#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use constant TESTS => 1;
use Test::More tests => 1 + TESTS * 5;
use test;

my @tests = (
	{
		dmsetup => 'pr-134/dmsetup',
		status => OK,
		message => 'vg1-cache::idle, vg1-zoom::idle',
	},
);

# test that plugin can be created
ok(lvm->new, "plugin created");

foreach my $test (@tests) {
	my $plugin = lvm->new(
		commands => {
			'dmsetup' => ['<', TESTDIR . '/data/lvm/' .$test->{dmsetup} ],
		},
	);
	ok($plugin, "plugin created");

	$plugin->check;
	ok(1, "check ran");

	ok(defined($plugin->status), "status code set");
	is($plugin->status, $test->{status}, "status code matches");
	is($plugin->message, $test->{message}, "status message");
}
