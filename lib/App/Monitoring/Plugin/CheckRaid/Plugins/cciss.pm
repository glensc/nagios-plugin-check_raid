package App::Monitoring::Plugin::CheckRaid::Plugins::cciss;

use base 'App::Monitoring::Plugin::CheckRaid::Plugin';
use App::Monitoring::Plugin::CheckRaid::Plugins::lsscsi;
use App::Monitoring::Plugin::CheckRaid::Plugins::smartctl;
use strict;
use warnings;

sub program_names {
	'cciss_vol_status';
}

sub commands {
	{
		'controller status' => ['-|', '@CMD', '@devs'],
		'controller status verbose' => ['-|', '@CMD', '-V', '@devs'],
		'cciss_vol_status version' => ['>&2', '@CMD', '-v'],

		'detect hpsa' => ['<', '/sys/module/hpsa/refcnt'],
		'detect cciss' => ['<', '/proc/driver/cciss'],
		'cciss proc' => ['<', '/proc/driver/cciss/$controller'],

		# for lsscsi, issue #109
		'lsscsi list' => ['-|', '@CMD', '-g'],
	}
}

sub sudo {
	my ($this, $deep) = @_;

	# quick check when running check
	return 1 unless $deep;

	my $cmd = $this->{program};

	my $v1_10 = $this->cciss_vol_status_version >= 1.10;

	my @sudo;
	my @cciss_devs = $this->detect;
	if (@cciss_devs) {
		my $c = join(' ', @cciss_devs);
		if ($v1_10) {
			push(@sudo, "CHECK_RAID ALL=(root) NOPASSWD: $cmd -V $c");
		} else {
			push(@sudo, "CHECK_RAID ALL=(root) NOPASSWD: $cmd $c");
		}
	}

	my @cciss_disks = $this->detect_disks(@cciss_devs);
	if (!$v1_10 && @cciss_disks) {
		my $smartctl = App::Monitoring::Plugin::CheckRaid::Plugins::smartctl->new();

		if ($smartctl->active) {
			my $cmd = $smartctl->{program};
			foreach my $ref (@cciss_disks) {
				my ($dev, $diskopt, $disk) = @$ref;
				# escape comma for sudo
				$diskopt =~ s/,/\\$&/g;
				push(@sudo, "CHECK_RAID ALL=(root) NOPASSWD: $cmd -H $dev $diskopt$disk");
			}
		}
	}

	return @sudo;
}

# detects if hpsa (formerly cciss) is present in system
sub detect {
	my $this = shift;

	my ($fh, @devs);

	# try lsscsi first if enabled and allowed
	my $lsscsi = App::Monitoring::Plugin::CheckRaid::Plugins::lsscsi->new('commands' => $this->{commands});
	my $use_lsscsi = defined($this->{use_lsscsi}) ? $this->{use_lsscsi} : $lsscsi->active;
	if ($use_lsscsi) {
		# for cciss_vol_status < 1.10 we need /dev/sgX nodes, columns which are type storage
		@devs = $lsscsi->list_sg;

		# cciss_vol_status 1.10 can process disk nodes too even if sg is not present
		my $v1_10 = $this->cciss_vol_status_version >= 1.10;
		if (!@devs && $v1_10) {
			@devs = $lsscsi->list_dd;
		}

		return wantarray ? @devs : \@devs if @devs;
	}

	# check hpsa devs
	eval { $fh = $this->cmd('detect hpsa'); };
	if ($fh) {
		my $refcnt = <$fh>;
		close $fh;

		if ($refcnt) {
			# TODO: how to figure which sgX is actually in use?
			# for now we collect all, and expect cciss_vol_status to ignore unknowns
			# refcnt seems to match number of sg devs: /sys/class/scsi_generic/sg*
			for (my $i = 0; $i < $refcnt; $i++) {
				my $dev = "/dev/sg$i";
				# filter via valid() so could exclude devs
				push(@devs, $dev) if $this->valid($dev);
			}
		}
	}
	undef($fh);

	# check legacy cciss devs
	eval { $fh = $this->cmd('detect cciss'); };
	if ($fh) {
		my @c = grep { !/^\./ } readdir($fh);
		close($fh);

		# find controllers
		#	cciss0: HP Smart Array P400i Controller
		#	Board ID: 0x3235103c
		#	Firmware Version: 4.06
		#	IRQ: 98
		#	Logical drives: 1
		#	Current Q depth: 0
		#	Current # commands on controller: 0
		#	Max Q depth since init: 249
		#	Max # commands on controller since init: 275
		#	Max SG entries since init: 31
		#	Sequential access devices: 0
		#
		#	cciss/c0d0:      220.12GB       RAID 1(1+0)
		for my $c (@c) {
			my $fh = $this->cmd('cciss proc', { '$controller' => $c });
			while (<$fh>) {
				# check "c*d0" - iterate over each controller
				next unless (my($dev) = m{^(cciss/c\d+d0):});
				$dev = "/dev/$dev";
				# filter via valid() so could exclude devs
				push(@devs, $dev) if $this->valid($dev);
			}
			close $fh;
		}
	}
	undef($fh);

	return wantarray ? @devs : \@devs;
}

# build list of cciss disks
# used by smartctl check
# just return all disks (0..15) for each cciss dev found
sub detect_disks {
	my $this = shift;

	my @devs;
	# build devices list for smartctl
	foreach my $scsi_dev (@_) {
		foreach my $disk (0..15) {
			push(@devs, [ $scsi_dev, '-dcciss,', $disk ]);
		}
	}
	return wantarray ? @devs : \@devs;
}

# parse version out of "cciss_vol_status version 1.09"
# NOTE: it prints the output to stderr, but may print to stdout in the future
sub cciss_vol_status_version {
	my $this = shift;

	# cache inside single run
	return $this->{cciss_vol_status_version} if defined $this->{cciss_vol_status_version};

	my $version = sub {
		my $fh = $this->nosudo_cmd('cciss_vol_status version');
		my ($line) = <$fh>;
		$fh->close;
		return 0 unless $line;

		if (my($v) = $line =~ /^cciss_vol_status version ([\d.]+)$/) {
			return 0 + $v;
		}
		return 0;
	};

	return $this->{cciss_vol_status_version} = &$version();
}

sub trim { my $s = shift; $s =~ s/^\s+|\s+$//g; return $s };

# we process until we find end of sentence (dot at the end of the line)
sub consume_diagnostic {
	my ($this, $fh) = @_;

	my $diagnostic = '';
	while (1) {
		my $s = <$fh>;
		last unless $s;
		chomp;
		$diagnostic .= ' '. trim($s);
		last if $s =~ /\.$/;
	}
	return trim($diagnostic);
}

# process to skip lines with physical location:
# "         connector 1I box 1 bay 4 ..."
sub consume_disk_map {
	my ($this, $fh) = @_;

	while (my $s = <$fh>) {
		chomp $s;
		# connector 1I box 1 bay 4
		last unless $s =~ /^\s+connector\s/;
	}
}

sub parse {
	my $this = shift;
	my @devs = @_;

	my (%c, $cdev);

	# cciss_vol_status 1.10 has -V option to print more info about controller and disks.
	my $v1_10 = $this->cciss_vol_status_version >= 1.10;

	# add all devs at once to commandline, cciss_vol_status can do that
	my $fh = $this->cmd($v1_10 ? 'controller status verbose' : 'controller status', { '@devs' => \@devs });
	while (<$fh>) {
		chomp;

		# skip empty lines and artificial comments (added by this project)
		next if /^$/ or /^#/;

		if (/Controller:/) {
			# this is first item when new controller is found
			# reset previous state
			undef $cdev;
			next;
		}

		# catch enclosures, print_bus_status()
		# /dev/cciss/c1d0: (Smart Array P800) Enclosure MSA70 (S/N: SGA651004J) on Bus 2, Physical Port 1E status: OK.
		# /dev/cciss/c0d0: (Smart Array 6i) Enclosure PROLIANT 6L2I (S/N: ) on Bus 0, Physical Port J1 status: OK.
		if (my($file, $board_name, $name, $sn, $bus, $port1, $port2, $status) = m{
			^(/dev/[^:]+):\s        # File
			\(([^)]+)\)\s           # Board Name
			Enclosure\s(.*?)\s      # Enclosure Name
			\(S/N:\s(\S*)\)\s       # Enclosure SN
			on\sBus\s(\d+),\s       # Bus Number
			Physical\sPort\s(.)     # physical_port1
			(.)\s                   # physical_port2
			status:\s(.*?)\.        # status (without a dot)
		}x) {
			$c{$file}{enclosures}{$bus} = {
				board_name => $board_name,
				name => $name,
				sn => $sn,
				bus => int($bus),
				phys1 => $port1,
				phys2 => $port2,
				status => $status,
			};
			next;
		}

		# volume status, print_volume_status()
		# /dev/cciss/c0d0: (Smart Array P400i) RAID 1 Volume 0 status: OK
		# /dev/sda: (Smart Array P410i) RAID 1 Volume 0 status: OK.
		# /dev/sda: (Smart Array P410i) RAID 5 Volume 0 status: OK.   At least one spare drive designated.  At least one spare drive has failed.
		if (my($file, $board_name, $raid_level, $volume_number, $certain, $status, $spare_drive_status) = m{
			^(/dev/[^:]+):\s        # File
			\(([^)]+)\)\s           # Board Name
			(RAID\s\d+|\([^)]+\))\s # RAID level
			Volume\s(\d+)           # Volume number
			(\(\?\))?\s             # certain?
			status:\s(.*?)\.        # status (without a dot)
			(.*)?                   # spare drive status messages
		}x) {
			$cdev = $file;
			$c{$file}{volumes}{$volume_number} = {
				board_name => $board_name,
				raid_level => $raid_level,
				volume_number => $volume_number,
				certain => int(not defined $certain),
				status => $status,
				spare_drive_status => trim($spare_drive_status),
			};

			$c{$file}{board_name} = $board_name;
			next;
		}

		next unless $cdev;

		if (my ($count) = /Physical drives: (\d+)/) {
			$c{$cdev}{'pd count'} = $count;
			next;
		}

		# check_physical_drives(file, fd);
		# NOTE: check for physical drives is enabled with -V or -s option (-V enables -s)
		# cciss_vol_status.c format_phys_drive_location()
		if (my ($phys1, $phys2, $box, $bay, $model, $serial_no, $fw_rev, $status) = m{
			\sconnector\s(.)(.)\s # Phys connector 1&2
			box\s(\d+)\s          # phys_box_on_bus
			bay\s(\d+)\s          # phys_bay_in_box
			(.{40})\s             # model
			(.{40})\s             # serial no
			(.{8})\s              # fw rev
			(.+)                  # status
		$}x) {
			my $slot = "$phys1$phys2-$box-$bay";
			$c{$cdev}{drives}{$slot} = {
				'slot' => $slot,
				'phys1' => $phys1,
				'phys2' => $phys2,
				'box' => int($box),
				'bay' => int($bay),

				'model' => trim($model),
				'serial' => trim($serial_no),
				'fw' => trim($fw_rev),
				'status' => $status,
			};
			next;
		}

		# TODO
		# check_fan_power_temp(file, ctlrtype, fd, num_controllers);

		# check_nonvolatile_cache_status(file, ctlrtype, fd, num_controllers);
		# /dev/cciss/c0d0(Smart Array P400i:0): Non-Volatile Cache status:
		if (my($file, $board_name, $instance) = m{^(/dev/[^(]+)\((.+):(\d+)\): Non-Volatile Cache status}) {
			# $file and $dev may differ, so store it
			$c{$cdev}{cache} = {
				'file' => $file,
				'board' => $board_name,
				'instance' => int($instance),
			};
			next;
		}

		if (defined($c{$cdev}{cache})) {
			my $cache = $c{$cdev}{cache};
			my %map = (
				configured => qr/Cache configured: (.+)/,
				read_cache_memory => qr/Read cache memory: (.+)/,
				write_cache_memory => qr/Write cache memory: (.+)/,
				write_cache_enabled => qr/Write cache enabled: (.+)/,
				flash_cache => qr/Flash backed cache present/,
				disabled_temporarily => qr/Write cache temporarily disabled/,
				disabled_permanently => qr/Write Cache permanently disabled/,
			);
			my $got;
			while (my($k, $r) = each %map) {
				next unless (my($v) = $_ =~ $r);
				$cache->{$k} = $v;
				$got = 1;

				# consume extended diagnostic
				if ($k =~ /disabled_(temporari|permanentl)ly/) {
					$cache->{"$k diagnostic"} = $this->consume_diagnostic($fh);
				}
			}

			next if $got;
		}

		# show_disk_map("  Failed drives:", file, fd, id, controller_lun, ctlrtype,
		# show_disk_map("  'Replacement' drives:", file, fd, id, controller_lun, ctlrtype,
		# show_disk_map("  Drives currently substituted for by spares:", file, fd, id, controller_lun, ctlrtype,
		if (/^  Failed drives:/ ||
			/^  'Replacement' drives:/ ||
			/^  Drives currently substituted for by spares:/
		) {
			# could store this somewhere, ignore for now
			$this->consume_disk_map($fh);
			next;
		}

		if (my($total_failed) = /Total of (\d+) failed physical drives detected on this logical drive\./) {
			$c{$cdev}{phys_failed} = $total_failed;
			next;
		}

		warn "Unparsed[$_]";
	}
	$fh->close;

	return \%c;
}

sub check {
	my $this = shift;
	my @devs = $this->detect;

	unless (@devs) {
		$this->warning;
		$this->message("No Smart Array Adapters were found on this machine");
		return;
	}

	# status messages pushed here
	my @status;

	my $res = $this->parse(@devs);
	for my $dev (sort {$a cmp $b} keys %$res) {
		my $c = $res->{$dev};
		my @bstatus;

		# check volumes
		my @vstatus;
		for my $vn (sort {$a cmp $b} keys %{$c->{volumes}}) {
			my $v = $c->{volumes}->{$vn};
			if ($v->{status} !~ '^OK') {
				$this->critical;
			}
			push(@vstatus, "Volume $v->{volume_number} ($v->{raid_level}): $v->{status}");
		}

		push(@bstatus, @vstatus) if @vstatus;

		# check physical devices
		if ($c->{'pd count'}) {
			my %pd;
			for my $ps (sort {$a cmp $b} keys %{$c->{drives}}) {
				my $pd = $c->{drives}{$ps};
				if ($pd->{status} !~ '^OK') {
					$this->critical;
					$ps .= "($pd->{serial})";
				}
				push(@{$pd{$pd->{status}}}, $ps);
			}
			push(@bstatus, "Drives($c->{'pd count'}): ". $this->join_status(\%pd));
		}

		# check enclosures
		if ($c->{enclosures}) {
			my @e;
			for my $i (sort {$a cmp $b} keys %{$c->{enclosures}}) {
				my $e = $c->{enclosures}{$i};

				# enclosure name may be missing, identify by connection
				my $s = $e->{name} || "$e->{bus}-$e->{phys1}$e->{phys2}";
				# enclosure S/N may be missing
				$s .= "($e->{sn})" if $e->{sn};
				$s .= ": $e->{status}";
				if ($e->{status} !~ '^OK') {
					$this->critical;
				}
				push(@e, $s);
			}
			push(@bstatus, "Enclosures: ". join(', ', @e));
		}

		# check cache
		if ($c->{cache} && $c->{cache}->{configured} eq 'Yes') {
			my $cache = $c->{cache};
			my @cstatus = 'Cache:';

			if ($cache->{write_cache_enabled} eq 'Yes') {
				push(@cstatus, "WriteCache");

			} elsif ($cache->{disabled_temporarily} || $cache->{disabled_permanently}) {
				# disabled diagnostic is available, but it's too long to print here
				push(@cstatus, "WriteCache:DISABLED");
				$this->cache_fail;
			}

			push(@cstatus, "FlashCache") if $cache->{flash_cache};
			push(@cstatus, "ReadMem:$cache->{read_cache_memory}") if $cache->{read_cache_memory};
			push(@cstatus, "WriteMem:$cache->{write_cache_memory}") if $cache->{write_cache_memory};

			push(@bstatus, join(' ', @cstatus));
		}

		push(@status, "$dev($c->{board_name}): ". join(', ', @bstatus));
	}

	unless (@status) {
		return;
	}

	# denote this plugin as ran ok
	$this->ok;

	$this->message(join(', ', @status));

	# cciss_vol_status 1.10 with -V (or -s) checks individual disk health anyway
	my $v1_10 = $this->cciss_vol_status_version >= 1.10;

	# no_smartctl: allow skip from tests
	if (!$v1_10 && !$this->{no_smartctl}) {
		# check also individual disk health
		my @disks = $this->detect_disks(@devs);
		if (@disks) {
			# inherit smartctl command from our commands (testing)
			my %params = ();
			$params{commands}{smartctl} = $this->{commands}{smartctl} if $this->{commands}{smartctl};

			my $smartctl = App::Monitoring::Plugin::CheckRaid::Plugins::smartctl->new(%params);
			# do not perform check if smartctl is missing
			if ($smartctl->active) {
				$smartctl->check_devices(@disks);

				# XXX this is hack, as we have no proper subcommand check support
				$this->message($this->message . " " .$smartctl->message);
				if ($smartctl->status > 0) {
					$this->critical;
				}
			}
		}
	}
}

1;
