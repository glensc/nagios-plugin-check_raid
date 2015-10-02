package lsscsi;
use parent -norequire, 'plugin';

push(@utils::plugins, __PACKAGE__);

sub program_names {
	__PACKAGE__;
}

sub commands {
	{
		'lsscsi list' => ['-|', '@CMD', '-g'],
	}
}

# lists contoller devices (type=storage)
# this will fail (return empty list) if sg module is not present
# return /dev/sgX nodes
sub list_sg {
	my $this = shift;

	my @scan = $this->scan;

	my @devs = map { $_->{sgnode} } grep { $_->{type} eq 'storage' && $_->{sgnode} ne '-' } @scan;
	return wantarray ? @devs : \@devs;
}

# list disk nodes one for each controller
# return /dev/sdX nodes
sub list_dd {
	my $this = shift;

	my @scan = $this->scan;
	my @devs = map { $_->{devnode} } grep { $_->{type} eq 'disk' && $_->{devnode} ne '-' && $_->{sgnode} } @scan;
	return wantarray ? @devs : \@devs;
}

# scan lsscsi output
sub scan {
	my $this = shift;

	# cache inside single run
	return wantarray ? @{$this->{sdevs}} : $this->{sdevs} if $this->{sdevs};

	# Scan such output:
	# [0:0:0:0]    disk    HP       LOGICAL VOLUME   3.00  /dev/sda   /dev/sg0
	# [0:3:0:0]    storage HP       P410i            3.00  -          /dev/sg1
	# or without sg driver:
	# [0:0:0:0]    disk    HP       LOGICAL VOLUME   3.00  /dev/sda   -
	# [0:3:0:0]    storage HP       P410i            3.00  -          -

	my $fh = $this->cmd('lsscsi list');
	my @sdevs;
	while (<$fh>) {
		chop;
		if (my($hctl, $type, $vendor, $model, $rev, $devnode, $sgnode) = m{^
			\[([\d:]+)\] # SCSI Controller, SCSI bus, SCSI target, and SCSI LUN
			\s+(\S+) # type
			\s+(\S+) # vendor
			\s+(.*?) # model, match everything as it may contain spaces
			\s+(\S+) # revision
			\s+((?:/dev/\S+|-)) # /dev node
			\s+((?:/dev/\S+|-)) # /dev/sg node
		}x) {
			push(@sdevs, {
				'hctl' => $hctl,
				'type' => $type,
				'vendor' => $vendor,
				'model' => $model,
				'rev' => $rev,
				'devnode' => $devnode,
				'sgnode' => $sgnode,
			});
		}
	}
	close $fh;

	$this->{sdevs} = \@sdevs;
	return wantarray ? @sdevs : \@sdevs;
}

1;
