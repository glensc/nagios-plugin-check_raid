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
		read => 'pr35',
		message => 'jmicron_JRAID: /dev/sda(mirror, 745.19 MiB): ok, /dev/sdb(mirror, 745.19 MiB): ok',
	},
);

foreach my $test (@tests) {
	my $plugin = dmraid->new(
		commands => {
			'read' => ['<', TESTDIR . '/data/dmraid/' .$test->{read} ],
		},
	);

	ok($plugin, "plugin created");

	$plugin->check;
	ok(1, "check ran");

	ok(defined($plugin->status), "status code set");
	ok($plugin->status == $test->{status}, "status code (got:".$plugin->status." exp:".$test->{status}.")");

	print "[".$plugin->message."]\n";
	ok($plugin->message eq $test->{message}, "status message");
}
