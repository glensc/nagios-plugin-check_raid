package App::Monitoring::Plugin::CheckRaid::Plugins::lvm;

# Package to check lvm raid

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
		'dmsetup' => ['-|', '@CMD', 'status', '--target=raid'],
	}
}

sub check {
	my $this = shift;

	my @status;
	my @raid_list;
	my $rh = $this->cmd('dmsetup');
	while (<$rh>) {
		chomp;
		push @raid_list, $_;
	}
	close $rh;

	my $raid;

	foreach $raid (@raid_list)
	{
		my ($_lv_name, $_s, $_l, $_raid, $_raid_type, $_devices, $_health_chars, $_sync_ratio, $_sync_action, $_mismatch_cnt) = split(/ /, $raid);

		if($_health_chars =~ /D/)
		{
			$this->critical;
		}

		$_sync_action =~ s/^\s+|\s+$//g;
		if ($_sync_action eq 'check' or $_sync_action eq 'repair' or $_sync_action eq 'init')
		{
			$this->warning;
		}

		push(@status, "$_lv_name:$_sync_action");
	}

	return unless @status;

	$this->ok->message(join(', ', @status));
}

1;
