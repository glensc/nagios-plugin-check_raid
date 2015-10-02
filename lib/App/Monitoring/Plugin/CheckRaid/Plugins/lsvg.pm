package lsvg;
# AIX LVM
use parent -norequire, 'plugin';

# register
# Status: broken (no test data)
#push(@utils::plugins, __PACKAGE__);

sub program_names {
	__PACKAGE__;
}

sub commands {
	{
		'lsvg' => ['-|', '@CMD'],
		'lsvg list' => ['-|', '@CMD', '-l', '$vg'],
	}
}

sub sudo {
	my ($this, $deep) = @_;
	# quick check when running check
	return 1 unless $deep;

	my $cmd = $this->{program};
	(
		"CHECK_RAID ALL=(root) NOPASSWD: $cmd",
		"CHECK_RAID ALL=(root) NOPASSWD: $cmd -l *",
	)
}

sub check {
	my $this = shift;

	# status messages pushed here
	my @status;

	my @vg;
	my $fh = $this->cmd('lsvg');
	while (<$fh>) {
		chomp;
		push @vg, $_;
	}
	close $fh;

	foreach my $vg (@vg) {
		next unless $this->valid($vg); # skip entire VG

		my $fh = $this->cmd('lsvg list', { '$vg' => $vg });

		while (<$fh>) {
			my @f = split /\s/;
			my ($n, $s) = ($f[0], $f[5]);
			next if (!$this->valid($n) or !$s);
			next if ($f[3] eq $f[2]); # not a mirrored LV

			if ($s =~ m#open/(\S+)#i) {
				$s = $1;
				if ($s ne 'syncd') {
					$this->critical;
				}
				push(@status, "lvm:$n:$s");
			}
		}
		close $fh;
	}

	return unless @status;

	$this->message(join(', ', @status));
}

1;
