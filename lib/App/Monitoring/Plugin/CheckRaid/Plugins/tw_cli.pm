package App::Monitoring::Plugin::CheckRaid::Plugins::tw_cli;

# tw_cli(8) is a Command Line Interface Storage Management Software for
# AMCC/3ware ATA RAID Controller(s).
# Owned by LSI currently: https://en.wikipedia.org/wiki/3ware
#
# http://www.cyberciti.biz/files/tw_cli.8.html

use base 'App::Monitoring::Plugin::CheckRaid::Plugin';
# not yet, see:
# https://github.com/glensc/nagios-plugin-check_raid/pull/131#issuecomment-189957806
#use Date::Parse qw(strptime);
#use DateTime;
use strict;
use warnings;

sub program_names {
	qw(tw_cli-9xxx tw_cli tw-cli);
}

sub commands {
	{
		'show' => ['-|', '@CMD', 'show'], # This is 'info' output AND enclosure summary
		'unitstatus' => ['-|', '@CMD', 'info', '$controller', 'unitstatus'],
		'drivestatus' => ['-|', '@CMD', 'info', '$controller', 'drivestatus'],
		'bbustatus' => ['-|', '@CMD', 'info', '$controller', 'bbustatus'],
		'enc_show_all' => ['-|', '@CMD', '$encid', 'show all'],
	}
}

sub sudo {
	my ($this, $deep) = @_;
	# quick check when running check
	return 1 unless $deep;

	my $cmd = $this->{program};
	(
		"CHECK_RAID ALL=(root) NOPASSWD: $cmd info",
		"CHECK_RAID ALL=(root) NOPASSWD: $cmd info *",
		"CHECK_RAID ALL=(root) NOPASSWD: $cmd show",
		"CHECK_RAID ALL=(root) NOPASSWD: $cmd * show all",
	);
}

sub trim { my $s = shift; $s =~ s/^\s+|\s+$//g; return $s };

sub to_i {
	my $i = shift;
	return $i if $i !~ /^\d+$/;
	return int($i);
}

sub parse {
	my $this = shift;

	my (%c);
	# scan controllers
	my ($sect_ctl, $sect_enc) = 0;
	my $fh = $this->cmd('show');
	while (<$fh>) {
		# Section break
		if(/^\s*$/) { ($sect_ctl,$sect_enc) = (0,0); next; };
		# header line
		if(/^-+$/) { next; };
		# section headers: Controller
		# Ctl   Model  Ports     Drives  Units   NotOpt  RRate VRate  BBU
		# Ctl   Model  (V)Ports  Drives  Units   NotOpt  RRate VRate  BBU
		if (/^Ctl.*Model.*Rate/) { $sect_ctl = 1; next; };
		# section headers: Enclosure
		#  Encl    Slots   Drives  Fans   TSUnits   Ctls
		#  Encl    Slots   Drives  Fans   TSUnits  PSUnits
		#  Enclosure     Slots  Drives  Fans  TSUnits  PSUnits  Alarms
		if (/^Encl.*Drive/) { $sect_enc = 1; next; };

		# controller section
		if ($sect_ctl and my($ctl, $model, $ports, $drives, $units, $notopt, $rrate, $vrate, $bbu) = m{^
			(c\d+)\s+   # Controller
			(\S+)\s+    # Model
			(\d+)\s+    # (V)Ports
			(\d+)\s+    # Drives
			(\d+)\s+    # Units
			(\d+)\s+    # NotOpt: Not Optional
						# Not Optimal refers to any state except OK and VERIFYING.
						# Other states include INITIALIZING, INIT-PAUSED,
						# REBUILDING, REBUILD-PAUSED, DEGRADED, MIGRATING,
						# MIGRATE-PAUSED, RECOVERY, INOPERABLE, and UNKNOWN.
			(\d+)\s+    # RRate: Rebuild Rate
			(\d+|-)\s+  # VRate: Verify Rate
			(\S+|-)?    # BBU
		}x) {
			$c{$ctl} = {
				model => $model,
				ports => int($ports),
				drives => int($drives),
				units => int($units),
				optimal => int(!$notopt),
				rrate => int($rrate),
				vrate => to_i($vrate),
				bbu => $bbu,
			};
		}
		# enclosure section
		if ($sect_enc and my($enc, $slots, $drives, $fans, $tsunits, $psunits, $alarms) = m{^
			((?:/c\d+)?/e\d+)\s+   # Controller, Enclosure
			  # 9650SE reports enclosures as /eX
			  # 9690SA+ report enclosures as /cX/eX
			(\d+)\s+    # Slots
			(\d+)\s+    # Drives
			(\d+)\s+    # Fans
			(\d+)\s+    # TSUnits - Temp Sensor
			(\d+)?\s+    # PSUnits - Power Supply, not always present!
			(\d+)?\s+    # Controller OR Alarms, not always present!
		}x) {
			# This will be filled in later by the enclosure pass
			$c{$enc} = {};
		}
	}
	close $fh;

	# no controllers? skip early
	return unless %c;

	for my $c (grep /^\/?c\d+$/, keys %c) {
		# get each unit on controllers
		$fh = $this->cmd('unitstatus', { '$controller' => $c });
		while (<$fh>) {
			if (my($u, $type, $status, $p_rebuild, $p_vim, $strip, $size, $cache, $avrify) = m{^
				(u\d+)\s+ # Unit
				(\S+)\s+  # UnitType
				(\S+)\s+  # Status
				(\S+)\s+  # %RCmpl: The %RCompl reports the percent completion
						  # of the unit's Rebuild, if this task is in progress.
				(\S+)\s+  # %V/I/M: The %V/I/M reports the percent completion
						  # of the unit's Verify, Initialize, or Migrate,
						  # if one of these are in progress.
				(\S+)\s+  # Strip
				(\S+)\s+  # Size(GB)
				(\S+)\s+  # Cache
				(\S+)     # AVrify
			}x) {
				$c{$c}{unitstatus}{$u} = {
					type => $type,
					status => $status,
					rebuild_percent => $p_rebuild,
					vim_percent => $p_vim,
					strip => $strip,
					size => $size,
					cache => $cache,
					avrify => $avrify,
				};
				next;
			}

			if (m{^u\d+}) {
				$this->unknown;
				warn "unparsed: [$_]";
			}
		}
		close $fh;

		# get individual disk status
		$fh = $this->cmd('drivestatus', { '$controller' => $c });
		# common regexp
		my $r = qr{^
			(p\d+)\s+       # Port
			(\S+)\s+        # Status
			(\S+)\s+        # Unit
			([\d.]+\s[TG]B|-)\s+ # Size
		}x;

		while (<$fh>) {
			# skip empty line
			next if /^$/;

			# Detect version
			if (/^Port/) {
				# <=9.5.1: Blocks Serial
				$r .= qr{
					(\S+)\s+  # Blocks
					(.+)      # Serial
				}x;
				next;
			} elsif (/^VPort/) {
				# >=9.5.2: Type Phy Encl-Slot Model
				$r .= qr{
					(\S+)\s+ # Type
					(\S+)\s+ # Phy
					(\S+)\s+ # Encl-Slot
					(.+)     # Model
				}x;
				next;
			}

			if (my($port, $status, $unit, $size, @rest) = ($_ =~ $r)) {
				# do not report disks not present
				# tw_cli 9.5.2 and above do not list these at all
				next if $status eq 'NOT-PRESENT';
				my %p;

				if (@rest <= 2) {
					my ($blocks, $serial) = @rest;
					%p = (
						blocks => to_i($blocks),
						serial => trim($serial),
					);
				} else {
					my ($type, $phy, $encl, $model) = @rest;
					%p = (
						type => $type,
						phy => to_i($phy),
						encl => $encl,
						model => $model,
					);
				}

				$c{$c}{drivestatus}{$port} = {
					status => $status,
					unit => $unit,
					size => $size,
					%p,
				};

				next;
			}

			if (m{^p\d+}) {
				$this->unknown;
				warn "unparsed: [$_]";
			}
		}
		close $fh;

		# get BBU status
		$fh = $this->cmd('bbustatus', { '$controller' => $c });
		while (<$fh>) {
			next if /^$/;
			next if /^-{10,}$/;
			if (my($bbu, $onlinestate, $bbuready, $status, $volt, $temp, $hours, $lastcaptest) = m{^
				(bbu\d*)\s+     # BBU, possibly numbered (RARE)
				(\S+)\s+        # OnlineState
				(\S+)\s+        # BBUReady
				(\S+)\s+        # Status
				(\S+)\s+        # Volt
				(\S+)\s+        # Temp
				(\d+)\s+        # Hours
				(\S+)\s+        # LastCapTest
			}x) {
				$c{$c}{bbustatus}{$bbu} = {
					OnlineState => $onlinestate,
					BBUReady => $bbuready,
					Status => $status,
					Volt => $volt,
					Temp => $temp,
					Hours => $hours,
					LastCapTest => $lastcaptest,
				};
				next;
			}
			if (m{^\S+\+}) {
				$this->unknown;
				warn "unparsed: [$_]";
			}
		}
		close $fh;
	}

	# Do enclosures now, which might NOT be attached the controllers
	# WARNING: This data section has not always been consistent over versions of tw_cli.
	# You should try to use the newest version of the driver, as it deliberately uses the newer style of output
	# rather than the output for the tw_cli versions released with 9550SX/9590SE/9650SE
	for my $encid (grep /\/e\d+$/, keys %c) {
		$fh = $this->cmd('enc_show_all', { '$encid' => $encid });
		# Variable names chose to be 'sect_XXX' explicitly.
		# This says what section we are in right now
		my ($sect_enc, $sect_fan, $sect_tmp, $sect_psu, $sect_slt, $sect_alm) = (0,0,0,0,0,0);
		# This says what section we have seen, it gets reset at the start of each enclosure block;
		my ($seen_enc, $seen_fan, $seen_tmp, $seen_psu, $seen_slt, $seen_alm) = (0,0,0,0,0,0);
		while (<$fh>) {
			# Skip the header break lines
			next if /^-+$/;
			# and the partial indented header that is ABOVE the fan header
			next if /^\s+-+Speed-+\s*$/;
			# If the line is blank, reset our section headers
			if(/^\s*$/){
				($sect_enc, $sect_fan, $sect_tmp, $sect_psu, $sect_slt, $sect_alm) = (0,0,0,0,0,0);
				# If we have SEEN all of the sections, also reset the seen markers
				# This is needed when the output contains multiple enclosures
				if($sect_enc and $sect_fan and $sect_tmp and $sect_psu and $sect_slt and $sect_alm) {
					($seen_enc, $seen_fan, $seen_tmp, $seen_psu, $seen_slt, $seen_alm) = (0,0,0,0,0,0);
				}
				next;
			}
			if (/^Encl.*Status/)        { $seen_enc = $sect_enc = 1; next; }
			if (/^Fan.*Status/)         { $seen_fan = $sect_fan = 1; next; }
			if (/^TempSensor.*Status/)  { $seen_tmp = $sect_tmp = 1; next; }
			if (/^PowerSupply.*Status/) { $seen_psu = $sect_psu = 1; next; }
			if (/^Slot.*Status/)        { $seen_slt = $sect_slt = 1; next; }
			if (/^Alarm.*Status/)       { $seen_alm = $sect_alm = 1; next; }
			# ------ Start of new enclosure
			if ($sect_enc and my($encl, $encl_status) = m{^
				((?:/c\d+)?/e\d+)\s+   # Controller, Enclosure
				(\S+)\s+   # Status
			}x) {
				# This is a special case for the test environment, as it is
				# hard to feed MULTI command inputs into the mock.
				if($ENV{'HARNESS_ACTIVE'} and $encl ne $encid) {
					$encid = $encl;
				}
				$c{$encid} = {
					encl   => $encl, # Dupe of $encid to verify
					status => $encl_status,
					# This is the top-level enclosure object
					fans => {},
					tempsensor => {},
					powersupply => {},
					slot => {},
					alarm => {},
				};
			}
			# ------ Fans
			elsif ($sect_fan and my($fan, $fan_status, $fan_state, $fan_step, $fan_rpm, $fan_identify) = m{^
				(fan\S+)\s+   # Fan
				(\S+)\s+   # Status
				(\S+)\s+   # State
				(\S+)\s+   # Step
				(\d+|N/A)\s+   # RPM
				(\S+)\s+   # Identify
			}x) {
				$c{$encid}{fans}{$fan} = {
					status => $fan_status,
					state => $fan_state,
					step => $fan_step,
					rpm => $fan_rpm,
					identify => $fan_identify,
				};
				next;
			}
			# ------ TempSensor
			elsif ($sect_tmp and my($tmp, $tmp_status, $tmp_temperature, $tmp_identify) = m{^
				(temp\S+)\s+   # TempSensor
				(\S+)\s+   # Status
				(\S+)\s+   # Temperature
				(\S+)\s+   # Identify
			}x) {
				$c{$encid}{tempsensor}{$tmp} = {
					status => $tmp_status,
					temperature => $tmp_temperature,
					identify => $tmp_identify,
				};
				next;
			}
			# ------ PowerSupply
			elsif ($sect_psu and my($psu, $psu_status, $psu_state, $psu_voltage, $psu_current, $psu_identify) = m{^
				((?:pw|psu)\S+)\s+   # PowerSupply
				(\S+)\s+   # Status
				(\S+)\s+   # State
				(\S+)\s+   # Voltage
				(\S+)\s+   # Current
				(\S+)\s+   # Identify
			}x) {
				$c{$encid}{powersupply}{$psu} = {
					status => $psu_status,
					state => $psu_state,
					voltage => $psu_voltage,
					current => $psu_current,
					identify => $psu_identify,
				};
				next;
			}
			# ------ Slot
			elsif ($sect_slt and my($slt, $slt_status, $slt_vport, $slt_identify) = m{^
				(slo?t\S+)\s+   # Slot
				(\S+)\s+   # Status
				(\S+)\s+   # (V)Port
				(\S+)\s+   # Identify
			}x) {
				$c{$encid}{slot}{$slt} = {
					status => $slt_status,
					vport => $slt_vport,
					identify => $slt_identify,
				};
				next;
			}
			# ------ Alarm
			elsif ($sect_alm and my($alm, $alm_status, $alm_state, $alm_audibility) = m{^
				(alm\S+)\s+   # Alarm
				(\S+)\s+   # Status
				(\S+)\s+   # State
				(\S+)\s+   # Audibility
			}x) {
				$c{$encid}{alarm}{$alm} = {
					status => $alm_status,
					state => $alm_state,
					audibility => $alm_audibility,
				};
				next;
			}
			# ---- End of known data
			elsif (m{^\S+\+}) {
				$this->unknown;
				warn "unparsed: [$_]";
			}

		}
		close $fh;
	}

	return \%c;
}

sub check {
	my $this = shift;

	# status messages pushed here
	my @status;

	my $c = $this->parse;
	if (!$c) {
		$this->unknown;
		$this->message("No Adapters were found on this machine");
	}

	# process each controller
	for my $cid (sort grep !/e\d+/, keys %$c) {
		my $c = $c->{$cid};
		my @cstatus;

		for my $uid (sort keys %{$c->{unitstatus}}) {
			my $u = $c->{unitstatus}->{$uid};
			my $s = $u->{status};

			if ($s =~ /INITIALIZING|MIGRATING/) {
				$this->warning;
				$s .= " $u->{vim_percent}";

			} elsif ($s =~ /VERIFYING|VERIFY-PAUSED/) {
				$this->check_status;
				$s .= " $u->{vim_percent}";

			} elsif ($s eq 'REBUILDING') {
				$this->resync;
				$s .= " $u->{rebuild_percent}";

			} elsif ($s eq 'DEGRADED') {
				$this->critical;

			} elsif ($s ne 'OK') {
				$this->critical;

			}

			my @ustatus = $s;

			# report cache, no checking
			if ($u->{cache} && $u->{cache} ne '-') {
				push(@ustatus, "Cache:$u->{cache}");
			}

			push(@status, "$cid($c->{model}): $uid($u->{type}): ".join(', ', @ustatus));
		}

		# check individual disk status
		my %ds;
		foreach my $p (sort { $a cmp $b } keys %{$c->{drivestatus}}) {
			my $d = $c->{drivestatus}->{$p};
			my $ds = $d->{status};
			if ($ds =~ /VERIFYING|VERIFY-PAUSED/) {
				$this->check_status;
			} elsif ($ds ne 'OK') {
				$this->critical;
			}

			if ($d->{unit} eq '-') {
				$ds = 'SPARE';
			}

			push(@{$ds{$ds}}, $p);
		}
		push(@status, "Drives($c->{drives}): ".$this->join_status(\%ds)) if %ds;

		# check BBU, but be prepared that BBU status might not report anything
		if ($this->{options}{bbu_monitoring} && $c->{bbu} && $c->{bbu} ne '-') {
			# On old controllers, bbustatus did not exist; and the only BBU status
			# you got was on the controller listing.
			if(scalar(keys %{$c->{bbustatus}}) < 1) {
				$this->critical if $c->{bbu} ne 'OK';
				push(@status, "BBU: $c->{bbu}");
			} else {
				foreach my $bbuid (sort { $a cmp $b } keys %{$c->{bbustatus}}) {
					my $bat = $c->{bbustatus}->{$bbuid};
					my $bs = $bat->{Status}; # We might override this later
					my @batmsg;
					if($bs eq 'Testing' or $bs eq 'Charging') {
						$this->bbulearn;
					} elsif($bs eq 'WeakBat') {
						# Time to replace your battery
						$this->warning;
					} elsif($bs ne 'OK') {
						$this->critical;
					}
					# We do NOT check BBUReady, as it doesn't private granular
					# info.
					# Check OnlineState flag as well
					# A battery can be GOOD, but disabled; this is only reflected in OnlineState.
					if($bat->{OnlineState} ne 'On') {
						push @batmsg, 'OnlineStatus='.$bat->{OnlineState};
						$this->critical;
					}
					# Check voltage & temps
					push @batmsg, 'Volt='.$bat->{Volt};
					push @batmsg, 'Temp='.$bat->{Temp};
					if ($bat->{Volt} =~ /^(LOW|HIGH)$/) {
						$this->critical;
					} elsif ($bat->{Volt} =~ /^(LOW|HIGH)$/) {
						$this->warning;
					}
					if ($bat->{Temp} =~ /^(LOW|HIGH)$/) {
						$this->critical;
					} elsif ($bat->{Temp} =~ /^(LOW|HIGH)$/) {
						$this->warning;
					}
					# Check runtime estimate
					# Warn if too low
					my $bbulearn = '';
					if ($bat->{Hours} ne '-' and int($bat->{Hours}) <= 1) {
						# TODO: make this configurable before going live
						#$this->warning;
						$this->bbulearn;
						$bbulearn = '/LEARN';
					}
					push @batmsg, 'Hours='.$bat->{Hours};

					# Check date of last capacity test
					if ($bat->{LastCapTest} eq 'xx-xxx-xxxx') {
						$this->bbulearn;
						$bbulearn = '/LEARN';
					} elsif ($bat->{LastCapTest} ne '-') {
						# TODO: is the short name of month localized by tw_cli?
						#my ($mday, $mon, $year) = (strptime($bat->{LastCapTest}, '%d-%b-%Y'))[3,4,5];
						#my $lastcaptest_epoch = DateTime->new(year => $year, month => $mon, day => $mday, hour => 0, minute => 0, second => 0);
						#my $present_time = time;
						## TODO: this value should be configurable before going live, also need to mock system date for testing
						#if (($present_time-$lastcaptest_epoch) > 86400*365) {
						#	$this->bbulearn;
						#}
					}
					push @batmsg, 'LastCapTest='.$bat->{LastCapTest};
					my $msg = join(',', @batmsg);
					my $bbustatus = $bs.$bbulearn;
					$bbustatus = "$bbuid=$bs" if $bbuid ne 'bbu'; # If we have multiple BBU, specify which one
					push(@status, "BBU: $bbustatus($msg)");
				}
			}
		}
	}
	# process each enclosure
	for my $eid (sort grep /\/e\d+/, keys %$c) {
		my $e = $c->{$eid};
		# If the enclosure command returned nothing, we have no status to
		# report.
		next unless defined($e->{status});

		# Something is wrong, but we are not sure what yet.
		$this->warning unless $e->{status} eq 'OK';
		my @estatus;
		for my $fan_id (sort keys %{$e->{fans}}) {
			my $f = $e->{fans}->{$fan_id};
			my $s = $f->{status};
			next if $s eq 'NOT-REPORTABLE' or $s eq 'NOT-INSTALLED' or $s eq 'NO-DEVICE';
			$this->warning if $s ne 'OK';
			push(@estatus, "$fan_id=$s($f->{rpm})");
		}
		for my $tmp_id (sort keys %{$e->{tempsensor}}) {
			my $t = $e->{tempsensor}->{$tmp_id};
			my $s = $t->{status};
			next if $s eq 'NOT-REPORTABLE' or $s eq 'NOT-INSTALLED' or $s eq 'NO-DEVICE';
			$this->warning if $s ne 'OK';
			$t->{temperature} =~ s/\(\d+F\)//; # get rid of extra units
			push(@estatus, "$tmp_id=$s($t->{temperature})");
		}
		for my $psu_id (sort keys %{$e->{powersupply}}) {
			my $t = $e->{powersupply}->{$psu_id};
			my $s = $t->{status};
			next if $s eq 'NOT-REPORTABLE' or $s eq 'NOT-INSTALLED' or $s eq 'NO-DEVICE';
			$this->warning if $s ne 'OK';
			push(@estatus, "$psu_id=$s(status=$t->{state},voltage=$t->{voltage},current=$t->{current})");
		}
		for my $slot_id (sort keys %{$e->{slot}}) {
			my $t = $e->{slot}->{$slot_id};
			my $s = $t->{status};
			next if $s eq 'NOT-REPORTABLE' or $s eq 'NOT-INSTALLED' or $s eq 'NO-DEVICE';
			$this->warning if $s ne 'OK';
			push(@estatus, "$slot_id=$s");
		}
		for my $alarm_id (sort keys %{$e->{alarm}}) {
			my $t = $e->{alarm}->{$alarm_id};
			my $s = $t->{status};
			next if $s eq 'NOT-REPORTABLE' or $s eq 'NOT-INSTALLED' or $s eq 'NO-DEVICE';
			$this->warning if $s ne 'OK';
			push(@estatus, "$alarm_id=$s(State=$t->{state},Audibility=$t->{audibility})");
		}
		#warn join("\n", @estatus);
		push(@status, "Enclosure: $eid(".join(',', @estatus).")");
	}

	return unless @status;

	$this->ok->message(join(', ', @status));
}

1;
