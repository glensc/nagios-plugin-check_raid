#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use Test::More tests => 5;
use test;

my @tests = (
	{
		status => CRITICAL,
		list => 'test1',
		message => '1:Okay, 2:Critical'
	},
);

foreach my $test (@tests) {
	my $plugin = ips->new(
		commands => {
			'list logical drive' => ['<', TESTDIR . '/data/ips/' . $test->{list} ],
		},
	);
	ok($plugin, "plugin created");

	$plugin->check;
	ok(1, "check ran");

	ok(defined($plugin->status), "status code set");
	is($plugin->status, $test->{status}, "status code matches");
	is($plugin->message, $test->{message}, "status message");
}
