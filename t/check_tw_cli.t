#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use constant TESTS => 15;
use Test::More tests => 1 + TESTS * 6;
use test;

my @tests = (
	{
		status => OK,
		info => '1/info',
		show => '1/show',
		unitstatus => '1/info.c.unitstatus',
		drivestatus => '1/info.c.drivestatus',
		bbustatus => 'empty',
		message => 'c0(9650SE-16ML): u0(RAID-6): OK, Cache:ON, Drives(16): p0,p1,p10,p11,p13,p14,p15,p2,p3,p4,p5,p6,p7,p8,p9=OK p12=SPARE, BBU: OK',
		c => '1',
	},
	{
		status => OK,
		info => '2/info',
		show => '2/show',
		unitstatus => '2/info.c0.unitstatus',
		drivestatus => '2/info.c0.drivestatus',
		bbustatus => 'empty',
		message => 'c0(9750-4i): u0(RAID-5): VERIFYING 16%, Cache:RiW, Drives(4): p0,p1,p2,p3=OK, BBU: OK',
		c => '2',
	},
	{
		status => CRITICAL,
		info => 'lumpy/info',
		show => 'lumpy/show',
		unitstatus => 'lumpy/unitstatus',
		drivestatus => 'lumpy/drivestatus',
		bbustatus => 'empty',
		message => 'c0(9650SE-2LP): u0(RAID-1): REBUILDING 98%, Cache:OFF, Drives(2): p0=DEGRADED p1=OK',
		c => 'lumpy',
	},
	{
		status => OK,
		info => 'ichy/info',
		show => 'ichy/show',
		unitstatus => 'ichy/info.c0.unitstatus',
		drivestatus => 'ichy/info.c0.drivestatus',
		bbustatus => 'empty',
		message => 'c0(9650SE-12ML): u0(RAID-5): OK, Cache:ON, Drives(6): p0,p1,p2,p3,p4,p5=OK, BBU: OK',
		c => 'ichy',
	},
	{
		status => OK,
		info => 'black/info',
		show => 'black/show',
		unitstatus => 'black/unitstatus',
		drivestatus => 'black/drivestatus',
		bbustatus => 'empty',
		message => 'c0(8006-2LP): u0(RAID-1): OK, Cache:W, Drives(2): p0,p1=OK',
		c => 'black',
	},
	{
		status => OK,
		info => 'rover/info',
		show => 'rover/show',
		unitstatus => 'rover/unitstatus',
		drivestatus => 'rover/drivestatus',
		bbustatus => 'empty',
		message => 'c0(9500S-8): u0(RAID-5): OK, Cache:OFF, Drives(6): p0,p1,p2,p3,p4,p5=OK',
		c => 'rover',
	},
	{
		status => OK,
		info => 'bootc/info',
		show => 'bootc/show',
		unitstatus => 'bootc/unitstatus',
		drivestatus => 'bootc/drivestatus',
		bbustatus => 'empty',
		message => 'c0(9750-4i): u0(RAID-6): VERIFYING 29%(A), Cache:RiW, c0(9750-4i): u1(RAID-6): VERIFYING 18%(A), Cache:RiW, c0(9750-4i): u2(SPARE): VERIFYING 14%, c0(9750-4i): u3(SPARE): VERIFYING 0%, Drives(18): p10,p11,p12,p13,p14,p15,p16,p17,p18,p19,p20,p21,p22,p23,p24,p8=OK p25,p9=VERIFYING',
		c => 'bootc',
	},
	{
		status => OK,
		info => 'bootc/info',
		show => 'bootc-enc/show',
		unitstatus => 'bootc/unitstatus',
		drivestatus => 'bootc/drivestatus',
		bbustatus => 'empty',
		enc_show_all => 'bootc-enc/c0.e0.show.all',
		message => 'c0(9750-4i): u0(RAID-6): VERIFYING 29%(A), Cache:RiW, c0(9750-4i): u1(RAID-6): VERIFYING 18%(A), Cache:RiW, c0(9750-4i): u2(SPARE): VERIFYING 14%, c0(9750-4i): u3(SPARE): VERIFYING 0%, Drives(18): p10,p11,p12,p13,p14,p15,p16,p17,p18,p19,p20,p21,p22,p23,p24,p8=OK p25,p9=VERIFYING, Enclosure: /c0/e0(fan0=OK(2670),fan1=OK(9500),fan2=OK(8540),fan3=OK(2830),fan4=OK(9120),fan5=OK(8330),temp0=OK(41C),temp1=OK(38C),temp2=OK(34C),temp3=OK(38C),temp4=OK(38C),temp5=OK(34C),pwrs0=OK(status=on,voltage=OK,current=OK),pwrs1=OK(status=on,voltage=OK,current=OK),slot0=OK,slot10=OK,slot2=OK,slot3=OK,slot4=OK,slot5=OK,slot6=OK,slot7=OK,slot8=OK,slot9=OK)',
		c => 'bootc-enc',
	},
	{
		status => OK,
		info => 'grubbs/info',
		show => 'grubbs/show',
		unitstatus => 'grubbs/info.c0.unitstatus',
		drivestatus => 'grubbs/info.c0.drivestatus',
		#bbustatus => 'grubbs/info.c0.bbustatus',
		#enc_show_all => 'grubbs/c0.eX.show.all',
		message => 'c0(9750-4i): u0(RAID-1): OK, Cache:RiW, c0(9750-4i): u1(RAID-10): OK, Cache:RiW, c0(9750-4i): u2(RAID-0): OK, Cache:RiW, Drives(14): p10,p11,p12,p13,p14,p15,p16,p17,p18,p19,p20,p21=OK p8,p9=SPARE, BBU: OK',
		c => 'grubbs-nobbu-noenc',
	},
	{
		status => OK,
		info => 'grubbs/info',
		show => 'grubbs/show',
		unitstatus => 'grubbs/info.c0.unitstatus',
		drivestatus => 'grubbs/info.c0.drivestatus',
		bbustatus => 'grubbs/info.c0.bbustatus',
		#enc_show_all => 'grubbs/c0.eX.show.all',
		message => 'c0(9750-4i): u0(RAID-1): OK, Cache:RiW, c0(9750-4i): u1(RAID-10): OK, Cache:RiW, c0(9750-4i): u2(RAID-0): OK, Cache:RiW, Drives(14): p10,p11,p12,p13,p14,p15,p16,p17,p18,p19,p20,p21=OK p8,p9=SPARE, BBU: OK(Volt=OK,Temp=OK,Hours=93,LastCapTest=24-Jul-2012)',
		c => 'grubbs-bbu-noenc',
	},
	{
		status => WARNING,
		info => 'grubbs/info',
		show => 'grubbs/show',
		unitstatus => 'grubbs/info.c0.unitstatus',
		drivestatus => 'grubbs/info.c0.drivestatus',
		#bbustatus => 'grubbs/info.c0.bbustatus',
		enc_show_all => 'grubbs/c0.eX.show.all',
		message => 'c0(9750-4i): u0(RAID-1): OK, Cache:RiW, c0(9750-4i): u1(RAID-10): OK, Cache:RiW, c0(9750-4i): u2(RAID-0): OK, Cache:RiW, Drives(14): p10,p11,p12,p13,p14,p15,p16,p17,p18,p19,p20,p21=OK p8,p9=SPARE, BBU: OK, Enclosure: /c0/e0(temp0=OK(22C),slot3=OK,slot6=OK,alm0=ACTIVATED(State=ON,Audibility=UNMUTE)), Enclosure: /c0/e1(fan0=OK(6900),fan1=OK(6900),fan2=OK(6660),temp0=OK(24C),slot1=OK,slot10=OK,slot13=OK,slot15=OK,slot17=OK,slot18=OK,slot20=OK,slot22=OK,slot3=OK,slot5=OK,slot6=OK,slot8=OK,alm0=ACTIVATED(State=ON,Audibility=UNMUTE))',
		c => 'grubbs-nobbu-enc',
	},
	{
		status => WARNING,
		info => 'grubbs/info',
		show => 'grubbs/show',
		unitstatus => 'grubbs/info.c0.unitstatus',
		drivestatus => 'grubbs/info.c0.drivestatus',
		bbustatus => 'grubbs/info.c0.bbustatus',
		enc_show_all => 'grubbs/c0.eX.show.all',
		message => 'c0(9750-4i): u0(RAID-1): OK, Cache:RiW, c0(9750-4i): u1(RAID-10): OK, Cache:RiW, c0(9750-4i): u2(RAID-0): OK, Cache:RiW, Drives(14): p10,p11,p12,p13,p14,p15,p16,p17,p18,p19,p20,p21=OK p8,p9=SPARE, BBU: OK(Volt=OK,Temp=OK,Hours=93,LastCapTest=24-Jul-2012), Enclosure: /c0/e0(temp0=OK(22C),slot3=OK,slot6=OK,alm0=ACTIVATED(State=ON,Audibility=UNMUTE)), Enclosure: /c0/e1(fan0=OK(6900),fan1=OK(6900),fan2=OK(6660),temp0=OK(24C),slot1=OK,slot10=OK,slot13=OK,slot15=OK,slot17=OK,slot18=OK,slot20=OK,slot22=OK,slot3=OK,slot5=OK,slot6=OK,slot8=OK,alm0=ACTIVATED(State=ON,Audibility=UNMUTE))',
		c => 'grubbs',
	},
	{
		status => WARNING,
		info => 'grubbs/info',
		show => 'grubbs/show',
		unitstatus => 'grubbs/info.c0.unitstatus',
		drivestatus => 'grubbs/info.c0.drivestatus',
		bbustatus => 'grubbs/info.c0.bbustatus',
		enc_show_all => 'grubbs/c0.e0.show.all',
		message => 'c0(9750-4i): u0(RAID-1): OK, Cache:RiW, c0(9750-4i): u1(RAID-10): OK, Cache:RiW, c0(9750-4i): u2(RAID-0): OK, Cache:RiW, Drives(14): p10,p11,p12,p13,p14,p15,p16,p17,p18,p19,p20,p21=OK p8,p9=SPARE, BBU: OK(Volt=OK,Temp=OK,Hours=93,LastCapTest=24-Jul-2012), Enclosure: /c0/e0(temp0=OK(22C),slot3=OK,slot6=OK,alm0=ACTIVATED(State=ON,Audibility=UNMUTE))',
		c => 'grubbs-e0',
	},
	{
		status => WARNING,
		info => 'grubbs/info',
		show => 'grubbs/show',
		unitstatus => 'grubbs/info.c0.unitstatus',
		drivestatus => 'grubbs/info.c0.drivestatus',
		bbustatus => 'grubbs/info.c0.bbustatus',
		enc_show_all => 'grubbs/c0.e1.show.all',
		message => 'c0(9750-4i): u0(RAID-1): OK, Cache:RiW, c0(9750-4i): u1(RAID-10): OK, Cache:RiW, c0(9750-4i): u2(RAID-0): OK, Cache:RiW, Drives(14): p10,p11,p12,p13,p14,p15,p16,p17,p18,p19,p20,p21=OK p8,p9=SPARE, BBU: OK(Volt=OK,Temp=OK,Hours=93,LastCapTest=24-Jul-2012), Enclosure: /c0/e1(fan0=OK(6900),fan1=OK(6900),fan2=OK(6660),temp0=OK(24C),slot1=OK,slot10=OK,slot13=OK,slot15=OK,slot17=OK,slot18=OK,slot20=OK,slot22=OK,slot3=OK,slot5=OK,slot6=OK,slot8=OK,alm0=ACTIVATED(State=ON,Audibility=UNMUTE))',
		c => 'grubbs-e1',
	},
	{
		status => WARNING,
		info => 'bohr/info',
		show => 'bohr/show',
		unitstatus => 'bohr/info.c0.unitstatus',
		drivestatus => 'bohr/info.c0.drivestatus',
		bbustatus => 'bohr/info.c0.bbustatus',
		message => 'c0(9650SE-8LPML): u0(RAID-10): OK, Cache:RiW, c0(9650SE-8LPML): u1(JBOD): OK, Cache:Ri, c0(9650SE-8LPML): u2(JBOD): OK, Cache:Ri, Drives(6): p0,p1,p2,p3,p4,p5=OK, BBU: OK/LEARN(Volt=OK,Temp=OK,Hours=0,LastCapTest=xx-xxx-xxxx)',
		c => 'bohr',
	},
);

# test that plugin can be created
ok(tw_cli->new, "plugin created");

foreach my $test (@tests) {
	my $commands = {
	};
	my $emptyfile = TESTDIR . '/data/tw_cli/empty';
	foreach my $commandname (qw(info show unitstatus drivestatus bbustatus enc_show_all)) {
		my $f;
		if($test->{$commandname}) {
			$f = TESTDIR . '/data/tw_cli/' .$test->{$commandname};
		} else {
			$f = $emptyfile;
		}
		$commands->{$commandname} = ['<', $f ];
	}
	my $plugin = tw_cli->new(
		commands => $commands,
		options => { bbu_monitoring => 1, bbulearn => 'OK' },
	);
	ok($plugin, "plugin created ($test->{c})");

	$plugin->check;
	ok(1, "check ran ($test->{c})");

	ok(defined($plugin->status), "status code set ($test->{c})");
	is($plugin->status, $test->{status}, "status code matches ($test->{c})");
	is($plugin->message, $test->{message}, "status message ($test->{c})");

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
