#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use Test::More tests => 8;
use test;

if (1) {
my $plugin = gdth->new(
	commands => {
		'proc' => ['<', TESTDIR . '/data/gdth'],
		'proc entry' => ['<', TESTDIR . '/data/gdth/$controller'],
	},
);

ok($plugin, "plugin created");
ok($plugin->check, "check ran");
ok($plugin->status == OK, "status OK");
print "[".$plugin->message."]\n";
ok($plugin->message eq 'Controller 0: Array 0(RAID-5) ready, Logical Drives: 0,1,2,3: ok');
}


if (1) {
my $plugin = gdth->new(
	commands => {
		'proc' => ['<', TESTDIR . '/data/gdth-fail'],
		'proc entry' => ['<', TESTDIR . '/data/gdth-fail/$controller'],
	},
);

ok($plugin, "plugin created");
ok($plugin->check, "check ran");
ok($plugin->status == CRITICAL, "status CRITICAL");
print "[".$plugin->message."]\n";
ok($plugin->message eq 'Controller 0: Array 0(RAID-5) fail, Logical Drives: 0,1,2,3,4,5: ok');
}
