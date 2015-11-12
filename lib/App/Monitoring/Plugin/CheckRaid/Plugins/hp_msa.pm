package App::Monitoring::Plugin::CheckRaid::Plugins::hp_msa;

use base 'App::Monitoring::Plugin::CheckRaid::Plugin';
use App::Monitoring::Plugin::CheckRaid::SerialLine;
use strict;
use warnings;

sub active {
	my $this = shift;
	return $this->detect;
}

# check from /sys if there are any MSA VOLUME's present.
sub detect {
	my $this = shift;

	# allow --plugin-option=hp_msa-enabled to force this plugin to be enabled
	return 1 if exists $this->{options}{'hp_msa-enabled'};

	for my $file (</sys/block/*/device/model>) {
		open my $fh, '<', $file or next;
		my $model = <$fh>;
		close($fh);
		return 1 if ($model =~ /^MSA.+VOLUME/);
	}
	return 0;
}

sub check {
	my $this = shift;

	#  allow --plugin-option=hp_msa-serial=/dev/ttyS2 to specify serial line
	my $ctldevice = $this->{options}{'hp_msa-serial'} || '/dev/ttyS0';

	# status messages pushed here
	my @status;

	my %opts = ();
	$opts{lockdir} = $this->{lockdir} if $this->{lockdir};

	my $modem = App::Monitoring::Plugin::CheckRaid::SerialLine->new($ctldevice, %opts);
	my $fh = $modem->open();
	unless ($fh) {
		$this->warning;
		$this->message("Can't open $ctldevice");
		return;
	}

	# check first controller
	print $fh "\r";
	print $fh "show globals\r";
	print $fh "show this_controller\r";
	print $fh "show other_controller\r";
	# this will issue termination match, ie. invalid command
	print $fh "exit\r";

	my ($c, %c, %t);
	while (<$fh>) {
		chomp;
		s/[\n\r]$//;
		last if /Invalid CLI command/;

		# Temperature:
		# EMU: 23 Celsius,  73 Fahrenheit
		# PS1: 22 Celsius,  71 Fahrenheit
		# PS2: 22 Celsius,  71 Fahrenheit
		if (my($s, $c) = /(\S+): (\d+) Celsius,\s+\d+ Fahrenheit/) {
			$t{$s} = int($c);
			next;
		}

		# Controller 1 (right controller):
		if (my($s) = /^(Controller \d+)/) {
			$c = $s;
			$c{$c} = [];
			next;
		}
		# Surface Scan: Running, LUN 10 (68% Complete)
		if (my($s, $m) = /Surface Scan:\s+(\S+)[,.]\s*(.*)/) {
			if ($s eq 'Running') {
				my ($l, $p) = $m =~ m{(LUN \d+) \((\d+)% Complete\)};
				push(@{$c{$c}}, "Surface: $l ($p%)");
				$this->warning;
			} elsif ($s ne 'Complete') {
				push(@{$c{$c}}, "Surface: $s, $m");
				$this->warning;
			}
			next;
		}
		# Rebuild Status: Running, LUN 0 (67% Complete)
		if (my($s, $m) = /Rebuild Status:\s+(\S+)[,.]\s*(.*)/) {
			if ($s eq 'Running') {
				my ($l, $p) = $m =~ m{(LUN \d+) \((\d+)% Complete\)};
				push(@{$c{$c}}, "Rebuild: $l ($p%)");
				$this->warning;
			} elsif ($s ne 'Complete') {
				push(@{$c{$c}}, "Rebuild: $s, $m");
				$this->warning;
			}
			next;
		}
		# Expansion: Complete.
		if (my($s, $m) = /Expansion:\s+(\S+)[.,]\s*(.*)/) {
			if ($s eq 'Running') {
				my ($l, $p) = $m =~ m{(LUN \d+) \((\d+)% Complete\)};
				push(@{$c{$c}}, "Expansion: $l ($p%)");
				$this->warning;
			} elsif ($s ne 'Complete') {
				push(@{$c{$c}}, "Expansion: $s, $m");
				$this->warning;
			}
			next;
		}
	}
	$modem->close();

	foreach $c (sort { $a cmp $b } keys %c) {
		my $s = $c{$c};
		$s = join(', ', @$s);
		$s = 'OK' unless $s;
		push(@status, "$c: $s");
	}

	# check that no temp is over the treshold
	my $warn = 28;
	my $crit = 33;
	while (my($t, $c) = each %t) {
		if ($c > $crit) {
			push(@status, "$t: ${c}C");
			$this->critical;
		} elsif ($c > $warn) {
			push(@status, "$t: ${c}C");
			$this->warning;
		}
	}

	return unless @status;

	$this->message(join(', ', @status));
}

1;
