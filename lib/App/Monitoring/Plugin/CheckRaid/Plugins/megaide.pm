package App::Monitoring::Plugin::CheckRaid::Plugins::megaide;

# MegaIDE RAID controller
# Status: BROKEN: no test data

use base 'App::Monitoring::Plugin::CheckRaid::Plugin';
use strict;
use warnings;

sub sudo {
	my ($this) = @_;
	my $cat = $this->which('cat');

	"CHECK_RAID ALL=(root) NOPASSWD: $cat /proc/megaide/0/status";
}

sub check {
	my $this = shift;
	my $fh;

	# status messages pushed here
	my @status;

	foreach my $f (</proc/megaide/*/status>) { # / silly comment to fix vim syntax hilighting
		if (-r $f) {
			open $fh, '<', $f or next;
=cut
		} else {
			my @CMD = ($cat, $f);
			unshift(@CMD, $sudo) if $> and $sudo;
			open($fh , '-|', @CMD) or next;
=cut
		}
		while (<$fh>) {
			next unless (my($s, $n) = /Status\s*:\s*(\S+).*Logical Drive.*:\s*(\d+)/i);
			next unless $this->valid($n);
			if ($s ne 'ONLINE') {
				$this->critical;
				push(@status, "$n:$s");
			} else {
				push(@status, "$n:$s");
			}
			last;
		}
		close $fh;
	}

	return unless @status;

	$this->message(join(' ', @status));
}

1;
