#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use Test::More tests => 4;
use test;

{
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
ok($plugin->message eq 'Logical Drive 0,0:ok, 0,1:ok, 0,2:ok, 0,3:ok', "expected message");
}

{
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
ok($plugin->message eq 'Logical Drive 0,0:ok, 0,1:ok, 0,2:ok, 0,3:ok, 0,4:ok, 0,5:ok', "expected message");
}
