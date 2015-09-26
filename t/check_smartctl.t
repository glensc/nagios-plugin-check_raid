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
		smartctl => 'smartctl.cciss.$disk',
		check_params => (
			['/dev/cciss/c0d0', '-dcciss', 0],
			['/dev/cciss/c0d0', '-dcciss', 7],
			['/dev/cciss/c0d0', '-dcciss', 8],
		),
		message => '/dev/cciss/c0d0#0=OK',
	},
);

# test that plugin can be created
ok(smartctl->new, "plugin created");

foreach my $test (@tests) {
	my $plugin = smartctl->new(
		commands => {
			'smartctl' => ['<', TESTDIR . '/data/' . $test->{smartctl} ],
		},
	);
	ok($plugin, "plugin created");

	$plugin->check($test->{check_params});
	ok(1, "check ran");

	ok(defined($plugin->status), "status code set");
	is($plugin->status, $test->{status}, "status code matches");
	is($plugin->message, $test->{message}, "status message");
}
