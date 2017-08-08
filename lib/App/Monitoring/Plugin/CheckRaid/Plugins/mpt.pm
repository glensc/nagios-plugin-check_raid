package App::Monitoring::Plugin::CheckRaid::Plugins::mpt;

use base 'App::Monitoring::Plugin::CheckRaid::Plugin';
use strict;
use warnings;

sub program_names {
	qw(mpt-status);
}

sub commands {
	{
		'get_controller_no' => ['-|', '@CMD', '-p'],
		'status' => ['-|', '@CMD', '-i', '$id'],
		'sync status' => ['-|', '@CMD', '-n'],
	}
}

sub sudo {
	my ($this, $deep) = @_;
	# quick check when running check
	return 1 unless $deep;

	my $cmd = $this->{program};
	(
	"CHECK_RAID ALL=(root) NOPASSWD: $cmd -i [0-9]",
	"CHECK_RAID ALL=(root) NOPASSWD: $cmd -i [1-9][0-9]",
	"CHECK_RAID ALL=(root) NOPASSWD: $cmd -n",
	"CHECK_RAID ALL=(root) NOPASSWD: $cmd -p",
	);
}

sub active {
	my ($this) = @_;

	# return if parent said NO
	my $res = $this->SUPER::active(@_);
	return $res unless $res;

	# there should be a controller. #95
	my $id = $this->get_controller;
	return defined($id);
}

# get controller from mpt-status -p
# FIXME: could there be multiple controllers?
sub get_controller {
	my $this = shift;

	my $fh = $this->cmd('get_controller_no');
	my $id;
	while (<$fh>) {
		chomp;
		if (/^Found.*id=(\d{1,2}),.*/) {
			$id = $1;
			last;
		}
	}
	$fh->close;

	return $id;
}

sub parse {
	my ($this, $id) = @_;

	my (%ld, %pd);

	my $fh = $this->cmd('status', { '$id' => $id });

	my %VolumeTypesHuman = (
		IS => 'RAID-0',
		IME => 'RAID-1E',
		IM => 'RAID-1',
	);

	while (<$fh>) {
		chomp;
		# mpt-status.c __print_volume_classic
		# ioc0 vol_id 0 type IM, 2 phy, 136 GB, state OPTIMAL, flags ENABLED
		if (my($vioc, $vol_id, $type, $disks, $vol_size, $vol_state, $vol_flags) =
			/^ioc(\d+)\s+ vol_id\s(\d+)\s type\s(\S+),\s (\d+)\sphy,\s (\d+)\sGB,\s state\s(\S+),\s flags\s(.+)/x) {
			$ld{$vol_id} = {
				ioc => int($vioc),
				vol_id => int($vol_id),
				# one of: IS, IME, IM
				vol_type => $type,
				raid_level => $VolumeTypesHuman{$type},
				phy_disks => int($disks),
				size => int($vol_size),
				# one of: OPTIMAL, DEGRADED, FAILED, UNKNOWN
				status => $vol_state,
				# array of: ENABLED, QUIESCED, RESYNC_IN_PROGRESS, VOLUME_INACTIVE or NONE
				flags => [ split ' ', $vol_flags ],
			};
		}

		# ./include/lsi/mpi_cnfg.h
		# typedef struct _RAID_PHYS_DISK_INQUIRY_DATA
		# {
		#   U8 VendorID[8];            /* 00h */
		#   U8 ProductID[16];          /* 08h */
		#   U8 ProductRevLevel[4];     /* 18h */
		#   U8 Info[32];               /* 1Ch */
		# }
		# mpt-status.c __print_physdisk_classic
		# ioc0 phy 0 scsi_id 0 IBM-ESXS PYH146C3-ETS10FN RXQN, 136 GB, state ONLINE, flags NONE
		# ioc0 phy 0 scsi_id 1 ATA      ST3808110AS      J   , 74 GB, state ONLINE, flags NONE
		# ioc0 phy 0 scsi_id 1 ATA      Hitachi HUA72101 AJ0A, 931 GB, state ONLINE, flags NONE
		elsif (my($pioc, $num, $phy_id, $vendor, $prod_id, $rev, $size, $state, $flags) =
			/^ioc(\d+)\s+ phy\s(\d+)\s scsi_id\s(\d+)\s (.{8})\s+(.{16})\s+(.{4})\s*,\s (\d+)\sGB,\s state\s(\S+),\s flags\s(.+)/x) {
			$pd{$num} = {
				ioc => int($pioc),
				num => int($num),
				phy_id => int($phy_id),
				vendor => $vendor,
				prod_id => $prod_id,
				rev => $rev,
				size => int($size),
				# one of: ONLINE, MISSING, NOT_COMPATIBLE, FAILED, INITIALIZING, OFFLINE_REQUESTED, FAILED_REQUESTED, OTHER_OFFLINE, UNKNOWN
				status => $state,
				# array of: OUT_OF_SYNC, QUIESCED or NONE
				flags => [ split ' ', $flags ],
			};
		} else {
			warn "mpt unparsed: [$_]";
			$this->unknown;
		}
	}
	$fh->close;

	# extra parse, if mpt-status has -n flag, can process also resync state
	# TODO: if -n becames default can do this all in one run
	my $resyncing = grep {/RESYNC_IN_PROGRESS/} map { @{$_->{flags}} } values %ld;
	if ($resyncing) {
		my $fh = $this->cmd('sync status');
		while (<$fh>) {
			if (/^ioc:\d+/) {
				# ignore
			}
			# mpt-status.c GetResyncPercentage
			# scsi_id:0 70%
			elsif (my($scsi_id, $percent) = /^scsi_id:(\d+) (\d+)%/) {
				$pd{$scsi_id}{resync} = int($percent);
			} else {
				warn "mpt unparsed: [$_]";
				$this->unknown;
			}
		}
		$fh->close;
	}

	return {
		'logical' => { %ld },
		'physical' => { %pd },
	};
}

sub check {
	my $this = shift;

	# status messages pushed here
	my @status;

	my $id = $this->get_controller;
	my $status = $this->parse($id);

	# process logical units
	while (my($d, $u) = each %{$status->{logical}}) {
		next unless $this->valid($d);

		my $s = $u->{status};
		if ($s =~ /INITIAL|INACTIVE/) {
			$this->warning;
		} elsif ($s =~ /RESYNC/) {
			$this->resync;
		} elsif ($s =~ /DEGRADED|FAILED/) {
			$this->critical;
		} elsif ($s !~ /ONLINE|OPTIMAL/) {
			$this->unknown;
		}

		# FIXME: this resync_in_progress is separate state of same as value in status?
		if (grep { /RESYNC_IN_PROGRESS/ } @{$u->{flags}}) {
			# find matching disks
			my @disks = grep {$_->{ioc} eq $u->{ioc} } values %{$status->{physical}};
			# collect percent for each disk
			my @percent = map { $_->{resync}.'%'} @disks;
			$s .= ' RESYNCING: '.join('/', @percent);
		}
		push(@status, "Volume $d ($u->{raid_level}, $u->{phy_disks} disks, $u->{size} GiB): $s");
	}

	# process physical units
	while (my($d, $u) = each %{$status->{physical}}) {
		my $s = $u->{status};
		# remove uninteresting flags
		my @flags = grep {!/NONE/} @{$u->{flags}};

		# skip print if nothing in flags and disk is ONLINE
		next unless @flags and $s eq 'ONLINE';

		$s .= ' ' . join(' ', @flags);
		push(@status, "Disk $d ($u->{size} GiB):$s");
		$this->critical;
	}

	return unless @status;

	$this->ok->message(join(', ', @status));
}

1;
