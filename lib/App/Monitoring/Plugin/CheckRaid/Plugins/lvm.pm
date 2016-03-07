package App::Monitoring::Plugin::CheckRaid::Plugins::lvm;

# Package to check Linux LVM RAID

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
		dmname s l
		raid
		raidraid_type
		devices
		health_chars
		sync_ratio
		sync_action
		mismatch_cnt
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
		if ($dm->{health_chars} =~ /D/)
		{
			$this->critical;
		}

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
