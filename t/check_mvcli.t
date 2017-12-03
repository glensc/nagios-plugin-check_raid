#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use constant TESTS => 2;
use Test::More tests => 1 + TESTS * 6;
use test;

my @tests = (
	{
		status => UNKNOWN,
		'mvcli blk' => 'issue-92/blk',
		'mvcli smart' => 'issue-92/smart-2',
		message => '',
		c => 'issue-92-1',
	},
	{
		status => UNKNOWN,
		'mvcli blk' => 'mvcli-92/mvcli.info.blk',
		'mvcli smart' => 'mvcli-92/mvcli.smart.p0',
		message => '',
		c => 'issue-92-2',
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

	my $c = $plugin->parse;
	my $df = TESTDIR . '/dump/mvcli/' . $test->{c};
	if (!-f $df) {
		store_dump $df, $c;
		# trigger error so that we don't have feeling all is ok ;)
		ok(0, "Created dump for $df");
	}
	my $dump = read_dump($df);
	is_deeply($c, $dump, "controller structure");
}
