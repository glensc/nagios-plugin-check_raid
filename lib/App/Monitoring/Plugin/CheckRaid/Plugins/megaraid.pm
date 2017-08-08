package App::Monitoring::Plugin::CheckRaid::Plugins::megaraid;

# MegaRAID
# Status: BROKEN: no test data

use base 'App::Monitoring::Plugin::CheckRaid::Plugin';
use strict;
use warnings;

sub sudo {
	my ($this) = @_;
	my $cat = $this->which('cat');

	my @sudo;
	foreach my $mr (</proc/mega*/*/raiddrives*>) {
		push(@sudo, "CHECK_RAID ALL=(root) NOPASSWD: $cat $mr") if -d $mr;
	}

	@sudo;
}

sub check {
	my $this = shift;
	# status messages pushed here
	my @status;

	foreach my $f (</proc/megaraid/*/raiddrives*>) { # vim/
		my $fh;
		if (-r $f) {
			open $fh, '<', $f or next;
=cut
		} else {
			my @CMD = ($cat, $f);
			unshift(@CMD, $sudo) if $> and $sudo;
			open($fh , '-|', @CMD) or next;
=cut
		}
		my ($n) = $f =~ m{/proc/megaraid/([^/]+)};
		while (<$fh>) {
			if (my($s) = /logical drive\s*:\s*\d+.*, state\s*:\s*(\S+)/i) {
				if ($s ne 'optimal') {
					$this->critical;
				}
				push(@status, "$n: $s");
				last;
			}
		}
		$fh->close;
	}

	return unless @status;

	$this->message(join(', ', @status));
}

1;
