package App::Monitoring::Plugin::CheckRaid::Plugins::megarc;

# LSI MegaRaid or Dell Perc arrays
# Check the status of all arrays on all Lsi MegaRaid controllers on the local
# machine. Uses the megarc program written by Lsi to get the status of all
# arrays on all local Lsi MegaRaid controllers.
#
# check designed from check_lsi_megaraid:
# http://www.monitoringexchange.org/cgi-bin/page.cgi?g=Detailed/2416.html;d=1
# Perl port (check_raid) by Elan Ruusamäe.

use base 'App::Monitoring::Plugin::CheckRaid::Plugin';
use strict;
use warnings;

sub program_names {
	shift->{name};
}

sub commands {
	{
		'controller list' => ['-|', '@CMD', '-AllAdpInfo', '-nolog'],
		'controller config' => ['-|', '@CMD', '-dispCfg', '-a$controller', '-nolog'],
	}
}

sub sudo {
	my ($this, $deep) = @_;
	# quick check when running check
	return 1 unless $deep;

	my $cmd = $this->{program};
	(
		"CHECK_RAID ALL=(root) NOPASSWD: $cmd -AllAdpInfo -nolog",
		"CHECK_RAID ALL=(root) NOPASSWD: $cmd -dispCfg -a* -nolog",
	);
}

sub check {
	my $this = shift;

	# status messages pushed here
	my @status;

	# get controllers
	my $fh = $this->cmd('controller list');
	my @lines = <$fh>;
	$fh->close;

	if ($lines[11] =~ /No Adapters Found/) {
		$this->warning;
		$this->message("No LSI adapters were found on this machine");
		return;
	}

	my @c;
	foreach (@lines[12..$#lines]) {
		if (my ($id) = /^\s*(\d+)/) {
			push(@c, int($id));
		}
	}
	unless (@c) {
		$this->warning;
		$this->message("No LSI adapters were found on this machine");
		return;
	}

	foreach my $c (@c) {
		my $fh = $this->cmd('controller config', { '$controller' => $c });
		my (%d, %s, $ld);
		while (<$fh>) {
			# Logical Drive : 0( Adapter: 0 ):  Status: OPTIMAL
			if (my($d, $s) = /Logical Drive\s+:\s+(\d+).+Status:\s+(\S+)/) {
				$ld = $d;
				$s{$ld} = $s;
				next;
			}
			# SpanDepth :01     RaidLevel: 5  RdAhead : Adaptive  Cache: DirectIo
			if (my($s) = /RaidLevel:\s+(\S+)/) {
				$d{$ld} = $s if defined $ld;
				next;
			}
		}
		$fh->close;

		# now process the details
		unless (keys %d) {
			$this->message("No arrays found on controller $c");
			$this->warning;
			return;
		}

		while (my($d, $s) = each %s) {
			if ($s ne 'OPTIMAL') {
				# The Array number here is incremented by one because of the
				# inconsistent way that the LSI tools count arrays.
				# This brings it back in line with the view in the bios
				# and from megamgr.bin where the array counting starts at
				# 1 instead of 0
				push(@status, "Array ".(int($d) + 1)." status is ".$s{$d}." (Raid-$s on adapter $c)");
				$this->critical;
				next;
			}

			push(@status, "Logical Drive $d: $s");
		}
	}

	return unless @status;

	$this->ok->message(join(', ', @status));
}

1;
