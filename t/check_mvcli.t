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
		status => UNKNOWN,
		'mvcli blk' => 'issue-92/blk',
		'mvcli smart' => 'issue-92/smart-2',
		message => '',
	},
);

foreach my $test (@tests) {
	my $plugin = mvcli->new(
		commands => {
			'mvcli blk' => ['<', TESTDIR . '/data/mvcli/' .$test->{'mvcli blk'} ],
			'mvcli smart' => ['<', TESTDIR . '/data/mvcli/' .$test->{'mvcli smart'} ],
		},
	);
	ok($plugin, "plugin created");

	$plugin->check;
	ok(1, "check ran");

	ok(defined($plugin->status), "status code set");
	is($plugin->status, $test->{status}, "status code matches");
	is($plugin->message, $test->{message}, "status message");
}
