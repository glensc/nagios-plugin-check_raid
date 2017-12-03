package App::Monitoring::Plugin::CheckRaid::Plugins::mvcli;

# Status: BROKEN: not finished

use base 'App::Monitoring::Plugin::CheckRaid::Plugin';
use strict;
use warnings;

sub program_names {
	shift->{name};
}

sub commands {
	{
		'mvcli blk' => ['-|', '@CMD', 'info', '-o', 'blk'],
		'mvcli vd' => ['-|', '@CMD', 'info', '-o', 'vd'],
		'mvcli smart' => ['-|', '@CMD', 'smart', '-p', '0'],
	}
}

sub sudo {
	my ($this, $deep) = @_;
	# quick check when running check
	return 1 unless $deep;

	my $cmd = $this->{program};
	"CHECK_RAID ALL=(root) NOPASSWD: $cmd"
}

sub parse_blk {
	my $this = shift;

	my (@blk, %blk);

	my $fh = $this->cmd('mvcli blk');
	while (<$fh>) {
		chomp;

		if (my ($blk_id) = /Block id:\s+(\d+)/) {
			# block id is first item, so push previous item to list
			if (%blk) {
				push(@blk, { %blk });
				%blk = ();
			}
			$blk{blk_id} = int($blk_id);
		} elsif (my($pd_id) = /PD id:\s+(\d+)/) {
			$blk{pd_id} = int($pd_id);
		} elsif (my($vd_id) = /VD id:\s+(\d+)/) {
			$blk{vd_id} = int($vd_id);
		} elsif (my($bstatus) = /Block status:\s+(.+)/) {
			$blk{block_status} = $bstatus;
		} elsif (my($size) = /Size:\s+(\d+) K/) {
			$blk{size} = int($size);
		} elsif (my($offset) = /Starting offset:\s+(\d+) K/) {
			$blk{offset} = int($offset);
		} else {
#			warn "[$_]\n";
		}
	}
	close $fh;

	if (%blk) {
		push(@blk, { %blk });
	}

	return wantarray ? @blk : \@blk;
}

sub parse_vd {
	my $this = shift;

	my (@vd, %vd);
	my ($name, $value);

	my $fh = $this->cmd('mvcli vd');
	while (<$fh>) {
		chomp;

		if (/^$/
				|| /----+/
				|| /SG driver version/
				|| /Virtual Disk Information/
			) {
			next;
		}

		unless (($name, $value) = /^(.+):\s+(.+)$/) {
			warn "UNPARSED: [$_]";
			next;
		}

		if ($name eq 'id') {
			# id is first item, so push previous item to list
			if (%vd) {
				push(@vd, { %vd });
				%vd = ();
			}
		}

		$vd{$name} = $value;
	}
	close $fh;

	if (%vd) {
		push(@vd, { %vd });
	}

	return wantarray ? @vd : \@vd;
}

sub parse_smart {
	my ($this, $blk) = @_;

	# collect pd numbers
	my @pd = map { $_->{pd_id} } @$blk;

	my %smart;
	foreach my $pd (@pd) {
		my $fh = $this->cmd('mvcli smart', { '$pd' => $pd });
		my %attrs = ();
		while (<$fh>) {
			chomp;

			if (my($id, $name, $current, $worst, $treshold, $raw, $status) = /
				([\dA-F]{2})\s+ # id
				(.*?)\s+        # name
				(\d+)\s+        # current
				(\d+)\s+        # worst
				(\d+)\s+        # treshold
				([\dA-F]{12})   # raw
				(?:\s+(\w+))?   # status
			/x) {
				my %attr = ();
				$attr{id} = $id;
				$attr{name} = $name;
				$attr{current} = int($current);
				$attr{worst} = int($worst);
				$attr{treshold} = int($treshold);
				$attr{raw} = $raw;
				$attr{status} = $status || undef;
				$attrs{$id} = { %attr };
			} else {
#				warn "[$_]\n";
			}
		}

		$smart{$pd} = { %attrs };
	}

	return \%smart;
}

sub parse {
	my $this = shift;

	my $blk = $this->parse_blk;
	my $vd = $this->parse_vd;
	my $smart = $this->parse_smart($blk);

	return {
		blk => $blk,
		vd => $vd,
		smart => $smart,
	};
}

sub check {
	my $this = shift;

	my (@status);
	my @d = $this->parse;

	# not implemented yet
	$this->unknown;

	$this->message(join('; ', @status));
}

1;
