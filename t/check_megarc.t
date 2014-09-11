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
		status => OK,
		list => 'test1/list',
		config => 'test1/megarc.adapter-0',
		message => 'Logical Drive 0: OPTIMAL',
	},
);

foreach my $test (@tests) {
	my $plugin = megarc->new(
		commands => {
			'controller list' => ['<', TESTDIR . '/data/megarc/' .$test->{list} ],
			'controller config' => ['<', TESTDIR . '/data/megarc/' .$test->{config} ],
		},
	);
	ok($plugin, "plugin created");

	$plugin->check;
	ok(1, "check ran");

	ok(defined($plugin->status), "status code set");
	is($plugin->status, $test->{status}, "status code matches");
	is($plugin->message, $test->{message}, "status message");
}
