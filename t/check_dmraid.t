#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use constant ACTIVE_TESTS => 1;
use constant INACTIVE_TESTS => 1;
use Test::More tests => ACTIVE_TESTS * 5 + INACTIVE_TESTS * 3;
use test;

my @tests = (
	{
		active => 1,
		status => OK,
		read => 'pr35',
		message => 'jmicron_JRAID: /dev/sda(mirror, 745.19 MiB): ok, /dev/sdb(mirror, 745.19 MiB): ok',
	},
	{
		active => 0,
		read => 'pr60',
	},
);

foreach my $test (@tests) {
	my $plugin = dmraid->new(
		commands => {
			'read' => ['<', TESTDIR . '/data/dmraid/' .$test->{read} ],
		},
	);

	ok($plugin, "plugin created");

	my $active = $plugin->active;
	ok($active == $test->{active}, "active matches");

	# can't check if plugin not active
	next unless $active;

	$plugin->check;
	ok(1, "check ran");

	ok(defined($plugin->status), "status code set");
	ok($plugin->status == $test->{status}, "status code (got:".$plugin->status." exp:".$test->{status}.")");

	print "[".$plugin->message."]\n";
	ok($plugin->message eq $test->{message}, "status message");
}
