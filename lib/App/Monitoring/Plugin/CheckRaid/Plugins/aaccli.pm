package App::Monitoring::Plugin::CheckRaid::Plugins::aaccli;

# Adaptec ServeRAID

use base 'App::Monitoring::Plugin::CheckRaid::Plugin';
use strict;
use warnings;

sub program_names {
	shift->{name};
}

sub commands {
	{
		'container list' => ['=', '@CMD'],
	}
}

sub sudo {
	my ($this, $deep) = @_;

	# quick check when running check
	return 1 unless $deep;

	my $cmd = $this->{program};
	"CHECK_RAID ALL=(root) NOPASSWD: $cmd container list /full"
}

sub check {
	my $this = shift;

	# status messages pushed here
	my @status;

	my $write = "";
	$write .= "open aac0\n";
	$write .= "container list /full\n";
	$write .= "exit\n";
	my $read = $this->cmd('container list', \$write);

#File foo receiving all output.
#
#AAC0>
#COMMAND: container list /full=TRUE
#Executing: container list /full=TRUE
#Num          Total  Oth Stripe          Scsi   Partition                                       Creation
#Label Type   Size   Ctr Size   Usage   C:ID:L Offset:Size   State   RO Lk Task    Done%  Ent Date   Time
#----- ------ ------ --- ------ ------- ------ ------------- ------- -- -- ------- ------ --- ------ --------
# 0    Mirror 74.5GB            Open    0:02:0 64.0KB:74.5GB Normal                        0  051006 13:48:54
# /dev/sda             Auth             0:03:0 64.0KB:74.5GB Normal                        1  051006 13:48:54
#
#
#AAC0>
#COMMAND: logfile end
#Executing: logfile end
	while (<$read>) {
		if (my($dsk, $stat) = /(\d:\d\d?:\d+)\s+\S+:\S+\s+(\S+)/) {
			next unless $this->valid($dsk);
			$dsk =~ s#:#/#g;
			next unless $this->valid($dsk);

			push(@status, "$dsk:$stat");

			$this->critical if ($stat eq "Broken");
			$this->warning if ($stat eq "Rebuild");
			$this->warning if ($stat eq "Bld/Vfy");
			$this->critical if ($stat eq "Missing");
			if ($stat eq "Verify") {
				$this->resync;
			}
			$this->warning if ($stat eq "VfyRepl");
		}
	}
	close $read;

	return unless @status;

	$this->message(join(', ', @status));
}

1;
