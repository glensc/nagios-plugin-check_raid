#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use constant TESTS => 5;
use Test::More tests => TESTS * 5;
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
	{
		status => UNKNOWN,
		controller => 'heracles/controller.all.show.status',
		logical => 'heracles/logicaldrive.all.show',
		message => 'Smart Array P400: ',
	},
	{
		status => OK,
		controller => 'PR94/ctrl-status',
		logical => 'PR94/ld-show',
		message => 'Smart Array P410i: Array A(OK)[LUN1:OK]',
	},
	{
		status => CRITICAL,
		controller => 'issue98/controller.status',
		logical => 'issue98/logical.status',
		message => 'Smart Array P410: Array A(OK)[LUN1:OK], Array B(Failed)[LUN2:OK], Array C(OK)[LUN3:OK]',
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
	is($plugin->status, $test->{status}, "status code matches");
	is($plugin->message, $test->{message}, "status message");
}
