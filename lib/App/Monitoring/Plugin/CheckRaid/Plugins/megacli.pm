package App::Monitoring::Plugin::CheckRaid::Plugins::megacli;

# MegaRAID SAS 8xxx controllers
# based on info from here:
# http://www.bxtra.net/Articles/2008-09-16/Dell-Perc6i-RAID-Monitoring-Script-using-MegaCli-LSI-CentOS-52-64-bits
# TODO: http://www.techno-obscura.com/~delgado/code/check_megaraid_sas
# TODO: process several adapters
# TODO: process drive temperatures
# TODO: check error counts
# TODO: hostspare information

use base 'App::Monitoring::Plugin::CheckRaid::Plugin';
use strict;
use warnings;

sub program_names {
	qw(MegaCli64 MegaCli megacli);
}

sub commands {
	{
		'pdlist' => ['-|', '@CMD', '-PDList', '-aALL', '-NoLog'],
		'ldinfo' => ['-|', '@CMD', '-LdInfo', '-Lall', '-aALL', '-NoLog'],
		'battery' => ['-|', '@CMD', '-AdpBbuCmd', '-GetBbuStatus', '-aALL', '-NoLog'],
	}
}

# TODO: process from COMMANDS
sub sudo {
	my ($this, $deep) = @_;
	# quick check when running check
	return 1 unless $deep;

	my $cmd = $this->{program};

	(
		"CHECK_RAID ALL=(root) NOPASSWD: $cmd -PDList -aALL -NoLog",
		"CHECK_RAID ALL=(root) NOPASSWD: $cmd -LdInfo -Lall -aALL -NoLog",
		"CHECK_RAID ALL=(root) NOPASSWD: $cmd -AdpBbuCmd -GetBbuStatus -aALL -NoLog",
	);
}

# parse physical devices
sub parse_pd {
	my $this = shift;

	my (@pd, %pd);
	my $rc = -1;
	my $fh = $this->cmd('pdlist');
	while (<$fh>) {
		if (my($s) = /Device Id: (\S+)/) {
			push(@pd, { %pd }) if %pd;
			%pd = ( dev => $s, state => undef, name => undef, predictive => undef );
			next;
		}

		if (my($s) = /Firmware state: (.+)/) {
			# strip the extra state:
			# 'Hotspare, Spun Up'
			# 'Hotspare, Spun down'
			# 'Online, Spun Up'
			# 'Online, Spun Up'
			# 'Online, Spun down'
			# 'Unconfigured(bad)'
			# 'Unconfigured(good), Spun Up'
			# 'Unconfigured(good), Spun down'
			$s =~ s/,.+//;
			$pd{state} = $s;

			if (defined($pd{predictive})) {
				$pd{state} = $pd{predictive};
			}
			next;
		}

		if (my($s) = /Predictive Failure Count: (\d+)/) {
			if ($s > 0) {
				$pd{predictive} = 'Predictive';
			}
			next;
		}

		if (my($s) = /Inquiry Data: (.+)/) {
			# trim some spaces
			$s =~ s/\s+/ /g; $s =~ s/^\s+|\s+$//g;
			$pd{name} = $s;
			next;
		}

		if (my($s) = /Exit Code: (\d+x\d+)/) {
			$rc = hex($s);
		}
		else {
			$rc = 0;
		}
	}
	push(@pd, { %pd }) if %pd;

	$this->critical unless close $fh;
	$this->critical if $rc;

	return \@pd;
}

sub parse_ld {
	my $this = shift;

	my (@ld, %ld);
	my $rc = -1;
	my $fh = $this->cmd('ldinfo');
	while (<$fh>) {
		if (my($drive_id, $target_id) = /Virtual (?:Disk|Drive)\s*:\s*(\d+)\s*\(Target Id:\s*(\d+)\)/i) {
			push(@ld, { %ld }) if %ld;
			# Default to DriveID:TargetID in case no Name is given ...
			%ld = ( name => "DISK$drive_id.$target_id", state => undef );
			next;
		}

		if (my($name) = /Name\s*:\s*(\S+)/) {
			# Add a symbolic name, if given
			$ld{name} = $name;
			next;
		}

		if (my($s) = /Virtual Drive Type\s*:\s*(\S+)/) {
			$ld{type} = $s;
			next;
		}

		if (my($s) = /State\s*:\s*(\S+)/) {
			$ld{state} = $s;
			next;
		}

		if (my($s) = /Default Cache Policy\s*:\s*(.+)/) {
			$ld{default_cache} = [split /,\s*/, $s];
			next;
		}

		if (my($s) = /Current Cache Policy\s*:\s*(.+)/) {
			$ld{current_cache} = [split /,\s*/, $s];
			next;
		}

		if (my($s) = /Exit Code: (\d+x\d+)/) {
			$rc = hex($s);
		} else {
			$rc = 0;
		}
	}
	push(@ld, { %ld }) if %ld;

	$this->critical unless close $fh;
	$this->critical if $rc;

	return \@ld;
}

# check battery
sub parse_bbu {
	my $this = shift;

	return undef unless $this->bbu_monitoring;

	my %default_bbu = (
		name => undef, state => '???', charging_status => '???', missing => undef,
		learn_requested => undef, replacement_required => undef,
		learn_cycle_requested => undef, learn_cycle_active => '???',
		pack_will_fail => undef, temperature => undef, temperature_state => undef,
		voltage => undef, voltage_state => undef
	);

	my (@bbu, %bbu);
	my $fh = $this->cmd('battery');
	while (<$fh>) {
		# handle when bbu status get gives an error. see issue #32
		if (my($s) = /Get BBU Status Failed/) {
			last;
		}

		if (my($s) = /BBU status for Adapter: (.+)/) {
			push(@bbu, { %bbu }) if %bbu;
			%bbu = %default_bbu;
			$bbu{name} = $s;
			next;
		}
#=cut
# according to current sample data, Battery State never has value
		if (my($s) = /Battery State\s*: ?(.*)/i) {
			if (!$s) { $s = 'Faulty'; };
			$bbu{state} = $s;
			next;
		}
#=cut
		if (my($s) = /Charging Status\s*: (\w*)/) {
			$bbu{charging_status} = $s;
			next;
		}
		if (my($s) = /Battery Pack Missing\s*: (\w*)/) {
			$bbu{missing} = $s;
			next;
		}
		if (my($s) = /Battery Replacement required\s*: (\w*)/) {
			$bbu{replacement_required} = $s;
			next;
		}
		if (my($s) = /Learn Cycle Requested\s*: (\w*)/) {
			$bbu{learn_cycle_requested} = $s;
			next;
		}
		if (my($s) = /Learn Cycle Active\s*: (\w*)/) {
			$bbu{learn_cycle_active} = $s;
			next;
		}
		if (my($s) = /Pack is about to fail & should be replaced\s*: (\w*)/) {
			$bbu{pack_will_fail} = $s;
			next;
		}
		# Temperature: 18 C
		if (my($s) = /Temperature: (\d+) C/) {
			$bbu{temperature} = $s;
			next;
		}
		# Temperature : OK
		if (my($s) = /  Temperature\s*: (\w*)/) {
			$bbu{temperature_state} = $s;
			next;
		}
		# Voltage: 4074 mV
		if (my($s) = /Voltage: (\d+) mV/) {
			$bbu{voltage} = $s;
			next;
		}
		# Voltage : OK
		if (my($s) = /Voltage\s*: (\w*)/) {
			$bbu{voltage_state} = $s;
			next;
		}

	}
	$this->critical unless close $fh;

	push(@bbu, { %bbu }) if %bbu;

	return \@bbu;
}

sub parse {
	my $this = shift;

	my $pd = $this->parse_pd;
	my $ld = $this->parse_ld;
	my $bbu = $this->parse_bbu;

	my @devs = @$pd if $pd;
	my @vols = @$ld if $ld;
	my @bats = @$bbu if $bbu;

	return {
		logical => $ld,
		physical => $pd,
		battery => $bbu,
	};
}

sub check {
	my $this = shift;

	my $c = $this->parse;

	my @vstatus;
	foreach my $vol (@{$c->{logical}}) {
		# skip CacheCade for now. #91
		if ($vol->{type} && $vol->{type} eq 'CacheCade') {
			next;
		}

		push(@vstatus, sprintf "%s:%s", $vol->{name}, $vol->{state});
		if ($vol->{state} ne 'Optimal') {
			$this->critical;
		}

		# check cache policy, #65
		my @wt = grep { /WriteThrough/ } @{$vol->{current_cache}};
		if (@wt) {
			my @default = grep { /WriteThrough/ } @{$vol->{default_cache}};
			# alert if WriteThrough is configured in default
			$this->cache_fail unless @default;
			push(@vstatus, "WriteCache:DISABLED");
		}
	}

	my %dstatus;
	foreach my $dev (@{$c->{physical}}) {
		if ($dev->{state} eq 'Online' || $dev->{state} eq 'Hotspare' || $dev->{state} eq 'Unconfigured(good)' || $dev->{state} eq 'JBOD') {
			push(@{$dstatus{$dev->{state}}}, sprintf "%02d", $dev->{dev});

		} else {
			$this->critical;
			# TODO: process other statuses
			push(@{$dstatus{$dev->{state}}}, sprintf "%02d (%s)", $dev->{dev}, $dev->{name});
		}
	}

	my (%bstatus, @bpdata, @blongout);
	foreach my $bat (@{$c->{battery}}) {
		if ($bat->{state} !~ /^(Operational|Optimal)$/) {
			# BBU learn cycle in progress.
			if ($bat->{charging_status} =~ /^(Charging|Discharging)$/ && $bat->{learn_cycle_active} eq 'Yes') {
				$this->bbulearn;
			} else {
				$this->critical;
			}
		}
		if ($bat->{missing} ne 'No') {
			$this->critical;
		}
		if ($bat->{replacement_required} ne 'No') {
			$this->critical;
		}
		if (defined($bat->{pack_will_fail}) && $bat->{pack_will_fail} ne 'No') {
			$this->critical;
		}
		if ($bat->{temperature_state} ne 'OK') {
			$this->critical;
		}
		if ($bat->{voltage_state} ne 'OK') {
			$this->critical;
		}

		# Short output.
		#
		# CRITICAL: megacli:[Volumes(1): NoName:Optimal; Devices(2): 06,07=Online; Batteries(1): 0=Non Operational]
		push(@{$bstatus{$bat->{state}}}, sprintf "%d", $bat->{name});
		# Performance data.
		# Return current battery temparature & voltage.
		#
		# Battery0=18;4074
		push(@bpdata, sprintf "Battery%s_T=%s;;;; Battery%s_V=%s;;;;", $bat->{name}, $bat->{temperature}, $bat->{name}, $bat->{voltage});

		# Long output.
		# Detailed plugin output.
		#
		# Battery0:
		#  - State: Non Operational
		#  - Missing: No
		#  - Replacement required: Yes
		#  - About to fail: No
		#  - Temperature: OK (18 °C)
		#  - Voltage: OK (4015 mV)
		push(@blongout, join("\n", grep {/./}
			"Battery$bat->{name}:",
			" - State: $bat->{state}",
			" - Charging status: $bat->{charging_status}",
			" - Learn cycle requested: $bat->{learn_cycle_requested}",
			" - Learn cycle active: $bat->{learn_cycle_active}",
			" - Missing: $bat->{missing}",
			" - Replacement required: $bat->{replacement_required}",
			defined($bat->{pack_will_fail}) ? " - About to fail: $bat->{pack_will_fail}" : "",
			" - Temperature: $bat->{temperature_state} ($bat->{temperature} C)",
			" - Voltage: $bat->{voltage_state} ($bat->{voltage} mV)",
		));
	}

	my @cstatus;
	push(@cstatus, 'Volumes(' . ($#{$c->{logical}} + 1) . '): ' . join(',', @vstatus));
	push(@cstatus, 'Devices(' . ($#{$c->{physical}} + 1) . '): ' . $this->join_status(\%dstatus));
	push(@cstatus, 'Batteries(' . ($#{$c->{battery}} + 1) . '): ' . $this->join_status(\%bstatus)) if @{$c->{battery}};
	my @status = join('; ', @cstatus);

	my @pdata;
	push(@pdata,
		join('\n', @bpdata)
	);
	my @longout;
	push(@longout,
		join('\n', @blongout)
	);
	return unless @status;

	# denote this plugin as ran ok
	$this->ok;

	$this->message(join(' ', @status));
	$this->perfdata(join(' ', @pdata));
	$this->longoutput(join(' ', @longout));
}

1;
