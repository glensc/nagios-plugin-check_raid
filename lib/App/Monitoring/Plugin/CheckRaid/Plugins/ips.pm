package App::Monitoring::Plugin::CheckRaid::Plugins::ips;

# Serveraid IPS
# Tested on IBM xSeries 346 servers with Adaptec ServeRAID 7k controllers.
# The ipssend version was v7.12.14.

use base 'App::Monitoring::Plugin::CheckRaid::Plugin';
use strict;
use warnings;

sub program_names {
	qw(ipssend);
}

sub commands {
	{
		'list logical drive' => ['-|', '@CMD', 'GETCONFIG', '1', 'LD'],
	}
}

sub sudo {
	my ($this, $deep) = @_;
	# quick check when running check
	return 1 unless $deep;

	my $cmd = $this->{program};
	"CHECK_RAID ALL=(root) NOPASSWD: $cmd getconfig 1 LD"
}

sub check {
	my $this = shift;

	# status messages pushed here
	my @status;

	my $n;
	my $fh = $this->cmd('list logical drive');
	while (<$fh>) {
		if (/drive number (\d+)/i){
			$n = $1;
			next;
		}

		next unless $n;
		next unless $this->valid($n);
		next unless (my($s, $c) = /Status .*: (\S+)\s+(\S+)/);

		if ($c =~ /SYN|RBL/i) { # resynching
			$this->resync;
		} elsif ($c !~ /OKY/i) { # not OK
			$this->critical;
		}

		push(@status, "$n:$s");
	}
	$fh->close;

	return unless @status;

	$this->ok->message(join(', ', @status));
}

1;
