#!/usr/bin/perl -w
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use constant TESTS => 10;
use Test::More tests => 2 + TESTS * 5;
use test;

# NOTE: this plugin has side effect of changing dir
use Cwd;
ok(chdir(TESTDIR), "dir changed");
my $cwd = Cwd::cwd();
ok(defined($cwd), "cwd set");

my @tests = (
	{
		status => OK,
		getstatus => '1/getstatus',
		getconfig => '1/getconfig',
		message => 'Controller:Optimal, Logical Device 0:Optimal, Drives: 3LQ1WEH4,3LQ1WEWL=Online',
	},
	{
		status => OK,
		getstatus => '1/getstatus',
		getconfig => '2/getconfig',
		message => 'Controller:Optimal, Battery Status: Optimal, Battery Capacity Remaining: 100%, Battery Time: 3d16h0m, Logical Device 0:Optimal, Drives: 5000C5000B426E88,500000E01BEFF141=Online',
	},
	{
		status => OK,
		getstatus => '3/getstatus',
		getconfig => '3/getconfig',
		message => 'Controller:Optimal, Logical device #0: Build/Verify: In Progress 11%, ZMM Status: ZMM Optimal, Logical Device 0(Volume01):Optimal, Drives: *******,*******,*******,*******=Online',
	},
	{
		status => OK,
		getstatus => '4/arcconf_getstatus_1.out',
		getconfig => '4/arcconf_getconfig_1_al.out',
		message => 'Controller:Okay, Logical Device 1(MailMerak):Okay, Drives: 9QJ2C6NX,GTA060PBGHX61F=Online',
	},
	{
		status => OK,
		getstatus => 'issue31/getstatus',
		getconfig => 'issue31/getconfig',
		message => 'Controller:Optimal, Logical Device 0(OS):Optimal, Logical Device 1(SSDSTORAGEPOOL):Optimal, Logical Device 2(HDDSTORAGEPOOL):Optimal, Drives: xxxx,xxxx,xxxx,xxxx,xxxx,xxxx,xxxx,xxxx,xxxx,xxxx,xxxx=Online',
	},
	{
		status => OK,
		getstatus => 'issue47/getstatus',
		getconfig => 'issue47/getconfig',
		message => 'Controller:Optimal, ZMM Status: ZMM not installed, Logical Device 0(data):Optimal, Drives: WD-WCAW36362892,WD-WCAW36407613,WD-WCAW36385723,WD-WCAW36405341=Online',
	},
	{
		status => CRITICAL,
		getstatus => 'issue47/getstatus2',
		getconfig => 'issue47/getconfig2',
		message => 'Controller:Optimal, Logical device #0: Rebuild: In Progress 1%, ZMM Status: ZMM not installed, Logical Device 0(data):Degraded, Drives: WD-*******,WD-*******,WD-*******=Online WD-*******=Rebuilding',
	},
	{
		status => OK,
		getstatus => 'issue55/arcconf-getstatus.out',
		getconfig => 'issue55/arcconf-getconfig.out',
		message => 'Controller:Optimal, Logical Device 0(plop):Optimal, Drives: Y2O483PAS,Y2O3MYTGS,Y2O3M8RGS=Online S1F02BSH=Online (JBOD)',
	},
	{
		status => OK,
		getstatus => 'issue67/getstatus',
		getconfig => 'issue67/getconfig',
		message => 'Controller:Optimal, Logical Device 0(RAID):Optimal, Drives: 3KS5ABTV0000970648ZZ,3KS5SD1P00009718B64U=Online',
	},
	{
		status => OK,
		getstatus => 'pr66/arcconf-getstatus.out',
		getconfig => 'pr66/arcconf-getconfig.out',
		message => 'Controller:Optimal, Logical Device 0(OS):Optimal, Logical Device 1(SSDSTORAGEPOOL):Optimal, Logical Device 2(HDDSTORAGEPOOL):Optimal, Drives: S1AXNEAD602232X=Dedicated Hot-Spare for logical device 1 S16LNYAF302137=Dedicated Hot-Spare for logical device 100 S1AXNEAD901256E,S1AXNEAD603771B,9XG4LJ8A00009347BBNG,9XG4JJ2900009346AYKE,9XG4KBA800009347W1Q5,9XG4LBM600009347BBQ0,9XG4LHYX00009347W20M,9XG4LHZG00009347W1RL,S16LNYAF302008,S16LNYAF302181,S19HNEAD592704T,S19HNEAD586378L=Online',
	},
);

foreach my $test (@tests) {
	my $plugin = arcconf->new(
		commands => {
			getstatus => ['<', $cwd . '/data/arcconf/' . $test->{getstatus}],
			getconfig => ['<', $cwd . '/data/arcconf/' . $test->{getconfig}],
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
