#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use Test::More tests => 20;
use test;

my $plugin = plugin->new();

ok(!defined($plugin->status), 'default status undef');
is($plugin->status(OK), OK, 'set ok');
is($plugin->status(WARNING), WARNING, 'set warning');
is($plugin->status(CRITICAL), CRITICAL, 'set critical');
is($plugin->status(UNKNOWN), UNKNOWN, 'set unknown');

is($plugin->status(CRITICAL), UNKNOWN, 'set critical from unknown');
is($plugin->status(WARNING), UNKNOWN, 'set warning from unknown');
is($plugin->status(OK), UNKNOWN, 'set ok from unknown');

# reset to undef
$plugin->{status} = undef;
# set critical and then to ok, should not reset to ok
is($plugin->status(CRITICAL), CRITICAL, 'set critical');
is($plugin->status(OK), CRITICAL, 'set ok');

# reset to undef
$plugin->{status} = undef;
# set warning and then to ok, should not reset to ok
is($plugin->status(WARNING), WARNING, 'set warning');
is($plugin->status(OK), WARNING, 'set ok');

# check set status via sub calls
$plugin->{status} = undef;
is($plugin->ok->status, OK, 'set ok');
is($plugin->warning->status, WARNING, 'set warning');
is($plugin->critical->status, CRITICAL, 'set critical');
is($plugin->unknown->status, UNKNOWN, 'set unknown');

# the same, but with -W option emulated
$plugin->set_critical_as_warning;

$plugin->{status} = undef;
is($plugin->ok->status, OK, 'set ok');
is($plugin->warning->status, WARNING, 'set warning');
is($plugin->critical->status, WARNING, 'set warning');
is($plugin->unknown->status, UNKNOWN, 'set unknown');
