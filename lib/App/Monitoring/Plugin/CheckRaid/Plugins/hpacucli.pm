package App::Monitoring::Plugin::CheckRaid::Plugins::hpacucli;

## hpacucli/hpssacli support
#
# driver developers recommend to use cciss_vol_status for monitoring,
# hpacucli/hpssacli shouldn't be used for monitoring due they obtaining global
# kernel lock while cciss_vol_status does not. cciss_vol_status is designed for
# monitoring
# https://github.com/glensc/nagios-plugin-check_raid/issues/114#issuecomment-138866801

use base 'App::Monitoring::Plugin::CheckRaid::Plugin';
use strict;
use warnings;

sub program_names {
	shift->{name};
}

sub commands {
	{
		'controller status' => ['-|', '@CMD', 'controller', 'all', 'show', 'status'],
		'logicaldrive status' => ['-|', '@CMD', 'controller', '$target', 'logicaldrive', 'all', 'show'],
	}
}

sub sudo {
	my ($this, $deep) = @_;
	# quick check when running check
	return 1 unless $deep;

	my $cmd = $this->{program};
	(
		"CHECK_RAID ALL=(root) NOPASSWD: $cmd controller all show status",
		"CHECK_RAID ALL=(root) NOPASSWD: $cmd controller * logicaldrive all show",
	);
}

# if --plugin-option=hpacucli-target=slot=0 is specified
# filter only allowed values
sub filter_targets {
	my ($this, $targets) = @_;

	my $cli_opts = $this->{options}{'hpacucli-target'};
	if (!$cli_opts) {
		return $targets;
	}

	my %res;
	my @filters = split(/,/, $cli_opts);
	for my $filter (@filters) {
		if (exists $targets->{$filter}) {
			$res{$filter} = $targets->{$filter};
		} else {
			$this->critical->message("Controller $filter not found");
		}
	}

	return \%res;
}

# split:
# '(Embedded) (RAID Mode)'
# to:
# [ 'Embedded', 'RAID Mode' ]
sub split_controller_modes {
	my ($modes) = @_;
	my @parts;
	push @parts, $1 while $modes =~ /\((.*?)\)/g;
	return \@parts;
}

sub scan_targets {
	my $this = shift;

	# TODO: allow target customize:
	# hpacucli <target> is of format:
	#  [controller all|slot=#|wwn=#|chassisname="AAA"|serialnumber=#|chassisserialnumber=#|ctrlpath=#:# ]
	#  [array all|<id>]
	#  [physicaldrive all|allunassigned|[#:]#:#|[#:]#:#-[#:]#:#]
	#  [logicaldrive all|#]
	#  [enclosure all|#:#|serialnumber=#|chassisname=#]
	#  [licensekey all|<key>]

	# Scan controllers
	my (%targets, $target);
	my $fh = $this->cmd('controller status');
	while (<$fh>) {
		chomp;
		# skip empty lines and artificial comments (added by this project)
		next if /^$/ or /^#/;

		# Numeric slot
		if (my($controller, $slot, $modes) = /
				^(\S.+)\sin\sSlot
				\s(\S+?) # slot number
				(?:     # optional mode
					\s(\(.+\))
				)?$
			/x) {

			$target = "slot=$slot";
			$targets{$target} = {
				target => $target,
				controller => $controller,
				slot => $slot,
				modes => split_controller_modes($modes || ''),
			};
			$this->unknown if $slot !~ /^\d+/;
			next;
		}
		# Named Entry
		if (my($controller, $cn) = /^(\S.+) in (.+)/) {
			$target = "chassisname=$cn";
			$targets{$target} = {
				target => $target,
				controller => $controller,
				chassisname => $cn,
			};
			next;
		}

		# Other statuses, try "key: value" pairs
		if (my ($key, $value) = /^\s*(.+?):\s+(.+?)$/) {
			$targets{$target}{$key} = $value;
		} else {
			warn "Unparsed: [$_]\n";
		}
	}
	close $fh;

	return $this->filter_targets(\%targets);
}

# Scan logical drives
sub scan_luns {
	my ($this, $targets) = @_;

	my @luns;
	# sort by target to ensure consistent results
	for my $target (sort {$a->{target} cmp $b->{target}} values(%$targets)) {
		# check each controller
		my $fh = $this->cmd('logicaldrive status', { '$target' => $target->{target} });

		my $index = -1;
		my @array;
		my %array;
		while (<$fh>) {
			chomp;
			# skip empty lines and artificial comments (added by this project)
			next if /^$/ or /^#/;

			# Error: The controller identified by "slot=attr_value_slot_unknown" was not detected.
			if (/Error:/) {
				# store it somewhere. should it be appended?
				$target->{'error'} = $_;
				$this->unknown;
				next;
			}

			# "array A"
			# "array A (Failed)"
			# "array B (Failed)"
			if (my($a, $s) = /^\s+array (\S+)(?:\s*\((\S+)\))?$/) {
				$index++;
				# Offset 0 is Array own status
				# XXX: I don't like this one: undef could be false positive
				$target->{'array'}[$index]{status} = $s || 'OK';
				$target->{'array'}[$index]{name} = $a;
				next;
			}

			# logicaldrive 1 (68.3 GB, RAID 1, OK)
			# capture only status
			if (my($drive, $size, $raid, $status) = /^\s+logicaldrive (\d+) \(([\d.]+ .B), ([^,]+), ([^\)]+)\)$/) {
				warn "Index out of bounds" if $index < 0; # XXX should not happen

				# Offset 1 is each logical drive status
				my $ld = {
					'id' => $drive,
					'status' => $status,
					'size' => $size,
					'raid' => $raid,
				};
				push(@{$target->{'array'}[$index]{logicaldrives}}, $ld);
				next;
			}

			# skip known noise
			if (
				/\s+Type "help" for more details/
				# Controller name: exact match
				|| /^\Q$target->{controller}\E\s/
				# loose match, some test data seems malformed
				|| / in Slot \d/
				|| /^FIRMWARE UPGRADE REQUIRED:/
				|| /^\s{27}/
			) {
				next;
			}

			warn "Unhandled: [$_]\n";
		}
		$this->unknown unless close $fh;

		push(@luns, $target);
	}

	return \@luns;
}

# parse hpacucli output into logical structure
sub parse {
	my $this = shift;

	my $targets = $this->scan_targets;
	if (!$targets) {
		return $targets;
	}

	return $this->scan_luns($targets);
}

sub check {
	my $this = shift;

	my $ctrl = $this->parse;
	unless ($ctrl) {
		$this->warning->message("No Controllers were found on this machine");
		return;
	}

	# status messages pushed here
	my @status;

	foreach my $target (@$ctrl) {
		my @cstatus;
		foreach my $array (@{$target->{array}}) {
			# check array status
			if ($array->{status} ne 'OK') {
				$this->critical;
			}

			my @astatus;
			# extra details for non-normal arrays
			foreach my $ld (@{$array->{logicaldrives}}) {
				my $s = $ld->{status};
				push(@astatus, "LUN$ld->{id}:$s");

				if ($s eq 'OK' or $s eq 'Disabled') {
				} elsif ($s eq 'Failed' or $s eq 'Interim Recovery Mode') {
					$this->critical;
				} elsif ($s eq 'Rebuild' or $s eq 'Recover') {
					$this->warning;
				}
			}
			push(@cstatus, "Array $array->{name}($array->{status})[". join(',', @astatus). "]");
		}

		my $name = $target->{chassisname} || $target->{controller};
		push(@status, "$name: ".join(', ', @cstatus));
	}

	return unless @status;

	$this->ok->message(join(', ', @status));
}

1;
