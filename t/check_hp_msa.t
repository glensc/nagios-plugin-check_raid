#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;

	if ($ENV{TRAVIS}) {
		use Test::More;
		plan skip_all => "Skipping test as can't open /dev in travis";
		exit 0;
	}
}

use strict;
use warnings;
use Test::More tests => 6;
use test;

my @tests = (
	{
		status => WARNING,
		tty_device => '/dev/ttyNOTTY',
		message => "Can't open /dev/ttyNOTTY",
	},
);

# test that plugin can be created
ok(hp_msa->new, "plugin created");

foreach my $test (@tests) {
	my $plugin = hp_msa->new(
		tty_device => $test->{tty_device},
		lockdir => '.',
		commands => {
		},
		options => {
			'hp_msa-serial' => $test->{tty_device},
		},
	);

	ok($plugin, "plugin created");

	$plugin->check;
	ok(1, "check ran");

	ok(defined($plugin->status), "status code set");
	is($plugin->status, $test->{status}, "status code matches");
	is($plugin->message, $test->{message}, "status message");
}
