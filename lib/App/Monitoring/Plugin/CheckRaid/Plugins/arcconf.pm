package App::Monitoring::Plugin::CheckRaid::Plugins::arcconf;

# Adaptec AAC-RAID
# check designed from check-aacraid.py, Anchor System - <http://www.anchor.com.au>
# Oliver Hookins, Paul De Audney, Barney Desmond.
# Perl port (check_raid) by Elan Ruusamäe.

use base 'App::Monitoring::Plugin::CheckRaid::Plugin';
use strict;
use warnings;

sub program_names {
	shift->{name};
}

sub commands {
	{
		'getstatus' => ['-|', '@CMD', 'GETSTATUS', '1'],
		# 'nologs' does not exist in arcconf 6.50. #118
		'getconfig' => ['-|', '@CMD', 'GETCONFIG', '$ctrl', 'AL'],
	}
}

sub sudo {
	my ($this, $deep) = @_;
	# quick check when running check
	return 1 unless $deep;

	my $cmd = $this->{program};
	(
		"CHECK_RAID ALL=(root) NOPASSWD: $cmd GETSTATUS 1",
		"CHECK_RAID ALL=(root) NOPASSWD: $cmd GETCONFIG * AL",
	);
}

sub parse_error {
	my ($this, $message) = @_;
	warn "arcconf: parse error: $message";
	$this->unknown->message("Parse Error: $message");
}

# parse GETSTATUS command
# parses
# - number of controllers
# - logical device tasks (if any running)
sub parse_status {
	my ($this) = @_;

	my $count = 0;
	my $ok = 0;
	my $fh = $this->cmd('getstatus');
	my %s;
	# controller task
	my %task;
	while (<$fh>) {
		chomp;
		# empty line or comment
		next if /^$/ or /^#/;

		# termination
		if (/^Command completed successfully/) {
			$ok = 1;
			last;
		}

		if (my($c) = /^Controllers [Ff]ound: (\d+)/) {
			$count = int($c);
			next;
		}

		if (/^(\S.+) Task:$/) {
			$task{type} = $1;
			next;
		}

		if (/^\s+Logical device\s+: (\d+)/) {
			$task{device} = $1;
		} elsif (/^\s+Task ID\s+: (\d+)/) {
			$task{id} = $1;
		} elsif (/^\s+Current operation\s+: (.+)/) {
			$task{operation} = $1;
		} elsif (/^\s+Status\s+: (.+)/) {
			$task{status} = $1;
		} elsif (/^\s+Priority\s+: (.+)/) {
			$task{priority} = $1;
		} elsif (/^\s+Percentage complete\s+: (\d+)/) {
			$task{percent} = $1;
		} elsif (/^Invalid controller number/) {
			;
		} else {
			warn "Unknown line: [$_]";
			# FIXME: ->message() gets overwritten later on
			$this->unknown->message("Unknown line: [$_]");
		}
	}
	close($fh);

	# Tasks seem to be Controller specific, but as we don't support over one controller, let it be global
	$s{tasks} = { %task } if %task;

	if ($count == 0) {
		# if command completed, but no controllers,
		# assume no hardware present
		if (!$ok) {
			$this->unknown->message("No controllers found!");
		}
		return undef;
	}

	$s{ctrl_count} = $count;

	return \%s;
}

# parse GETCONFIG for all controllers
sub parse_config {
	my ($this, $status) = @_;

	my %c;
	for (my $i = 1; $i <= $status->{ctrl_count}; $i++) {
		$c{$i} = $this->parse_ctrl_config($i, $status->{ctrl_count});
	}

	return { controllers => \%c };
}

# parse GETCONFIG command for specific controller
sub parse_ctrl_config {
	my ($this, $ctrl, $ctrl_count) = @_;

	# Controller information, Logical/Physical device info
	my ($ld, $ch, $pd);

	my $res = { controller => {}, logical => [], physical => [] };

	my $fh = $this->cmd('getconfig', { '$ctrl' => $ctrl });
	my ($section, $subsection, $ok);
	my %sectiondata = ();

	# called when data for section needs to be processed
	my $flush = sub {
		my $method = 'process_' . lc($section);
		$method =~ s/[.\s]+/_/g;
		$this->$method($res, \%sectiondata);
		%sectiondata = ();
	};
	while (<$fh>) {
		chomp;
		# empty line
		if (/^$/) {
			next;
		}

		if (/^Command completed successfully/) {
			$ok = 1;
			last;
		}

		if (my($c) = /^Controllers found: (\d+)/) {
			if ($c != $ctrl_count) {
				# internal error?!
				$this->unknown->message("Controller count mismatch");
			}
			next;
		}

		# section start
		if (/^---+/) {
			if (my($s) = <$fh> =~ /^(\w.+)$/) {
				# flush the lines
				if (defined($section)) {
					&$flush();
				}

				$section = $s;
				unless (<$fh> =~ /^---+/) {
					$this->parse_error($_);
				}
				undef($ld);
				$ch = 0;
				undef($pd);
				undef($subsection);
				next;
			}
			$this->parse_error($_);
		}

		# sub section start
		# there are also sections in subsections, but currently section names
		# are unique enough
		if (/^\s+---+/) {
			if (my($s) = <$fh> =~ /^\s+(\S.+?)\s*?$/) {
				$subsection = $s;
				unless (<$fh> =~ /^\s+---+/) {
					$this->parse_error($_);
				}
				next;
			}
			$this->parse_error($_);
		}

		next unless defined $section;

		# regex notes:
		# - value portion may be missing
		# - value may be empty
		# - value may be truncated (t/data/arcconf/issue47/getconfig)
		my ($key, $value) = /^\s*(.+?)(?:\s+:\s*(.*?))?$/;

		if ($section =~ /Controller [Ii]nformation/) {
			$sectiondata{$subsection || '_'}{$key} = $value;

		} elsif ($section =~ /Physical Device [Ii]nformation/) {
			if (my($c) = /Channel #(\d+)/) {
				$ch = int($c);
				undef($pd);
			} elsif (my($n) = /^\s+Device #(\d+)/) {
				$pd = int($n);
			} else {
				# FIXME: $pdk hack for t/data/arcconf/issue67/getconfig
				my $pdk = $pd;
				$pdk = '' unless defined $pdk;
				$sectiondata{$ch}{$pdk}{$subsection || '_'}{$key} = $value;
			}

		} elsif ($section =~ /Logical ([Dd]evice|drive) [Ii]nformation/) {
			if (my($n) = /Logical (?:[Dd]evice|drive) [Nn]umber (\d+)/) {
				$ld = int($n);
			} else {
				$sectiondata{$ld}{$subsection || '_'}{$key} = $value;
			}

		} elsif ($section eq 'MaxCache 3.0 information') {
			# not parsed yet
		} elsif ($section eq 'Connector information') {
			# not parsed yet
		} else {
			warn "NOT PARSED: [$section] [$_]";
		}
	}
	close $fh;
	&$flush() if $section;

	$this->unknown->message("Command did not succeed") unless defined $ok;

	return $res;
}

# Process Controller Information section
sub process_controller_information {
	my ($this, $res, $data) = @_;
	my $c = {};
	my $s;

	# current section
	my $cs = $data->{_};

	# TODO: battery stuff is under subsection "Controller Battery Information"
	$c->{status} = $cs->{'Controller Status'};

	if (exists $cs->{$s = 'Defunct Disk Drive Count'} || exists $cs->{$s = 'Defunct disk drive count'}) {
		$c->{defunct_count} = int($cs->{$s});
	}

	if ($s = $cs->{'Logical devices/Failed/Degraded'}) {
		my($td, $fd, $dd) = $s =~ m{(\d+)/(\d+)/(\d+)};
		$c->{logical_count} = int($td);
		$c->{logical_failed} = int($fd);
		$c->{logical_degraded} = int($dd);
	}
	# ARCCONF 9.30: Logical drives/Offline/Critical
	if ($s = $cs->{'Logical drives/Offline/Critical'}) {
		my($td2, $fd2, $dd2) = $s =~ m{(\d+)/(\d+)/(\d+)};
		$c->{logical_count} = int($td2);
		$c->{logical_offline} = int($fd2);
		$c->{logical_critical} = int($dd2);
	}

	$cs = $data->{'Controller Battery Information'};
	$c->{battery_status} = $cs->{Status} if exists $cs->{Status};
	$c->{battery_overtemp} = $cs->{'Over temperature'} if exists $cs->{'Over temperature'};

	if ($s = $cs->{'Capacity remaining'}) {
		my ($bc) = $s =~ m{(\d+)\s*percent.*$};
		$c->{battery_capacity} = int($bc);
	}

	if ($s = $cs->{'Time remaining (at current draw)'}) {
		my($d, $h, $m) = $s =~ /(\d+) days, (\d+) hours, (\d+) minutes/;
		$c->{battery_time} = int($d) * 1440 + int($h) * 60 + int($m);
		$c->{battery_time_full} = "${d}d${h}h${m}m";
	}


	$cs = $data->{'Controller ZMM Information'};
	$c->{zmm_status} = $cs->{Status} if exists $cs->{'Status'};

	$res->{controller} = $c;
}

sub process_logical_device_information {
	my ($this, $res, $data) = @_;
	my $s;

	my @ld;
	while (my($ld, $d) = each %$data) {
		# FIXME: parser fails to reset subsection
		my $cs = $d->{_} || $d->{'Logical device segment information'};

		$ld[$ld]{id} = $ld;
		if (exists $cs->{$s = 'RAID Level'} || exists $cs->{$s = 'RAID level'}) {
			$ld[$ld]{raid} = $cs->{$s};
		}
		$ld[$ld]{size} = $cs->{'Size'};
		$ld[$ld]{failed_stripes} = $cs->{'Failed stripes'} if exists $cs->{'Failed stripes'};
		$ld[$ld]{defunct_segments} = $cs->{'Defunct segments'} if exists $cs->{'Defunct segments'};

		if ($s = $cs->{'Status of Logical Device'} || $cs->{'Status of logical device'} || $cs->{'Status of logical drive'}) {
			$ld[$ld]{status} = $s;
		}
		if ($s = $cs->{'Logical Device name'} || $cs->{'Logical device name'} || $cs->{'Logical drive name'}) {
			$ld[$ld]{name} = $s;
		}

		#   Write-cache mode                         : Not supported]
		#   Partitioned                              : Yes]
		#   Number of segments                       : 2]
		#   Drive(s) (Channel,Device)                : 0,0 0,1]
		#   Defunct segments                         : No]
	}

	$res->{logical} = \@ld;
}

sub process_physical_device_information {
	my ($this, $res, $data) = @_;

	# Keys with no values:
	# "Device #0"
	# "Device is a Hard drive"
	#
	# ignored:
	# /Transfer Speed\s+:\s+(.+)/
	# /Initiator at SCSI ID/
	# /No physical drives attached/
	#
	# has only one subsection:
	# 'Device Phy Information', which is not yet processed

	my (@pd, $cs, $s);
	while (my($ch, $channel_data) = each %$data) {
		while (my($pd, $d) = each %$channel_data) {
			# FIXME: fallback to 'Device Phy Information' due parser bug
			$cs = $d->{_} || $d->{'Device Phy Information'};

			# FIXME: this should be skipped in check process, not here
			if ($pd eq '') {
				next;
			}

			$pd[$ch][$pd]{device_id} = $pd;
			$pd[$ch][$pd]{power_state} = $cs->{'Power State'} if exists $cs->{'Power State'};
			$pd[$ch][$pd]{status} = $cs->{'State'} if exists $cs->{'State'};
			$pd[$ch][$pd]{supported} = $cs->{'Supported'} if exists $cs->{'Supported'};
			$pd[$ch][$pd]{spare} = $cs->{'Dedicated Spare for'} if exists $cs->{'Dedicated Spare for'};
			$pd[$ch][$pd]{model} = $cs->{'Model'};
			$pd[$ch][$pd]{serial} = $cs->{'Serial number'} if exists $cs->{'Serial number'};
			$pd[$ch][$pd]{wwn} = $cs->{'World-wide name'} if exists $cs->{'World-wide name'};
			$pd[$ch][$pd]{write_cache} = $cs->{'Write Cache'} if exists $cs->{'Write Cache'};
			$pd[$ch][$pd]{ssd} = $cs->{'SSD'} if exists $cs->{'SSD'};
			$pd[$ch][$pd]{fru} = $cs->{'FRU'} if exists $cs->{'FRU'};
			$pd[$ch][$pd]{ncq} = $cs->{'NCQ status'} if exists $cs->{'NCQ status'};
			$pd[$ch][$pd]{pfa} = $cs->{'PFA'} if exists $cs->{'PFA'};
			$pd[$ch][$pd]{enclosure} = $cs->{'Enclosure ID'} if exists $cs->{'Enclosure ID'};
			$pd[$ch][$pd]{type} = $cs->{'Type'} if exists $cs->{'Type'};
			$pd[$ch][$pd]{smart} = $cs->{'S.M.A.R.T.'} if exists $cs->{'S.M.A.R.T.'};
			$pd[$ch][$pd]{smart_warn} = $cs->{'S.M.A.R.T. warnings'} if exists $cs->{'S.M.A.R.T. warnings'};
			$pd[$ch][$pd]{speed} = $cs->{'Transfer Speed'} if $cs->{'Transfer Speed'};
			$pd[$ch][$pd]{power_states} = $cs->{'Supported Power States'} if exists $cs->{'Supported Power States'};
			$pd[$ch][$pd]{fail_ldev_segs} = $cs->{'Failed logical device segments'} if exists $cs->{'Failed logical device segments'};

			# allow edits, i.e removed 'Vendor'/'Firmware' value from test data
			$pd[$ch][$pd]{vendor} = $cs->{'Vendor'} || '';
			$pd[$ch][$pd]{firmware} = $cs->{'Firmware'} if exists $cs->{'Firmware'};

			# previous parser was not exact line match
			if ($s = $cs->{'Size'} || $cs->{'Total Size'}) {
				$pd[$ch][$pd]{size} = $s;
			}

			$s = $cs->{'Reported ESD'} || $cs->{'Reported ESD(T:L)'};
			$pd[$ch][$pd]{esd} = $s if $s;

			if ($s = $cs->{'Reported Location'}) {
				my($e, $s) = $s =~ /(?:Enclosure|Connector) (\d+), (?:Slot|Device) (\d+)/;
				$pd[$ch][$pd]{location} = "$e:$s";
			}

			if ($s = $cs->{'Reported Channel,Device'} || $cs->{'Reported Channel,Device(T:L)'}) {
				$pd[$ch][$pd]{cd} = $s;
			}

			if (exists $cs->{$s = 'Device is a Hard drive'}
				|| exists $cs->{$s = 'Device is an Enclosure'}
				|| exists $cs->{$s = 'Device is an Enclosure services device'}
				|| exists $cs->{$s = 'Device is an Enclosure Services Device'}
			) {
				($pd[$ch][$pd]{devtype}) = $s =~ /Device is an?\s+(.+)/;
			}

			# TODO: normalize and other formats:
			# Current Temperature                : 27 deg C
			# Life-time Temperature Recorded
			# Temperature                              : 51 C/ 123 F (Normal)
			# Temperature                     : Normal
			# Temperature                        : Not Supported
			# Temperature Sensor Status 1     : 21 C/ 69 F (Normal)
			# Temperature Sensor Status 1     : 23 C/ 73 F (Normal)
			# Temperature Sensor Status 1     : 27 C/ 80 F (Normal)
			# Temperature Sensor Status 1     : 46 C/ 114 F (Abnormal)
			# Temperature status              : Normal
			# Threshold Temperature              : 51 deg C
			# FIXME: previous code used last line with /Temperature/ match
			if ($s = $cs->{'Temperature'} || $cs->{'Temperature Sensor Status 1'} || $cs->{'Temperature status'}) {
				$pd[$ch][$pd]{temperature} = $s;
			}

			# ignored:
			# Status of Enclosure
			# (Fan \d+|Speaker) status/
			# /Expander ID\s+:/
			# /Enclosure Logical Identifier\s+:/
			# /Expander SAS Address\s+:/
			# /[Mm]axCache (Capable|Assigned)\s+:\s+(.+)/
			# /Power supply \d+ status/
		}
	}


	$res->{physical} = \@pd;
}

sub process_logical_drive_information {
	shift->process_logical_device_information(@_);
}

sub process_maxcache_3_0_information {
}

# TODO: issue152/arc2_getconfig.txt
sub process_connector_information {
}

# NB: side effect: ARCCONF changes current directory to /var/log
sub parse {
	my ($this) = @_;

	# we chdir to /var/log, as tool is creating 'UcliEvt.log'
	# this can be disabled with 'nologs' parameter, but not sure do all versions support it
	chdir('/var/log') || chdir('/');

	my ($status, $config);
	$status = $this->parse_status or return;
	$config = $this->parse_config($status) or return;

	return { %$status, %$config };
}

# check for controller status
sub check_controller {
	my ($this, $c) = @_;

	my @status;

	$this->critical if $c->{status} !~ /Optimal|Okay|OK/;
	push(@status, "Controller:$c->{status}");

	if ($c->{defunct_count} > 0) {
		$this->critical;
		push(@status, "Defunct drives:$c->{defunct_count}");
	}

	if (defined $c->{logical_failed} && $c->{logical_failed} > 0) {
		$this->critical;
		push(@status, "Failed drives:$c->{logical_failed}");
	}

	if (defined $c->{logical_degraded} && $c->{logical_degraded} > 0) {
		$this->critical;
		push(@status, "Degraded drives:$c->{logical_degraded}");
	}

	if (defined $c->{logical_offline} && $c->{logical_offline} > 0) {
		$this->critical;
		push(@status, "Offline drives:$c->{logical_offline}");
	}

	if (defined $c->{logical_critical} && $c->{logical_critical} > 0) {
		$this->critical;
		push(@status, "Critical drives:$c->{logical_critical}");
	}

	# ZMM (Zero-Maintenance Module) status
	if (defined($c->{zmm_status})) {
		push(@status, "ZMM Status: $c->{zmm_status}");
	}

	# Battery status
	if ($this->bbu_monitoring) {
		my @s = $this->battery_status($c);
		push(@status, @s) if @s;
	}

	return @status;
}

# check for physical devices
sub check_physical {
	my ($this, $p) = @_;

	my %pd;
	$this->{pd_resync} = 0;
	for my $ch (@$p) {
		for my $pd (@{$ch}) {
			# skip not disks
			next if not defined $pd;
			next if $pd->{devtype} =~ m/Enclosure/;

			if ($pd->{status} eq 'Rebuilding') {
				$this->resync;
				$this->{pd_resync}++;

			} elsif ($pd->{status} eq 'Dedicated Hot-Spare') {
				$this->spare;
				$pd->{status} = "$pd->{status} for $pd->{spare}";

			} elsif ($pd->{status} !~ /^Online|Hot[- ]Spare|Ready/) {
				$this->critical;
			}

			my $id = $pd->{serial} || $pd->{wwn} || $pd->{location} || $pd->{cd};
			push(@{$pd{$pd->{status}}}, $id);
		}
	}

	return \%pd;
}

# check for logical devices
sub check_logical {
	my ($this, $l) = @_;

	my @status;
	for my $ld (@$l) {
		next unless $ld; # FIXME: fix that script assumes controllers start from '0'

		if ($ld->{status} eq 'Degraded' && $this->{pd_resync}) {
			$this->warning;
		} elsif ($ld->{status} !~ /Optimal|Okay/) {
			$this->critical;
		}

		my $id = $ld->{id};
		if ($ld->{name}) {
			$id = "$id($ld->{name})";
		}
		push(@status, "Logical Device $id:$ld->{status}");

		if (defined $ld->{failed_stripes} && $ld->{failed_stripes} ne 'No') {
			push(@status, "Failed stripes: $ld->{failed_stripes}");
		}
		if (defined $ld->{defunct_segments} && $ld->{defunct_segments} ne 'No') {
			push(@status, "Defunct segments: $ld->{defunct_segments}");
		}
	}

	return @status;
}

sub check {
	my $this = shift;

	my $data = $this->parse;
	$this->unknown,return unless $data;

	my @status;

	for my $i (sort {$a cmp $b} keys %{$data->{controllers}}) {
		my $c = $data->{controllers}->{$i};

		push(@status, $this->check_controller($c->{controller}));

		# current (logical device) tasks
		if ($data->{tasks}->{operation} ne 'None') {
			# just print it. no status change
			my $task = $data->{tasks};
			push(@status, "$task->{type} #$task->{device}: $task->{operation}: $task->{status} $task->{percent}%");
		}

		# check physical first, as it setups pd_resync flag
		my $pd = $this->check_physical($c->{physical});

		push(@status, $this->check_logical($c->{logical}));

		# but report after logical devices
		push(@status, "Drives: ".$this->join_status($pd)) if $pd;
	}

	$this->ok->message(join(', ', @status));
}

# check battery status in $c
sub battery_status {
	my ($this, $c) = @_;

	my @status;

	if (!defined($c->{battery_status}) || $c->{battery_status} eq 'Not Installed') {
		return;
	}

	push(@status, "Battery Status: $c->{battery_status}");

	# if battery status is 'Failed', none of the details below are available. #105
	if ($c->{battery_status} eq 'Failed') {
		$this->critical;
		return @status;
	}

	# detailed battery checks
	if ($c->{battery_overtemp} ne 'No') {
		$this->critical;
		push(@status, "Battery Overtemp: $c->{battery_overtemp}");
	}

	push(@status, "Battery Capacity Remaining: $c->{battery_capacity}%");
	if ($c->{battery_capacity} < 50) {
		$this->critical;
	}
	if ($c->{battery_capacity} < 25) {
		$this->warning;
	}

	if ($c->{battery_time} < 1440) {
		$this->warning;
	}
	if ($c->{battery_time} < 720) {
		$this->critical;
	}

	if ($c->{battery_time} < 60) {
		push(@status, "Battery Time: $c->{battery_time}m");
	} else {
		push(@status, "Battery Time: $c->{battery_time_full}");
	}

	return @status;
}

1;
