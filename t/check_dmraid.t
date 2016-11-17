#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use constant ACTIVE_TESTS => 2;
use constant INACTIVE_TESTS => 1;
use Test::More tests => 1 + ACTIVE_TESTS * 3 + INACTIVE_TESTS * 3;
use test;

my @tests = (
	{
		active => 1,
		status => OK,
		dmraid => 'pr35',
		message => 'jmicron_JRAID: /dev/sda(mirror, 745.19 MiB): ok, /dev/sdb(mirror, 745.19 MiB): ok',
	},
	{
		active => 0,
		dmraid => 'pr60',
	},
	{
		active => 0,
		status => OK,
		dmraid => 'issue129/dmraid-r',
		message => '',
	},
);

# test that plugin can be created
ok(dmraid->new, "plugin created");

foreach my $test (@tests) {
	my $plugin = dmraid->new(
		commands => {
			'dmraid' => ['<', TESTDIR . '/data/dmraid/' .$test->{dmraid} ],
		},
		options => {
			'dmraid-enabled' => 1,
		},
	);

	ok($plugin, "plugin created");

	$plugin->check;
	ok(1, "check ran");

	next unless $test->{active};

	ok(defined($plugin->status), "status code set");
	is($plugin->status, $test->{status}, "status code matches");
	is($plugin->message, $test->{message}, "status message");
}
