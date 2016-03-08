package App::Monitoring::Plugin::CheckRaid::Plugins::dm;

# Package to check Linux Device Mapper

# Linux LVM Mirrors
# https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/6/html/Logical_Volume_Manager_Administration/mirror_create.html
#
# Linux LVM RAID
# https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/6/html/Logical_Volume_Manager_Administration/raid_volumes.html
#
# Low-level:
# https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/6/html/Logical_Volume_Manager_Administration/device_mapper.html#mirror-map
# https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/6/html/Logical_Volume_Manager_Administration/device_mapper.html#dmraid-map

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
		"CHECK_RAID ALL=(root) NOPASSWD: $cmd status",
	);
}

sub commands {
	{
		'dmsetup' => [ '-|', '@CMD', 'status' ],
	}
}

sub parse_target {
	my ($this, $target, $data) = @_;

	my %h;

	# https://www.kernel.org/doc/Documentation/device-mapper/dm-raid.txt
	if ($target eq 'raid') {
		my @cols = qw(
			raid_type devices health_chars
			sync_ratio sync_action mismatch_cnt
		);

		@h{@cols} = split /\s+/, $data;
	}

	%h;
}

sub parse {
	my $this = shift;

	my @devices;
	my $fh = $this->cmd('dmsetup');
	while (<$fh>) {
		my %h;
		if (my ($dmname, $s, $l, $target, $rest) = m{^
			(\S+):\s+    # dmname
			(\S+)\s+     # s
			(\S+)\s+     # l
			(\S+)\s+     # target
			(.+)         # rest of the data
			}x) {
			%h = $this->parse_target($target, $rest);

			# skip target type not handled
			next unless %h;

			%h = (
				'dmname' => $dmname,
				's'      => $s,
				'l'      => $l,
				'target' => $target,
				%h,
			);
		}
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
