#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use Test::More tests => 4;
use test;

my $plugin = dpt_i2o->new(
	commands => {
		'proc' => ['<', TESTDIR . '/data/dpt_i2o'],
		'proc entry' => ['<', TESTDIR . '/data/dpt_i2o/$controller'],
	},
);

ok($plugin, "plugin created");
ok($plugin->check, "check ran");
ok($plugin->status == OK, "status OK");
print "[".$plugin->message."]\n";
ok($plugin->message eq '0,0,0:online, 0,5,0:online, 0,6,0:online', "expected message");
