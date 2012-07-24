#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use Test::More tests => 5;
use test;

my $plugin = areca->new(
	commands => {
		'rsf info' => ['<', TESTDIR . '/data/cli64.rsf.info-1'],
		'disk info' => ['<', TESTDIR . '/data/cli64.disk.info-1'],
	},
);

ok($plugin, "plugin created");
$plugin->check;
ok(1, "check ran");
ok(defined($plugin->status), "status code set");
ok($plugin->status == OK, "status OK");
print "[".$plugin->message."]\n";
ok($plugin->message eq 'Array#1(Raid Set # 000): Normal', "expected message");
