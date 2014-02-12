#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use Test::More tests => 10;
use test;

my @tests = (
	{
		status => OK,
		controller => 'hpacucli.controller.all.show.status',
		logical => 'hpacucli.slot=0.logicaldrive.all.show',
		message => 'MY STORAGE: Array A(OK)[LUN1:OK], Smart Array P400i: Array A(OK)[LUN1:OK]',
	},
	{
		status => CRITICAL,
		controller => 'hpacucli.controller.all.show.status',
		logical => 'hpacucli.interim_recovery_mode.show',
		message => 'MY STORAGE: Array A(OK)[LUN1:Interim Recovery Mode], Smart Array P400i: Array A(OK)[LUN1:Interim Recovery Mode]',
	},
);

foreach my $test (@tests) {
	my $plugin = hpacucli->new(
		program => '/bin/true',
		commands => {
			'controller status' => ['<', TESTDIR . '/data/hpacucli/' . $test->{controller} ],
			'logicaldrive status' => ['<', TESTDIR . '/data/hpacucli/' .$test->{logical} ],
		},
	);

	ok($plugin, "plugin created");

	$plugin->check;
	ok(1, "check ran");

	ok(defined($plugin->status), "status code set");
	ok($plugin->status == $test->{status}, "status code (got:".$plugin->status." exp:".$test->{status}.")");

	print "[".$plugin->message."]\n";
	ok($plugin->message eq $test->{message}, "status message");
}
