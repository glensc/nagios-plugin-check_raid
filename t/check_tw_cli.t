#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use Test::More tests => 4;
use test;

my $plugin = tw_cli->new(
	commands => {
		'info' => ['<', TESTDIR . '/data/tw_cli.info'],
		'unitstatus' => ['<', TESTDIR . '/data/tw_cli.c.unitstatus'],
		'drivestatus' => ['<', TESTDIR . '/data/tw_cli.info.c.drivestatus'],
	},
);

ok($plugin, "plugin created");
ok($plugin->check, "check ran");
ok($plugin->status == OK, "status code");
print "[".$plugin->message."]\n";
ok($plugin->message eq 'c0(9650SE-16ML): u0:OK, (disks: p0:OK p1:OK p2:OK p3:OK p4:OK p5:OK p6:OK p7:OK p8:OK p9:OK p10:OK p11:OK p12:OK p13:OK p14:OK p15:OK)', "status message");
