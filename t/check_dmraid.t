#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use Test::More tests => 5;
use test;

my $plugin = dmraid->new(
	commands => {
		'read' => ['<', TESTDIR . '/data/dmraid/pr35'],
	},
);

ok($plugin, "plugin created");
$plugin->check;
ok(1, "check ran");
ok(defined($plugin->status), "status code set");
ok($plugin->status == OK, "status OK");
print "[".$plugin->message."]\n";
ok($plugin->message eq 'jmicron_JRAID: /dev/sda(mirror, 745.19 MiB): ok, /dev/sdb(mirror, 745.19 MiB): ok')
