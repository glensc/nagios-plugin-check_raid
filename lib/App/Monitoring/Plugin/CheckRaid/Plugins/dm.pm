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

sub active {
	my ($this, $sudo) = @_;

	# return if parent said NO
	my $res = $this->SUPER::active(@_);
	return $res unless $res;

	# check if there really are any devices
	my $c = $this->parse;
	return !!@$c;
}

sub sudo {
	my ($this, $deep) = @_;
	# quick check when running check
	return 1 unless $deep;

	my $cmd = $this->{program};
	(
		"CHECK_RAID ALL=(root) NOPASSWD: $cmd status --noflush",
		"CHECK_RAID ALL=(root) NOPASSWD: $cmd status",
	);
}

sub commands {
	{
		'dmsetup'         => [ '-|', '@CMD', 'status' ],
		'dmsetup noflush' => [ '-|', '@CMD', 'status', '--noflush' ],
	}
}

# https://www.kernel.org/doc/Documentation/device-mapper/dm-raid.txt
sub parse_raid {
	local $_ = shift;

	# https://github.com/torvalds/linux/blob/v3.18/drivers/md/dm-raid.c#L1377
	# https://github.com/torvalds/linux/blob/v3.18/drivers/md/dm-raid.c#L1409-L1423
	# https://github.com/torvalds/linux/blob/v3.18/drivers/md/dm-raid.c#L1425-L1435
	# https://github.com/torvalds/linux/blob/v3.18/drivers/md/dm-raid.c#L1437-L1442
	# https://github.com/torvalds/linux/blob/v3.18/drivers/md/dm-raid.c#L1444-L1452
	my @cols = qw(
		raid_type raid_disks
		status_chars
		sync_ratio
		sync_action
		mismatch_cnt
	);

	my %h;
	@h{@cols} = split;

	\%h;
}

# https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/6/html/Logical_Volume_Manager_Administration/device_mapper.html#mirror-map
sub parse_mirror {
	local $_ = shift;

	my %h;

	# https://github.com/torvalds/linux/blob/v3.18/drivers/md/dm-raid1.c#L1355
	my @parts = split;

	# https://github.com/torvalds/linux/blob/v3.18/drivers/md/dm-raid1.c#L1365
	$h{nr_mirrors} = shift @parts;

	# https://github.com/torvalds/linux/blob/v3.18/drivers/md/dm-raid1.c#L1366-L1369
	my @devs;
	for (my $i = 0; $i < $h{nr_mirrors}; $i++) {
		push(@devs, shift @parts);
	}
	$h{devices} = \@devs;

	# https://github.com/torvalds/linux/blob/v3.18/drivers/md/dm-raid1.c#L1372-L1374
	# some ratio?
	$h{ratio} = shift @parts;
	# param count? always '1'
	shift @parts;
	# the 'buffer' filled with status chars
	$h{status_chars} = shift @parts;

	# log device information
	# https://github.com/torvalds/linux/blob/v3.18/drivers/md/dm-log.c#L807-L810
	# log params, always '3'
	shift @parts;
	my %l;
	$l{type} = shift @parts;
	$l{device} = shift @parts;
	# status: F->D->A
	$l{status_char} = shift @parts;
	$h{log} = { %l };

	# for debugging. fill only if something remains not parsed
	$h{_remaining} = join ' ', @parts if @parts;

	\%h;
}

sub parse_target {
	my ($target, $data) = @_;

	return parse_raid($data) if $target eq 'raid';
	return parse_mirror($data) if $target eq 'mirror';
	undef;
}

sub get_fh {
	my $this = shift;

	# use dmsetup --noflush, requires LVM >= 2.02.97
	# if that fails, fall back to just dmsetup
	# https://github.com/glensc/nagios-plugin-check_raid/issues/130#issuecomment-194476070
	my $fh = $this->cmd('dmsetup noflush');
	$fh = $this->cmd('dmsetup') if eof $fh;

	return $fh;
}

sub parse {
	my $this = shift;

	# cache for single run
	if (!defined($this->{parsed})) {
		$this->{parsed} = $this->_parse;
	}

	return $this->{parsed};
}

sub _parse {
	my $this = shift;

	my @devices;
	my $fh = $this->get_fh();
	while (<$fh>) {
		# skip comments.
		# not present in dmsetup output, but our test files may have.
		next if /^#/;

		last if /No devices found/;

		if (my ($dmname, $s, $l, $target, $rest) = m{^
			(\S+):\s+       # dmname
			(\d+)\s+        # start
			(\d+)\s+        # length
			(\S+)           # target
			(?:\s+(.+))?    # rest of the data
			\s?             # there may be trailing space
			$}x) {
			my $h = parse_target($target, $rest);

			# skip target type not handled
			next unless $h;

			my %h = (
				'dmname' => $dmname,
				's'      => $s,
				'l'      => $l,
				'target' => $target,
				%$h,
			);
			push @devices, \%h;
			next;
		}

		warn "Unhandled:[$_]";
		$this->unknown;
	}
	$fh->close;

	return \@devices;
}

sub check {
	my $this = shift;

	my $c = $this->parse;

	if (!@$c) {
		$this->noraid->message("No devices to check");
		return;
	}

	my @status;
	foreach my $dm (@$c)
	{
		# <status_chars>  One char for each device, indicating:
		# 'A' = alive and in-sync (mirror, raid1, raid)
		# 'a' = alive but not in-sync (mirror, raid1)
		# 'D' = dead/failed (mirror, raid1, raid)
		# 'S' = Sync (mirror, raid1)
		# 'mirror'/'raid1': https://github.com/torvalds/linux/blob/v3.18/drivers/md/dm-raid1.c#L1330-L1342
		# 'raid': https://github.com/torvalds/linux/blob/v3.18/drivers/md/dm-raid.c#L1409-L1414
		$this->critical if ($dm->{status_chars} =~ /D/);
		$this->warning if ($dm->{status_chars} =~ /[aS]/);

		my @s = "$dm->{dmname}:$dm->{status_chars}";

		# <sync_action>   One of the following possible states:
		# idle    - No synchronization action is being performed.
		# frozen  - The current action has been halted.
		# resync  - Array is undergoing its initial synchronization or...
		# recover - A device in the array is being rebuilt or...
		# check   - A user-initiated full check of the array is...
		# repair  - The same as "check", but discrepancies are...
		# reshape - The array is undergoing a reshape.
		if ($dm->{sync_action}) {
			push(@s, $dm->{sync_action});
			if ($dm->{sync_action} =~ /^(check|repair|init)$/) {
				$this->warning;
			}
		}
		push(@status, join(' ', @s));
	}

	return unless @status;

	$this->ok->message(join(', ', @status));
}

1;
