#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use Test::More tests => 15;
use test;

if (1) {
	my $plugin = megacli->new(
		commands => {
			'pdlist' => ['<', TESTDIR . '/data/megacli/megacli.pdlist.1'],
			'ldinfo' => ['<', TESTDIR . '/data/megacli/megacli.ldinfo.1'],
		},
	);

	ok($plugin, "plugin created");
	$plugin->check;
	ok(1, "check ran");
	ok(defined($plugin->status), "status code set");
	ok($plugin->status == OK, "status code");
	print "[".$plugin->message."]\n";
	ok($plugin->message eq 'Volumes(2): OS:Optimal,DATA:Optimal; Devices(12): 14,16=Hotspare 04,05,06,07,08,09,10,11,12,13=Online');
}

if (1) {
	my $plugin = megacli->new(
		commands => {
			'pdlist' => ['<', TESTDIR . '/data/megacli/megacli.pdlist.2'],
			'ldinfo' => ['<', TESTDIR . '/data/megacli/megacli.ldinfo.2'],
		},
	);

	ok($plugin, "plugin created");
	$plugin->check;
	ok(1, "check ran");
	ok(defined($plugin->status), "status code set");
	ok($plugin->status == OK, "status code");
	print "[".$plugin->message."]\n";
	ok($plugin->message eq 'Volumes(1): DISK0.0:Optimal; Devices(11): 16=Hotspare 11,12,13,14,15,17=Online 18,19,20,21=Unconfigured(good)');
}

if (1) {
	my $plugin = megacli->new(
		commands => {
			'pdlist' => ['<', TESTDIR . '/data/megacli/issue41/pdlist'],
			'ldinfo' => ['<', TESTDIR . '/data/megacli/issue41/ldinfo'],
		},
	);

	ok($plugin, "plugin created");
	$plugin->check;
	ok(1, "check ran");
	ok(defined($plugin->status), "status code set");
	ok($plugin->status == OK, "status code");
	print "[".$plugin->message."]\n";
	ok($plugin->message eq 'Volumes(3): DISK0.0:Optimal,DISK1.1:Optimal,DISK2.2:Optimal; Devices(6): 11,10,09,08,12,13=Online');
}
