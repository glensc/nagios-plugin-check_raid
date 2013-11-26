use strict;
use warnings;
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

1;
