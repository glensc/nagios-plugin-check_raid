#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use constant TESTS => 4;
use Test::More tests => TESTS * 5;
use test;

my @tests = (
	{
		status => OK,
		info => '1/info',
		unitstatus => '1/info.c.unitstatus',
		drivestatus => '1/info.c.drivestatus',
		message => 'c0(9650SE-16ML): u0:OK, Drives(16): p0,p1,p10,p11,p12,p13,p14,p15,p2,p3,p4,p5,p6,p7,p8,p9=OK',
	},
	{
		status => RESYNC,
		info => '2/info',
		unitstatus => '2/info.c0.unitstatus',
		drivestatus => '2/info.c0.drivestatus',
		message => 'c0(9750-4i): u0:VERIFYING 16%, Drives(4): p0,p1,p2,p3=OK',
	},
	{
		status => CRITICAL,
		info => 'lumpy/info',
		unitstatus => 'lumpy/unitstatus',
		drivestatus => 'lumpy/drivestatus',
		message => 'c0(9650SE-2LP): u0:REBUILDING 98%, Drives(2): p0=DEGRADED p1=OK',
	},
	{
		status => OK,
		info => 'ichy/info',
		unitstatus => 'ichy/info.c0.unitstatus',
		drivestatus => 'ichy/info.c0.drivestatus',
		message => 'c0(9650SE-12ML): u0:OK, Drives(6): p0,p1,p2,p3,p4,p5=OK',
	},
);

foreach my $test (@tests) {
	my $plugin = tw_cli->new(
		commands => {
			'info' => ['<', TESTDIR . '/data/tw_cli/' .$test->{info} ],
			'unitstatus' => ['<', TESTDIR . '/data/tw_cli/' .$test->{unitstatus} ],
			'drivestatus' => ['<', TESTDIR . '/data/tw_cli/' .$test->{drivestatus} ],
		},
	);
	ok($plugin, "plugin created");

	$plugin->check;
	ok(1, "check ran");

	ok(defined($plugin->status), "status code set");
	is($plugin->status, $test->{status}, "status code matches");
	is($plugin->message, $test->{message}, "status message");
}
