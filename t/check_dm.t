#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use constant TESTS => 3;
use Test::More tests => 1 + TESTS * 6;
use test;

my @tests = (
	{
		dmsetup => 'pr-134/dmsetup',
		status => OK,
		message => 'vg1-cache:AA idle, vg1-zoom:AA idle',
	},
	{
		dmsetup => 'pr-134/raid',
		status => OK,
		message => 'vg-SWAP:AA idle, vg-root:AA idle, vg-testraid:AA idle',
	},
	{
		dmsetup => 'pr-134/mirror',
		status => OK,
		message => 'vg-testmirror:AA',
	},
);

# test that plugin can be created
ok(dm->new, "plugin created");

foreach my $test (@tests) {
	my $plugin = dm->new(
		commands => {
			'dmsetup' => ['<', TESTDIR . '/data/dm/' .$test->{dmsetup} ],
		},
	);
	ok($plugin, "plugin created");

	$plugin->check;
	ok(1, "check ran");

	ok(defined($plugin->status), "status code set");
	is($plugin->status, $test->{status}, "status code matches");
	is($plugin->message, $test->{message}, "status message");

	my $c = $plugin->parse;
	my $df = TESTDIR . '/dump/dm/' . $test->{dmsetup};
	if (!-f $df) {
		store_dump $df, $c;
		# trigger error so that we don't have feeling all is ok ;)
		ok(0, "Created dump for $df");
	}
	my $dump = read_dump($df);
	is_deeply($c, $dump, "parsed structure");
}
