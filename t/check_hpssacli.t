#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use constant TESTS => 3;
use Test::More tests => TESTS * 5;
use test;

my @tests = (
	{
		status => OK,
		controller => 'PR94/ctrl-status',
		logical => 'PR94/ld-show',
		message => 'Smart Array P410i: Array A(OK)[LUN1:OK]',
	},
);

foreach my $test (@tests) {
	my $plugin = hpssacli->new(
		program => '/bin/true',
		commands => {
			'controller status' => ['<', TESTDIR . '/data/hpssacli/' . $test->{controller} ],
			'logicaldrive status' => ['<', TESTDIR . '/data/hpssacli/' .$test->{logical} ],
		},
	);

	ok($plugin, "plugin created");

	$plugin->check;
	ok(1, "check ran");

	ok(defined($plugin->status), "status code set");
	is($plugin->status, $test->{status}, "status code matches");
	is($plugin->message, $test->{message}, "status message");
}
