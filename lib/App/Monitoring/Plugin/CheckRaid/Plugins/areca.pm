package areca;
## Areca SATA RAID Support
## requires cli64 or cli32 binaries
## For links to manuals and binaries, see this issue:
## https://github.com/glensc/nagios-plugin-check_raid/issues/10
use parent -norequire, 'plugin';

# register
push(@utils::plugins, __PACKAGE__);

sub program_names {
	qw(areca-cli areca_cli64 areca_cli32 cli64 cli32);
}

sub commands {
	{
		'rsf info' => ['-|', '@CMD', 'rsf', 'info'],
		'disk info' => ['-|', '@CMD', 'disk', 'info'],
	}
}

sub sudo {
	my ($this, $deep) = @_;
	# quick check when running check
	return 1 unless $deep;

	my $cmd = $this->{program};
	(
		"CHECK_RAID ALL=(root) NOPASSWD: $cmd rsf info",
		"CHECK_RAID ALL=(root) NOPASSWD: $cmd disk info",
	);
}

# plugin check
# can store its exit code in $this->status
# can output its message in $this->message
sub check {
	my $this = shift;

	## Check Array Status
	my (@status, %arrays);
	my $fh = $this->cmd('rsf info');
	while (<$fh>) {
=cut
 #  Name             Disks TotalCap  FreeCap MinDiskCap         State
 #  Name             Disks TotalCap  FreeCap DiskChannels       State
===============================================================================
 1  Raid Set # 000      23 34500.0GB    0.0GB   1500.0GB         Normal
 1  Raid Set # 00       15 15000.0GB    0.0GB 123G567C9AB48EF    Normal
 1  data                15 11250.0GB    0.0GB 123456789ABCDEF    Normal
 1  data                15 11250.0GB    0.0GB 123456789ABCDEF    Initializing
===============================================================================
=cut
		next unless (my($id, $n, $s) = m{^
			\s*(\d+)    # Id
			\s+(.+)     # Name
			\s+\d+      # Disks
			\s+\S+      # TotalCap
			\s+\S+      # FreeCap
			\s+\S+      # MinDiskCap/DiskChannels
			\s+(\S+)\s* # State
		$}x);

		# trim trailing spaces from name
		$n =~ s/\s+$//;

		if ($s =~ /[Rr]e[Bb]uild/) {
			$this->warning;
		} elsif ($s !~ /[Nn]ormal|[Rr]e[Bb]uild|Checking|Initializing/) {
			$this->critical;
		}

		push(@status, "Array#$id($n): $s");

		$arrays{$n} = [ $id, $s ];
	}
	close $fh;

	## Check Drive Status
	$fh = $this->cmd('disk info');
	my %drivestatus;
	while (<$fh>) {
		chomp;
=cut
  # Enc# Slot#   ModelName                        Capacity  Usage
===============================================================================
  1  01  Slot#1  N.A.                                0.0GB  N.A.
  8  01  Slot#8  N.A.                                0.0GB  N.A.
  9  02  SLOT 01 ST31500341AS                     1500.3GB  Raid Set # 000
 11  02  SLOT 03 ST31500341AS                     1500.3GB  Raid Set # 000

  # Ch# ModelName                       Capacity  Usage
===============================================================================
  1  1  ST31000340NS                    1000.2GB  Raid Set # 00
  6  6  ST31000340NS                    1000.2GB  Raid Set # 00
  3  3  WDC WD7500AYYS-01RCA0            750.2GB  data
  4  4  WDC WD7500AYYS-01RCA0            750.2GB  data
 16 16  WDC WD7500AYYS-01RCA0            750.2GB  HotSpare[Global]
=cut
		next unless my($id, $model, $usage) = m{^
			\s*(\d+)      # Id
			\s+\d+        # Channel/Enclosure (not reliable, tests 1,2,12 differ)
			\s+(.+)       # ModelName
			\s+\d+.\d\S+  # Capacity
			\s+(.+)       # Usage (Raid Name)
		}x;

		# trim trailing spaces from name
		$usage =~ s/\s+$//;

		# Asssume model N.A. means the slot not in use
		# we could also check for Capacity being zero, but this seems more
		# reliable.
		next if $usage eq 'N.A.';

		# use array id in output: shorter
		my $array_id = defined($arrays{$usage}) ? ($arrays{$usage})->[0] : undef;
		my $array_name = defined $array_id ? "Array#$array_id" : $usage;

		# assume critical if Usage is not one of:
		# - existing Array name
		# - HotSpare
		# - Rebuild
		if (defined($arrays{$usage})) {
			# Disk in Array named $usage
			push(@{$drivestatus{$array_name}}, $id);
		} elsif ($usage =~ /[Rr]e[Bb]uild/) {
			# rebuild marks warning
			push(@{$drivestatus{$array_name}}, $id);
			$this->warning;
		} elsif ($usage =~ /HotSpare/) {
			# hotspare is OK
			push(@{$drivestatus{$array_name}}, $id);
		} elsif ($usage =~ /Pass Through/) {
			# Pass Through is OK
			push(@{$drivestatus{$array_name}}, $id);
		} else {
			push(@{$drivestatus{$array_name}}, $id);
			$this->critical;
		}
	}
	close $fh;

	push(@status, "Drive Assignment: ".$this->join_status(\%drivestatus)) if %drivestatus;

	$this->ok->message(join(', ', @status));
}

1;
