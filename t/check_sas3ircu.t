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
		list => 'test1/LIST.log',
		cstatus => 'test1/0-STATUS.log',
		cdisplay => 'test1/sas3ircu-display.out',
		message => 'ctrl #0: 1 Vols: Optimal: 4 Drives: Optimal (OPT)::',
	},
);

# test that plugin can be created
ok(sas3ircu->new, "plugin created");

foreach my $test (@tests) {
	my $plugin = sas3ircu->new(
		program => '/bin/true',
		commands => {
			'controller list' => ['<', TESTDIR . '/data/sas3ircu/' . $test->{list} ],
			'controller status' => ['<', TESTDIR . '/data/sas3ircu/' . $test->{cstatus} ],
			'device status' => ['<', TESTDIR . '/data/sas3ircu/' . $test->{cdisplay} ],
		},
	);
	ok($plugin, "plugin created: $test->{list}");

	$plugin->check;
	ok(1, "check ran");

	ok(defined($plugin->status), "status code set");
	is($plugin->status, $test->{status}, "status code matches");
	is($plugin->message, $test->{message}, "status message");
}
