#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use Test::More tests => 1;
use test;

my @tests = (
);

# test that plugin can be created
ok(aaccli->new, "plugin created");

foreach my $test (@tests) {
	my $plugin = aaccli->new(
		commands => {
			'container list' => ['<', TESTDIR . '/data/aaccli/' .$test->{container} ],
		},
	);
	ok($plugin, "plugin created");

	$plugin->check;
	ok(1, "check ran");

	ok(defined($plugin->status), "status code set");
	is($plugin->status, $test->{status}, "status code matches");
	is($plugin->message, $test->{message}, "status message");
}
