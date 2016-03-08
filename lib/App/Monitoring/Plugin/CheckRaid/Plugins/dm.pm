package App::Monitoring::Plugin::CheckRaid::Plugins::dm;

# Package to check Linux LVM RAID
# https://www.kernel.org/doc/Documentation/device-mapper/dm-raid.txt

use base 'App::Monitoring::Plugin::CheckRaid::Plugin';
use strict;
use warnings;

sub program_names {
	qw(dmsetup);
}

sub sudo {
	my ($this, $deep) = @_;
	# quick check when running check
	return 1 unless $deep;

	my $cmd = $this->{program};
	(
		"CHECK_RAID ALL=(root) NOPASSWD: $cmd status --target=raid",
	);
}

sub commands {
	{
		'dmsetup' => [ '-|', '@CMD', 'status', '--target=raid' ],
	}
}

sub parse {
	my $this = shift;

	my @columns = qw[
		dmname s l raid
		raid_type devices health_chars
		sync_ratio sync_action mismatch_cnt
	];

	my @devices;
	my $fh = $this->cmd('dmsetup');
	while (<$fh>) {
		my %h;
		@h{@columns} = split;
		$h{dmname} =~ s/:$//;
		push @devices, { %h };
	}
	close $fh;
	return \@devices;
}

sub check {
	my $this = shift;

	my $c = $this->parse;

	my @status;
	foreach my $dm (@$c)
	{
		# <health_chars>  One char for each device, indicating:
		# 'A' = alive and in-sync,
		# 'a' = alive but not in-sync,
		# 'D' = dead/failed.
		$this->critical if ($dm->{health_chars} =~ /D/);
		$this->warning if ($dm->{health_chars} =~ /a/);

		# <sync_action>   One of the following possible states:
		# idle    - No synchronization action is being performed.
		# frozen  - The current action has been halted.
		# resync  - Array is undergoing its initial synchronization or...
		# recover - A device in the array is being rebuilt or...
		# check   - A user-initiated full check of the array is...
		# repair  - The same as "check", but discrepancies are...
		# reshape - The array is undergoing a reshape.
		if ($dm->{sync_action} =~ /^(check|repair|init)$/)
		{
			$this->warning;
		}

		push(@status, "$dm->{dmname}:$dm->{sync_action}");
	}

	return unless @status;

	$this->ok->message(join(', ', @status));
}

1;
