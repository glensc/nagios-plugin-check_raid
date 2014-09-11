#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use Test::More tests => 15;
use test;

my @tests = (
	{
		status => OK,
		info => '1/info',
		unitstatus => '1/info.c.unitstatus',
		drivestatus => '1/info.c.drivestatus',
		message => 'c0(9650SE-16ML): u0:OK, (disks: p0:OK p1:OK p2:OK p3:OK p4:OK p5:OK p6:OK p7:OK p8:OK p9:OK p10:OK p11:OK p12:OK p13:OK p14:OK p15:OK)',
	},
	{
		status => RESYNC,
		info => '2/info',
		unitstatus => '2/info.c0.unitstatus',
		drivestatus => '2/info.c0.drivestatus',
		message => 'c0(9750-4i): u0:VERIFYING 16%, (disks: p0:OK p1:OK p2:OK p3:OK)',
	},
	{
		status => CRITICAL,
		info => '3/lumpy-info',
		unitstatus => '3/lumpy-unitstatus',
		drivestatus => '3/lumpy-drivestatus',
		message => 'c0(9650SE-2LP): u0:REBUILDING 98%, (disks: p0:DEGRADED p1:OK)',
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
