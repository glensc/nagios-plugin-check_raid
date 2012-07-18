#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use Test::More tests => 4;
use test;

my $plugin = hpacucli->new(
	program => '/bin/true',
	commands => {
		'controller status' => ['<', TESTDIR . '/data/hpacucli.controller.all.show.status'],
		'logicaldrive status' => ['<', TESTDIR . '/data/hpacucli.slot=0.logicaldrive.all.show'],
	},
);


ok($plugin, "plugin created");
ok($plugin->check, "check ran");
ok($plugin->status == OK, "status OK");
print "[".$plugin->message."]\n";
ok($plugin->message eq 'MY STORAGE: Array A(OK), Smart Array P400i: Array A(OK)', "expected message");
