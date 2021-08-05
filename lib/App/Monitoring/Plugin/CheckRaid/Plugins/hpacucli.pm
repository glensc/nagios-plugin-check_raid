package App::Monitoring::Plugin::CheckRaid::Plugins::hpacucli;

## hpacucli/hpssacli/ssacli support
#
# driver developers recommend to use cciss_vol_status for monitoring,
# hpacucli/hpssacli shouldn't be used for monitoring due they obtaining global
# kernel lock while cciss_vol_status does not. cciss_vol_status is designed for
# monitoring
# https://github.com/glensc/nagios-plugin-check_raid/issues/114#issuecomment-138866801

use base 'App::Monitoring::Plugin::CheckRaid::Plugin';
use strict;
use warnings;

use constant E_NO_LOGICAL_DEVS => 'The specified device does not have any logical drives';

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

		# skip known noise
		if (
			/FIRMWARE UPGRADE REQUIRED: /
			|| /^\s{27}/
		) {
			next;
		}

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

		# Case for installed hpacucli but missing controllers
		if (
			/No controllers detected/
		) {
			return;
		}

		# Other statuses, try "key: value" pairs
		if (my ($key, $value) = /^\s*(.+?):\s+(.+?)$/) {
			$targets{$target}{$key} = $value;
			next;
		}

		warn "Unparsed: [$_]\n";
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
			if (/^Error:\s/) {
				# store it somewhere. should it be appended?
				($target->{'error'}) = /^Error:\s+(.+?)\.?\s*$/;
				$this->unknown;
				next;
			}

			# "array A"
			# "array A (Failed)"
			# "array B (Failed)"
			if (my($a, $s) = /^\s+array (\S+)(?:\s*\((\S+)\))?$/i) {
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

# format lun (logicaldevice) status
# update check status if problems found
sub lstatus {
	my ($this, $ld) = @_;

	my $s = $ld->{status};

	if ($s eq 'OK' or $s eq 'Disabled') {
	} elsif ($s eq 'Failed' or $s eq 'Interim Recovery Mode') {
		$this->critical;
	} elsif ($s eq 'Rebuild' or $s eq 'Recover') {
		$this->warning;
	}

	return "LUN$ld->{id}:$s";
}

# format array status
# update check status if problems found
sub astatus {
	my ($this, $array) = @_;

	if ($array->{status} ne 'OK') {
		$this->critical;
	}

	return "Array $array->{name}($array->{status})";
}

# format controller status
# updates check status if problems found
sub cstatus {
	my ($this, $c) = @_;
	my (@s, $s);

	# always include controller status
	push(@s, $c->{'Controller Status'} || 'ERROR');
	if ($c->{'Controller Status'} ne 'OK') {
		$this->critical;
	}

	if ($c->{error}) {
		if ($c->{error} eq E_NO_LOGICAL_DEVS) {
			$this->noraid;
			push(@s, 'Not configured');
		} else {
			$this->unknown;
			push(@s, $c->{error});
		}
	}

	# print those only if not ok and configured
	if (($s = $c->{'Cache Status'}) && $s !~ /^(OK|Not Configured)/) {
		push(@s, "Cache: $s");
		$this->cache_fail;
	}
	if (($s = $c->{'Battery/Capacitor Status'}) && $s !~ /^(OK|Not Configured)/) {
		push(@s, "Battery: $s");
		$this->bbulearn;
	}

	# start with identifyier
	my $name = $c->{chassisname} || $c->{controller};

	return $name . '[' . join(', ', @s) . ']';
}

sub check {
	my $this = shift;

	my $ctrls = $this->parse;
	unless ($ctrls) {
		$this->warning->message("No Controllers were found on this machine");
		return;
	}

	my @status;
	foreach my $ctrl (@$ctrls) {
		my @astatus;
		foreach my $array (@{$ctrl->{array}}) {
			my @lstatus;
			foreach my $ld (@{$array->{logicaldrives}}) {
				push(@lstatus, $this->lstatus($ld));
			}
			push(@astatus, $this->astatus($array). '['. join(',', @lstatus). ']');
		}
		my $cstatus = $this->cstatus($ctrl);
		$cstatus .= ': '. join(', ', @astatus) if @astatus;
		push(@status, $cstatus);
	}

	return unless @status;

	$this->ok->message(join(', ', @status));
}

1;
