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
		list => 'test1/list',
		config => 'test1/megarc.adapter-0',
		message => 'Logical Drive 0: OPTIMAL',
	},
);

# test that plugin can be created
ok(megarc->new, "plugin created");

foreach my $test (@tests) {
	my $plugin = megarc->new(
		commands => {
			'controller list' => ['<', TESTDIR . '/data/megarc/' .$test->{list} ],
			'controller config' => ['<', TESTDIR . '/data/megarc/' .$test->{config} ],
		},
	);
	ok($plugin, "plugin created: $test->{list}");

	$plugin->check;
	ok(1, "check ran");

	ok(defined($plugin->status), "status code set");
	is($plugin->status, $test->{status}, "status code matches");
	is($plugin->message, $test->{message}, "status message");
}
