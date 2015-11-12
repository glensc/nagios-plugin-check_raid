package App::Monitoring::Plugin::CheckRaid::Plugins::lsraid;

# Linux, software RAID
# Broken: missing test data

use base 'App::Monitoring::Plugin::CheckRaid::Plugin';
use strict;
use warnings;

sub program_names {
	shift->{name};
}

sub commands {
	{
		'list' => ['-|', '@CMD', '-A', '-p'],
	}
}

sub sudo {
	my ($this, $deep) = @_;
	# quick check when running check
	return 1 unless $deep;

	my $cmd = $this->{program};
	"CHECK_RAID ALL=(root) NOPASSWD: $cmd -A -p"
}

sub check {
	my $this = shift;

	# status messages pushed here
	my @status;

	my $fh = $this->cmd('list');
	while (<$fh>) {
		next unless (my($n, $s) = m{/dev/(\S+) \S+ (\S+)});
		next unless $this->valid($n);
		if ($s =~ /good|online/) {
			# no worries
		} elsif ($s =~ /sync/) {
			$this->warning;
		} else {
			$this->critical;
		}
		push(@status, "$n:$s");
	}
	close $fh;

	return unless @status;

	$this->message(join(', ', @status));
}

1;
