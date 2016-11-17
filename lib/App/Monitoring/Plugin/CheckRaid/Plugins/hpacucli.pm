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
	my (%targets);
	my $fh = $this->cmd('controller status');
	while (<$fh>) {
		# Numeric slot
		if (my($model, $slot) = /^(\S.+) in Slot (.+)/) {
			$slot =~ s/ \(RAID Mode\)//;
			$slot =~ s/ \(HBA Mode\)//;
			$slot =~ s/ \(Embedded\)//;
			$targets{"slot=$slot"} = $model;
			$this->unknown if $slot !~ /^\d+/;
			next;
		}
		# Named Entry
		if (my($model, $cn) = /^(\S.+) in (.+)/) {
			$targets{"chassisname=$cn"} = $cn;
			next;
		}
	}
	close $fh;

	return $this->filter_targets(\%targets);
}

# Scan logical drives
sub scan_luns {
	my ($this, $targets) = @_;

	my %luns;
	while (my($target, $model) = each %$targets) {
		# check each controller
		my $fh = $this->cmd('logicaldrive status', { '$target' => $target });

		my ($array, %array);
		while (<$fh>) {
			# "array A"
			# "array A (Failed)"
			# "array B (Failed)"
			if (my($a, $s) = /^\s+array (\S+)(?:\s*\((\S+)\))?$/) {
				$array = $a;
				# Offset 0 is Array own status
				# XXX: I don't like this one: undef could be false positive
				$array{$array}[0] = $s || 'OK';
			}

			# skip if no active array yet
			next unless $array;

			# logicaldrive 1 (68.3 GB, RAID 1, OK)
			# capture only status
			if (my($drive, $s) = /^\s+logicaldrive (\d+) \([\d.]+ .B, [^,]+, ([^\)]+)\)$/) {
				# Offset 1 is each logical drive status
				$array{$array}[1]{$drive} = $s;
				next;
			}

			# Error: The controller identified by "slot=attr_value_slot_unknown" was not detected.
			if (/Error:/) {
				$this->unknown;
			}
		}
		$this->unknown unless close $fh;

		$luns{$target} = { %array };
	}

	return \%luns;
}

# parse hpacucli output into logical structure
sub parse {
	my $this = shift;

	my $targets = $this->scan_targets;
	if (!$targets) {
		return $targets;
	}
	my $luns = $this->scan_luns($targets);
	return { 'targets' => $targets, 'luns' => $luns };
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

	for my $target (sort {$a cmp $b} keys %{$ctrl->{targets}}) {
		my $model = $ctrl->{targets}->{$target};

		my @cstatus;
		foreach my $array (sort { $a cmp $b } keys %{$ctrl->{luns}->{$target}}) {
			my ($astatus, $ld) = @{$ctrl->{luns}->{$target}{$array}};

			# check array status
			if ($astatus ne 'OK') {
				$this->critical;
			}

			my @astatus;
			# extra details for non-normal arrays
			foreach my $lun (sort { $a cmp $b } keys %$ld) {
				my $s = $ld->{$lun};
				push(@astatus, "LUN$lun:$s");

				if ($s eq 'OK' or $s eq 'Disabled') {
				} elsif ($s eq 'Failed' or $s eq 'Interim Recovery Mode') {
					$this->critical;
				} elsif ($s eq 'Rebuild' or $s eq 'Recover') {
					$this->warning;
				}
			}
			push(@cstatus, "Array $array($astatus)[". join(',', @astatus). "]");
		}

		push(@status, "$model: ".join(', ', @cstatus));
	}

	return unless @status;

	$this->ok->message(join(', ', @status));
}

1;
