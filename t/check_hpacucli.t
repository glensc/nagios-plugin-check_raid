#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use Test::More tests => 10;
use test;

my $plugin = hpacucli->new(
	program => '/bin/true',
	commands => {
		'controller status' => ['<', TESTDIR . '/data/hpacucli.controller.all.show.status'],
		'logicaldrive status' => ['<', TESTDIR . '/data/hpacucli.slot=0.logicaldrive.all.show'],
	},
);


ok($plugin, "plugin created");
$plugin->check;
ok(1, "check ran");
ok(defined($plugin->status), "status code set");
ok($plugin->status == OK, "status OK");
print "[".$plugin->message."]\n";
ok($plugin->message eq 'MY STORAGE: Array A(OK)[LUN1:OK], Smart Array P400i: Array A(OK)[LUN1:OK]', "expected message");

$plugin = hpacucli->new(
	program => '/bin/true',
	commands => {
		'controller status' => ['<', TESTDIR . '/data/hpacucli.controller.all.show.status'],
		'logicaldrive status' => ['<', TESTDIR . '/data/hpacucli.interim_recovery_mode.show'],
	},
);

ok($plugin, "plugin created");
$plugin->check;
ok(1, "check ran");
ok(defined($plugin->status), "status code set");
ok($plugin->status == CRITICAL, "status CRITICAL");
print "[".$plugin->message."]\n";
ok($plugin->message eq 'MY STORAGE: Array A(OK)[LUN1:Interim Recovery Mode], Smart Array P400i: Array A(OK)[LUN1:Interim Recovery Mode]', "expected message");
