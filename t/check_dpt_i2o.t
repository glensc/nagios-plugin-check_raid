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
		status => OK,
		proc => 'dpt_i2o',
		entry => 'dpt_i2o/$controller',
		message => '0,0,0:online, 0,5,0:online, 0,6,0:online',
	},
);

# test that plugin can be created
ok(dpt_i2o->new, "plugin created");

foreach my $test (@tests) {
	my $plugin = dpt_i2o->new(
		commands => {
			'proc' => ['<', TESTDIR . '/data/' .$test->{proc} ],
			'proc entry' => ['<', TESTDIR . '/data/' .$test->{entry} ],
		},
	);
	ok($plugin, "plugin created");

	$plugin->check;
	ok(1, "check ran");

	ok(defined($plugin->status), "status code set");
	is($plugin->status, $test->{status}, "status code matches");
	is($plugin->message, $test->{message}, "status message");
}
