package smartctl;
use parent -norequire, 'plugin';

# no registering as standalone plugin
#push(@utils::plugins, __PACKAGE__);

sub program_names {
	__PACKAGE__;
}

sub commands {
	{
		'smartctl' => ['-|', '@CMD', '-H', '$dev', '$diskopt$disk'],
	}
}


sub sudo {
	my ($this, $deep) = @_;
	# quick check when running check
	return 1 unless $deep;

	# nothing, as not standalone plugin yet
}

# check for -H parameter for physical disks
# this is currently called out from cciss plugin
# @param device list
# device list being an array of:
# - device to check (/dev/cciss/c0d0)
# - disk options (-dcciss)
# - disk number (0..15)
sub check {
	my $this = shift;
	my @devs = @_;

	unless (@devs) {
		$this->warning;
		$this->message("No devices to check");
		return;
	}

	# status message for devs, latter just joined for shorter messages
	my %status;

	foreach my $ref (@devs) {
		my ($dev, $diskopt, $disk) = @$ref;

		my $fh = $this->cmd('smartctl', { '$dev' => $dev, '$diskopt' => $diskopt => '$disk' => $disk });
		while (<$fh>) {
			chomp;

			# SMART Health Status: HARDWARE IMPENDING FAILURE GENERAL HARD DRIVE FAILURE [asc=5d, ascq=10]
			if (my($s, $sc) = /SMART Health Status: (.*?)(\s*\[asc=\w+, ascq=\w+\])?$/) {
				# use shorter output, message that hpacucli would use
				if ($s eq 'HARDWARE IMPENDING FAILURE GENERAL HARD DRIVE FAILURE') {
					$s = 'Predictive Failure';
				}

				if ($s eq 'Predictive Failure') {
					$this->warning;
				} elsif ($s !~ '^OK') {
					$this->critical;
				}
				push(@{$status{$s}}, $dev.'#'.$disk);
			}
		}
		close($fh);
	}

	return unless %status;

	$this->ok->message($this->join_status(\%status));
}

1;
