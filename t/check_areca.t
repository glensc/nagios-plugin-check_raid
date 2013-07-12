#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use Test::More tests => 10;
use test;

if (1) {
my $plugin = areca->new(
	commands => {
		'rsf info' => ['<', TESTDIR . '/data/areca/cli64.rsf.info-1'],
		'disk info' => ['<', TESTDIR . '/data/areca/cli64.disk.info-1'],
	},
);

ok($plugin, "plugin created");
$plugin->check;
ok(1, "check ran");
ok(defined($plugin->status), "status code set");
ok($plugin->status == OK, "status OK");
print "[".$plugin->message."]\n";
ok($plugin->message eq 'Array#1(Raid Set # 000): Normal, Drive Assignment: 9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,31,32=Array#1 30=HotSpare');
}

if (1) {
my $plugin = areca->new(
	commands => {
		'rsf info' => ['<', TESTDIR . '/data/areca/cli64.rsf.info-16'],
		'disk info' => ['<', TESTDIR . '/data/areca/cli64.disk.info-16'],
	},
);

ok($plugin, "plugin created");
$plugin->check;
ok(1, "check ran");
ok(defined($plugin->status), "status code set");
ok($plugin->status == CRITICAL, "status CRITICAL");
print "[".$plugin->message."]\n";
ok($plugin->message eq 'Array#1(data): Rebuilding, Drive Assignment: 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15=Array#1 16=Failed');
}
