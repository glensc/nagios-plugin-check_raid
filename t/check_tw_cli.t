#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use constant TESTS => 7;
use Test::More tests => 1 + TESTS * 6;
use test;

my @tests = (
	{
		status => OK,
		info => '1/info',
		unitstatus => '1/info.c.unitstatus',
		drivestatus => '1/info.c.drivestatus',
		message => 'c0(9650SE-16ML): u0(RAID-6): OK, Cache:ON, Drives(16): p0,p1,p10,p11,p13,p14,p15,p2,p3,p4,p5,p6,p7,p8,p9=OK p12=SPARE, BBU: OK',
		c => '1',
	},
	{
		status => OK,
		info => '2/info',
		unitstatus => '2/info.c0.unitstatus',
		drivestatus => '2/info.c0.drivestatus',
		message => 'c0(9750-4i): u0(RAID-5): VERIFYING 16%, Cache:RiW, Drives(4): p0,p1,p2,p3=OK, BBU: OK',
		c => '2',
	},
	{
		status => CRITICAL,
		info => 'lumpy/info',
		unitstatus => 'lumpy/unitstatus',
		drivestatus => 'lumpy/drivestatus',
		message => 'c0(9650SE-2LP): u0(RAID-1): REBUILDING 98%, Cache:OFF, Drives(2): p0=DEGRADED p1=OK',
		c => 'lumpy',
	},
	{
		status => OK,
		info => 'ichy/info',
		unitstatus => 'ichy/info.c0.unitstatus',
		drivestatus => 'ichy/info.c0.drivestatus',
		message => 'c0(9650SE-12ML): u0(RAID-5): OK, Cache:ON, Drives(6): p0,p1,p2,p3,p4,p5=OK, BBU: OK',
		c => 'ichy',
	},
	{
		status => OK,
		info => 'black/info',
		unitstatus => 'black/unitstatus',
		drivestatus => 'black/drivestatus',
		message => 'c0(8006-2LP): u0(RAID-1): OK, Cache:W, Drives(2): p0,p1=OK',
		c => 'black',
	},
	{
		status => OK,
		info => 'rover/info',
		unitstatus => 'rover/unitstatus',
		drivestatus => 'rover/drivestatus',
		message => 'c0(9500S-8): u0(RAID-5): OK, Cache:OFF, Drives(6): p0,p1,p2,p3,p4,p5=OK',
		c => 'rover',
	},
	{
		status => OK,
		info => 'bootc/info',
		unitstatus => 'bootc/unitstatus',
		drivestatus => 'bootc/drivestatus',
		message => 'c0(9750-4i): u0(RAID-6): VERIFYING 29%(A), Cache:RiW, c0(9750-4i): u1(RAID-6): VERIFYING 18%(A), Cache:RiW, c0(9750-4i): u2(SPARE): VERIFYING 14%, c0(9750-4i): u3(SPARE): VERIFYING 0%, Drives(18): p10,p11,p12,p13,p14,p15,p16,p17,p18,p19,p20,p21,p22,p23,p24,p8=OK p25,p9=VERIFYING',
		c => 'bootc',
	},
);

# test that plugin can be created
ok(tw_cli->new, "plugin created");

foreach my $test (@tests) {
	my $plugin = tw_cli->new(
		commands => {
			'info' => ['<', TESTDIR . '/data/tw_cli/' .$test->{info} ],
			'unitstatus' => ['<', TESTDIR . '/data/tw_cli/' .$test->{unitstatus} ],
			'drivestatus' => ['<', TESTDIR . '/data/tw_cli/' .$test->{drivestatus} ],
		},
	);
	ok($plugin, "plugin created");

	$plugin::bbu_monitoring = 1;

	$plugin->check;
	ok(1, "check ran");

	ok(defined($plugin->status), "status code set");
	is($plugin->status, $test->{status}, "status code matches");
	is($plugin->message, $test->{message}, "status message");

	my $c = $plugin->parse;
	my $df = TESTDIR . '/dump/tw_cli/' . $test->{c};
	if (!-f $df) {
		store_dump $df, $c;
		# trigger error so that we don't have feeling all is ok ;)
		ok(0, "Created dump for $df");
	}
	my $dump = read_dump($df);
	is_deeply($c, $dump, "controller structure");
}
