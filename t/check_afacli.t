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
		container => 'container.list',
		message => '0/00/0:Normal, 0/01/0:Normal',
	},
);

foreach my $test (@tests) {
	my $plugin = afacli->new(
		commands => {
			'container list' => ['<', TESTDIR . '/data/afacli/' .$test->{container} ],
		},
	);
	ok($plugin, "plugin created");

	$plugin->check;
	ok(1, "check ran");

	ok(defined($plugin->status), "status code set");
	is($plugin->status, $test->{status}, "status code matches");
	is($plugin->message, $test->{message}, "status message");
}
