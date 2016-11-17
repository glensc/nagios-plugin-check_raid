package App::Monitoring::Plugin::CheckRaid::Plugins::metastat;

# Solaris, software RAID

use base 'App::Monitoring::Plugin::CheckRaid::Plugin';
use strict;
use warnings;

sub program_names {
	shift->{name};
}

sub commands {
	{
		'metastat' => ['>&2', '@CMD'],
	}
}

sub sudo {
	my ($this, $deep) = @_;
	# quick check when running check
	return 1 unless $deep;

	my $cmd = $this->{program};
	"CHECK_RAID ALL=(root) NOPASSWD: $cmd"
}

sub active {
	my ($this) = @_;

	# return if parent said NO
	my $res = $this->SUPER::active(@_);
	return $res unless $res;

	my $output = $this->get_metastat;
	return !!@$output;
}

sub get_metastat {
	my $this = shift;

	# cache inside single run
	return $this->{output} if defined $this->{output};

	my $fh = $this->cmd('metastat');
	my @data;
	while (<$fh>) {
		chomp;
		last if /there are no existing databases/;
		push(@data, $_);
	}

	return $this->{output} = \@data;
}

sub check {
	my $this = shift;

	my ($d, $sd);

	# status messages pushed here
	my @status;
	my $output = $this->get_metastat;

	foreach (@$output) {
		if (/^(\S+):/) { $d = $1; $sd = ''; next; }
		if (/Submirror \d+:\s+(\S+)/) { $sd = $1; next; }
		if (/Device:\s+(\S+)/) { $sd = $1; next; }
		if (my($s) = /State: (\S.+\w)/) {
			if ($sd and $this->valid($sd) and $this->valid($d)) {
				if ($s =~ /Okay/i) {
					# no worries...
				} elsif ($s =~ /Resync/i) {
					$this->resync;
				} else {
					$this->critical;
				}
				push(@status, "$d:$sd:$s");
			}
		}

		if (defined $d && $d =~ /hsp/) {
			if (/(c[0-9]+t[0-9]+d[0-9]+s[0-9]+)\s+(\w+)/) {
				$sd = $1;
				my $s = $2;
				$this->warning if ($s !~ /Available/);
				push(@status, "$d:$sd:$s");
			}
		}
	}

	return unless @status;

	$this->ok->message(join(', ', @status));
}

1;
