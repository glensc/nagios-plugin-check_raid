package App::Monitoring::Plugin::CheckRaid::Plugins::afacli;

# Adaptec AACRAID

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

sub check {
	my $this = shift;

	# status messages pushed here
	my @status;

	my $write = "";
	$write .= "open afa0\n";
	$write .= "container list /full\n";
	$write .= "exit\n";

	my $read = $this->cmd('container list', \$write);
	while (<$read>) {
		# 0    Mirror  465GB            Valid   0:00:0 64.0KB: 465GB Normal                        0  032511 17:55:06
		# /dev/sda             root             0:01:0 64.0KB: 465GB Normal                        1  032511 17:55:06
		if (my($dsk, $stat) = /(\d:\d\d?:\d+)\s+\S+:\s?\S+\s+(\S+)/) {
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
	$read->close;

	return unless @status;

	$this->ok->message(join(', ', @status));
}

1;
