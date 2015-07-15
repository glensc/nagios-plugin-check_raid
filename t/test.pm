use strict;
use warnings;
use Data::Dumper;
require Exporter;

use constant TESTDIR => ($0 =~ m{(.+)/[^/]+$});

(our $srcdir = $0) =~ s,/[^/]+$,/,;
require $srcdir . '/../check_raid.pl';

use constant OK => 0;
use constant WARNING => 1;
use constant CRITICAL => 2;
use constant UNKNOWN => 3;
# default is WARNING
use constant RESYNC => WARNING;

our @EXPORT = qw(OK WARNING CRITICAL UNKNOWN TESTDIR);

sub read_dump {
	my ($file) = @_;
	our $VAR1;

	do $file;

	return $VAR1;
}

sub store_dump {
	my ($file, $c) = @_;

	open my $fh, '>', $file or die $!;
	{
		local $Data::Dumper::Sortkeys = 1;
		print $fh Dumper $c;
	}
	close $fh or die $!;
}

1;
