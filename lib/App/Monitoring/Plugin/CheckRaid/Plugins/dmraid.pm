package App::Monitoring::Plugin::CheckRaid::Plugins::dmraid;

use base 'App::Monitoring::Plugin::CheckRaid::Plugin';
use strict;
use warnings;

sub program_names {
	shift->{name};
}

sub commands {
	{
		'dmraid' => ['-|', '@CMD', '-r'],
	}
}

sub active {
	my ($this) = @_;

	# allow --plugin-option=dmraid-enabled to force this plugin to be enabled
	return 1 if exists $this->{options}{'dmraid-enabled'};

	# return if parent said NO
	my $res = $this->SUPER::active(@_);
	return $res unless $res;

	# check if dmraid is empty
	return keys %{$this->parse} > 0;
}

sub sudo {
	my ($this, $deep) = @_;
	# quick check when running check
	return 1 unless $deep;

	my $cmd = $this->{program};
	"CHECK_RAID ALL=(root) NOPASSWD: $cmd -r";
}

# parse arrays, return data indexed by array name
sub parse {
	my $this = shift;

	my (%arrays);
	my $fh = $this->cmd('dmraid');
	while (<$fh>) {
		chomp;
		next unless (my($device, $format, $name, $type, $status, $sectors) = m{^
			# /dev/sda: jmicron, "jmicron_JRAID", mirror, ok, 781385728 sectors, data@ 0
			(/dev/\S+):\s # device
			(\S+),\s # format
			"([^"]+)",\s # name
			(mirror|stripe[d]?),\s # type
			(\w+),\s # status
			(\d+)\ssectors,.* # sectors
		$}x);
		next unless $this->valid($device);

		# trim trailing spaces from name
		$name =~ s/\s+$//;

		my $member = {
			'device' => $device,
			'format' => $format,
			'type' => $type,
			'status' => $status,
			'size' => $sectors,
		};

		push(@{$arrays{$name}}, $member);
	}
	close $fh;

	return \%arrays;
}


# plugin check
# can store its exit code in $this->status
# can output its message in $this->message
sub check {
	my $this = shift;
	my (@status);

	## Check Array and Drive Status
	my $arrays = $this->parse;
	while (my($name, $array) = each(%$arrays)) {
		my @s;
		foreach my $dev (@$array) {
			if ($dev->{status} =~ m/sync|rebuild/i) {
				$this->warning;
			} elsif ($dev->{status} !~ m/ok/i) {
				$this->critical;
			}
			my $size = $this->format_bytes($dev->{size});
			push(@s, "$dev->{device}($dev->{type}, $size): $dev->{status}");
		}
		push(@status, "$name: " . join(', ', @s));
	}

	return unless @status;

	# denote that this plugin as ran ok, not died unexpectedly
	$this->ok->message(join(' ', @status));
}

1;
