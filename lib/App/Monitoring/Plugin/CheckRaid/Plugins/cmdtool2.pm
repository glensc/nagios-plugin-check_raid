package App::Monitoring::Plugin::CheckRaid::Plugins::cmdtool2;

use base 'App::Monitoring::Plugin::CheckRaid::Plugin';
use strict;
use warnings;

sub program_names {
	'CmdTool2';
}

sub commands {
	{
		'adapter list' => ['-|', '@CMD', , '-AdpAllInfo', '-aALL', '-nolog'],
		'adapter config' => ['-|', '@CMD', '-CfgDsply', '-a$adapter', '-nolog'],
	}
}

sub sudo {
	my ($this, $deep) = @_;
	# quick check when running check
	return 1 unless $deep;

	my $cmd = $this->{program};
	(
		"CHECK_RAID ALL=(root) NOPASSWD: $cmd -AdpAllInfo -aALL -nolog",
		"CHECK_RAID ALL=(root) NOPASSWD: $cmd -CfgDsply -a* -nolog",
	);
}

sub check {
	my $this = shift;

	# status messages pushed here
	my @status;

	# get adapters
	my $fh = $this->cmd('adapter list');
	my @c;
	while (<$fh>) {
		if (my($c) = /^Adapter #(\d+)/) {
			push(@c, $c);
		}
	}
	close $fh;

	unless (@c) {
		$this->warning;
		$this->message("No LSI adapters were found on this machine");
		return;
	}

	foreach my $c (@c) {
		my $fh = $this->cmd('adapter config', { '$adapter' => $c });
		my ($d);
		while (<$fh>) {
			# DISK GROUPS: 0
			if (my($s) = /^DISK GROUPS: (\d+)/) {
				$d = int($s);
				next;
			}

			# State: Optimal
			if (my($s) = /^State: (\S+)$/) {
				if ($s ne 'Optimal') {
					$this->critical;
				}
				push(@status, "Logical Drive $c,$d: $s");
			}
		}
	}

	return unless @status;

	# denote this plugin as ran ok
	$this->ok;

	$this->message(join(', ', @status));
}

1;
