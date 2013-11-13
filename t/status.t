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
ok($plugin->status(OK) == OK, 'set ok');
ok($plugin->status(WARNING) == WARNING, 'set warning');
ok($plugin->status(CRITICAL) == CRITICAL, 'set critical');
ok($plugin->status(UNKNOWN) == UNKNOWN, 'set unknown');

ok($plugin->status(CRITICAL) == UNKNOWN, 'set critical from unknown');
ok($plugin->status(WARNING) == UNKNOWN, 'set warning from unknown');
ok($plugin->status(OK) == UNKNOWN, 'set ok from unknown');

# reset to undef
$plugin->{status} = undef;
# set critical and then to ok, should not reset to ok
ok($plugin->status(CRITICAL) == CRITICAL, 'set critical');
ok($plugin->status(OK) == CRITICAL, 'set ok');

# reset to undef
$plugin->{status} = undef;
# set warning and then to ok, should not reset to ok
ok($plugin->status(WARNING) == WARNING, 'set warning');
ok($plugin->status(OK) == WARNING, 'set ok');

# check set status via sub calls
$plugin->{status} = undef;
ok($plugin->ok->status == OK, 'set ok');
ok($plugin->warning->status == WARNING, 'set warning');
ok($plugin->critical->status == CRITICAL, 'set critical');
ok($plugin->unknown->status == UNKNOWN, 'set unknown');

# the same, but with -W option emulated
plugin->set_critical_as_warning;

$plugin->{status} = undef;
ok($plugin->ok->status == OK, 'set ok');
ok($plugin->warning->status == WARNING, 'set warning');
ok($plugin->critical->status == WARNING, 'set warning');
ok($plugin->unknown->status == UNKNOWN, 'set unknown');
