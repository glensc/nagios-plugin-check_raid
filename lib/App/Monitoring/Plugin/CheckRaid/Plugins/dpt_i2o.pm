package App::Monitoring::Plugin::CheckRaid::Plugins::dpt_i2o;

use base 'App::Monitoring::Plugin::CheckRaid::Plugin';
use strict;
use warnings;

sub commands {
	{
		'proc' => ['<', '/proc/scsi/dpt_i2o'],
		'proc entry' => ['<', '/proc/scsi/dpt_i2o/$controller'],
	}
}

sub active {
	my ($this) = @_;
	return -d $this->{commands}{proc}[1];
}

sub check {
	my $this = shift;
	# status messages pushed here
	my @status;

	my $fh = $this->cmd('proc');
	my @c = grep { !/^\./ } readdir($fh);
	$fh->close;

	# TODO: check for failed disks!
	for my $c (@c) {
		my $fh = $this->cmd('proc entry', { '$controller' => $c });

		while (<$fh>) {
			if (my ($c, $t, $l, $s) = m/TID=\d+,\s+\(Channel=(\d+),\s+Target=(\d+),\s+Lun=(\d+)\)\s+\((\S+)\)/) {
				if ($s ne "online") {
					$this->critical;
				}
				push(@status, "$c,$t,$l:$s");
			}
		}
		$fh->close;
	}

	return unless @status;

	# denote this plugin as ran ok
	$this->ok;

	$this->message(join(', ', @status));
}

1;
