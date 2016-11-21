#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use Test::More tests => 6;
use test;

my @tests = (
	{
		status => UNKNOWN,
		'mvcli blk' => 'issue-92/blk',
		'mvcli smart' => 'issue-92/smart-2',
		message => '',
	},
);

# test that plugin can be created
ok(mvcli->new, "plugin created");

foreach my $test (@tests) {
	my $plugin = mvcli->new(
		commands => {
			'mvcli blk' => ['<', TESTDIR . '/data/mvcli/' .$test->{'mvcli blk'} ],
			'mvcli smart' => ['<', TESTDIR . '/data/mvcli/' .$test->{'mvcli smart'} ],
		},
	);
	ok($plugin, "plugin created: $test->{'mvcli blk'}");

	$plugin->check;
	ok(1, "check ran");

	ok(defined($plugin->status), "status code set");
	is($plugin->status, $test->{status}, "status code matches");
	is($plugin->message, $test->{message}, "status message");
}
