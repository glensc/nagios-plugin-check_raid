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
		# empty line
		next if /^$/;

		# termination
		if (/^Command completed successfully/) {
			$ok = 1;
			last;
		}

		if (my($c) = /^Controllers found: (\d+)/) {
			$count = int($c);
			next;
		}

		# termination
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
	my (%c, @ld, $ld, @pd, $ch, $pd);

	my $fh = $this->cmd('getconfig', { '$ctrl' => $ctrl });
	my ($section, $subsection, $ok);
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

		if ($section eq 'Controller information') {
			if (not defined $subsection) {
				# TODO: battery stuff is under subsection "Controller Battery Information"
				if (my($s) = /Controller Status\s*:\s*(.+)/) {
					$c{status} = $s;

				} elsif (my($df) = /Defunct disk drive count\s+:\s*(\d+)/) {
					$c{defunct_count} = int($df);

				} elsif (my($td, $fd, $dd) = m{Logical devices/Failed/Degraded\s*:\s*(\d+)/(\d+)/(\d+)}) {
					$c{logical_count} = int($td);
					$c{logical_failed} = int($fd);
					$c{logical_degraded} = int($fd);

				} elsif (my($td2, $fd2, $dd2) = m{Logical drives/Offline/Critical\s*:\s*(\d+)/(\d+)/(\d+)}) {
					# ARCCONF 9.30
					$c{logical_count} = int($td2);
					$c{logical_offline} = int($fd2);
					$c{logical_critical} = int($fd2);
				}

			} elsif ($subsection eq 'Controller Battery Information') {
				if (my($bs) = /^\s+Status\s*:\s*(.*)$/) {
					$c{battery_status} = $bs;

				} elsif (my($bt) = /Over temperature\s*:\s*(.+)$/) {
					$c{battery_overtemp} = $bt;

				} elsif (my($bc) = /Capacity remaining\s*:\s*(\d+)\s*percent.*$/) {
					$c{battery_capacity} = int($bc);

				} elsif (my($d, $h, $m) = /Time remaining \(at current draw\)\s*:\s*(\d+) days, (\d+) hours, (\d+) minutes/) {
					$c{battery_time} = int($d) * 1440 + int($h) * 60 + int($m);
					$c{battery_time_full} = "${d}d${h}h${m}m";

				} else {
					warn "Battery not parsed: [$_]";
				}

			} elsif ($subsection eq 'Controller ZMM Information') {
				if (my($bs) = /^\s+Status\s*:\s*(.*)$/) {
					$c{zmm_status} = $bs;
				} else {
					warn "ZMM not parsed: [$_]";
				}

			} elsif ($subsection eq 'Controller Version Information') {
				# not parsed yet
			} elsif ($subsection eq 'Controller Vital Product Data') {
				# not parsed yet
			} elsif ($subsection eq 'Controller Cache Backup Unit Information') {
				# not parsed yet
			} elsif ($subsection eq 'Supercap Information') {
				# this is actually sub section of cache backup unit
				# not parsed yet
			} elsif ($subsection eq 'Controller Vital Product Data') {
				# not parsed yet
			} elsif ($subsection eq 'RAID Properties') {
				# not parsed yet
			} elsif ($subsection eq 'Controller BIOS Setting Information') {
				# not parsed yet
			} else {
				warn "SUBSECTION of [$section] NOT PARSED: [$subsection] [$_]";
			}

		} elsif ($section eq 'Physical Device information') {
			if (my($c) = /Channel #(\d+)/) {
				$ch = int($c);
				undef($pd);
			} elsif (my($n) = /Device #(\d+)/) {
				$pd = int($n);
			} elsif (not defined $pd) {
				if (/Transfer Speed\s+:\s+(.+)/) {
					# not parsed yet
				} elsif (/Initiator at SCSI ID/) {
					# not parsed yet
				} elsif (/No physical drives attached/) {
					# ignored
				} else {
					warn "Unparsed Physical Device data: [$_]";
				}
			} else {
				if (my($ps) = /Power State\s+:\s+(.+)/) {
					$pd[$ch][$pd]{power_state} = $ps;
				} elsif (my($st) = /^\s+State\s+:\s+(.+)/) {
					$pd[$ch][$pd]{status} = $st;
				} elsif (my($su) = /Supported\s+:\s+(.+)/) {
					$pd[$ch][$pd]{supported} = $su;
				} elsif (my($sf) = /Dedicated Spare for\s+:\s+(.+)/) {
					$pd[$ch][$pd]{spare} = $sf;
				} elsif (my($vnd) = /Vendor\s+:\s*(.*)/) {
					# allow edits, i.e removed 'Vendor' value from test data
					$pd[$ch][$pd]{vendor} = $vnd;
				} elsif (my($mod) = /Model\s+:\s+(.+)/) {
					$pd[$ch][$pd]{model} = $mod;
				} elsif (my($fw) = /Firmware\s+:\s*(.*)/) {
					$pd[$ch][$pd]{firmware} = $fw;
				} elsif (my($sn) = /Serial number\s+:\s+(.+)/) {
					$pd[$ch][$pd]{serial} = $sn;
				} elsif (my($wwn) = /World-wide name\s+:\s+(.+)/) {
					$pd[$ch][$pd]{wwn} = $wwn;
				} elsif (my($sz) = /Size\s+:\s+(.+)/) {
					$pd[$ch][$pd]{size} = $sz;
				} elsif (my($wc) = /Write Cache\s+:\s+(.+)/) {
					$pd[$ch][$pd]{write_cache} = $wc;
				} elsif (my($ssd) = /SSD\s+:\s+(.+)/) {
					$pd[$ch][$pd]{ssd} = $ssd;
				} elsif (my($fru) = /FRU\s+:\s+(.+)/) {
					$pd[$ch][$pd]{fru} = $fru;
				} elsif (my($esd) = /Reported ESD(?:\(.+\))?\s+:\s+(.+)/) {
					$pd[$ch][$pd]{esd} = $esd;
				} elsif (my($ncq) = /NCQ status\s+:\s+(.+)/) {
					$pd[$ch][$pd]{ncq} = $ncq;
				} elsif (my($pfa) = /PFA\s+:\s+(.+)/) {
					$pd[$ch][$pd]{pfa} = $pfa;
				} elsif (my($eid) = /Enclosure ID\s+:\s+(.+)/) {
					$pd[$ch][$pd]{enclosure} = $eid;
				} elsif (my($t) = /Type\s+:\s+(.+)/) {
					$pd[$ch][$pd]{type} = $t;
				} elsif (my($smart) = /S\.M\.A\.R\.T\.(?:\s+warnings)?\s+:\s+(.+)/) {
					$pd[$ch][$pd]{smart} = $smart;
				} elsif (my($speed) = /Transfer Speed\s+:\s+(.+)/) {
					$pd[$ch][$pd]{speed} = $speed;
				} elsif (my($e, $s) = /Reported Location\s+:\s+(?:Enclosure|Connector) (\d+), (?:Slot|Device) (\d+)/) {
					$pd[$ch][$pd]{location} = "$e:$s";
				} elsif (my($sps) = /Supported Power States\s+:\s+(.+)/) {
					$pd[$ch][$pd]{power_states} = $sps;
				} elsif (my($cd) = /Reported Channel,Device(?:\(.+\))?\s+:\s+(.+)/) {
					$pd[$ch][$pd]{cd} = $cd;
				} elsif (my($type) = /Device is an?\s+(.+)/) {
					$pd[$ch][$pd]{devtype} = $type;
				} elsif (/Status of Enclosure/) {
					# ignored
				} elsif (my($temp) = /Temperature.*:\s+(.+)/) {
					$pd[$ch][$pd]{temperature} = $temp;
				} elsif (/(Fan \d+|Speaker) status/) {
					# not parsed yet
				} elsif (/Expander ID\s+:/) {
					# not parsed yet
				} elsif (/Enclosure Logical Identifier\s+:/) {
					# not parsed yet
				} elsif (/Expander SAS Address\s+:/) {
					# not parsed yet
				} elsif (/[Mm]axCache (Capable|Assigned)\s+:\s+(.+)/) {
					# not parsed yet
				} elsif (/Power supply \d+ status/) {
					# not parsed yet
				} else {
					warn "Unparsed Physical Device data: [$_]";
				}
			}

		} elsif ($section =~ /Logical (device|drive) information/) {
			if (my($n) = /Logical (?:device|drive) number (\d+)/) {
				$ld = int($n);
				$ld[$ld]{id} = $n;

			} elsif (my($s) = /Status of logical (?:device|drive)\s+:\s+(.+)/) {
				$ld[$ld]{status} = $s;

			} elsif (my($ln) = /Logical (?:device|drive) name\s+:\s+(.+)/) {
				$ld[$ld]{name} = $ln;

			} elsif (my($rl) = /RAID level\s+:\s+(.+)/) {
				$ld[$ld]{raid} = $rl;

			} elsif (my($sz) = /Size\s+:\s+(.+)/) {
				$ld[$ld]{size} = $sz;

			} elsif (my($fs) = /Failed stripes\s+:\s+(.+)/) {
				$ld[$ld]{failed_stripes} = $fs;

			} elsif (my($ds) = /Defunct segments\s+:\s+(.+)/) {
				$ld[$ld]{defunct_segments} = $ds;

			} else {
				#   Write-cache mode                         : Not supported]
				#   Partitioned                              : Yes]
				#   Number of segments                       : 2]
				#   Drive(s) (Channel,Device)                : 0,0 0,1]
				#   Defunct segments                         : No]
			}
		} elsif ($section =~ /MaxCache 3\.0 information/) {
			# not parsed yet
		} else {
			warn "NOT PARSED: [$section] [$_]";
		}
	}
	close $fh;

	$this->unknown->message("Command did not succeed") unless defined $ok;

	return { controller => \%c, logical => \@ld, physical => \@pd };
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

	$this->critical if $c->{status} !~ /Optimal|Okay/;
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

	if (defined $c->{logical_degraded} && $c->{logical_degraded} > 0) {
		$this->critical;
		push(@status, "Degraded drives:$c->{logical_degraded}");
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

			my $id = $pd->{serial} || $pd->{wwn} || $pd->{location};
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
