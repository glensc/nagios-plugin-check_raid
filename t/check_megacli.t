#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use constant TESTS => 19;
use Test::More tests => 1 + TESTS * 8;
use test;

my @tests = (
	{
		status => OK,
		pdlist => 'megacli.pdlist.1',
		ldinfo => 'megacli.ldinfo.1',
		battery => 'empty',
		message => 'Volumes(2): OS:Optimal,DATA:Optimal; Devices(12): 14,16=Hotspare 04,05,06,07,08,09,10,11,12,13=Online',
		perfdata => '',
		longoutput => [],
		c => 'megacli.1',
	},
	{
		status => OK,
		pdlist => 'megacli.pdlist.2',
		ldinfo => 'megacli.ldinfo.2',
		battery => 'empty',
		message => 'Volumes(1): DISK0.0:Optimal; Devices(11): 16=Hotspare 11,12,13,14,15,17=Online 18,19,20,21=Unconfigured(good)',
		perfdata => '',
		longoutput => [],
		c => 'megacli.2',
	},
	{
		status => OK,
		pdlist => 'issue41/pdlist',
		ldinfo => 'issue41/ldinfo',
		battery => 'empty',
		message => 'Volumes(3): DISK0.0:Optimal,DISK1.1:Optimal,DISK2.2:Optimal; Devices(6): 11,10,09,08,12,13=Online',
		perfdata => '',
		longoutput => [],
		c => 'issue41',
	},
	{
		status => CRITICAL,
		pdlist => 'megacli.pdlist.2',
		ldinfo => 'empty',
		battery => 'empty',
		message => 'Volumes(0): ; Devices(11): 16=Hotspare 11,12,13,14,15,17=Online 18,19,20,21=Unconfigured(good)',
		perfdata => '',
		longoutput => [],
		c => 'megacli.pdlist.2',
	},
	{
		status => CRITICAL,
		pdlist => 'issue39/batteries.pdlist',
		ldinfo => 'issue39/batteries.ldinfo',,
		battery => 'issue39/batteries.bbustatus',
		message => 'Volumes(1): DISK0.0:Optimal,WriteCache:DISABLED; Devices(12): 14,16=Hotspare 04,05,06,07,08,09,10,11,12,13=Online; Batteries(1): 0=Faulty',
		perfdata => 'Battery0_T=30;;;; Battery0_V=4026;;;;',
		longoutput => [
			"Battery0:",
			" - State: Faulty",
			" - Charging status: None",
			" - Learn cycle requested: No",
			" - Learn cycle active: No",
			" - Missing: No",
			" - Replacement required: Yes",
			" - Temperature: OK (30 C)",
			" - Voltage: OK (4026 mV)",
		],
		c => 'issue39',
	},
	{
		status => OK,
		pdlist => 'issue39/batteries.pdlist.1',
		ldinfo => 'issue39/batteries.ldinfo.1',,
		battery => 'issue39/batteries.bbustatus.1',
		message => 'Volumes(1): DISK0.0:Optimal; Devices(2): 08,07=Online; Batteries(1): 0=Operational',
		perfdata => 'Battery0_T=18;;;; Battery0_V=3923;;;;',
		longoutput => [
			"Battery0:",
		   	" - State: Operational",
		   	" - Charging status: None",
			" - Learn cycle requested: No",
			" - Learn cycle active: No",
			" - Missing: No",
			" - Replacement required: No",
			" - About to fail: No",
			" - Temperature: OK (18 C)",
			" - Voltage: OK (3923 mV)"
		],
		c => 'issue39.1',
	},
	{
		status => CRITICAL,
		pdlist => 'issue39/batteries.pdlist.2',
		ldinfo => 'issue39/batteries.ldinfo.2',,
		battery => 'issue39/batteries.bbustatus.2',
		message => 'Volumes(1): DISK0.0:Optimal; Devices(2): 04,05=Online; Batteries(1): 0=Operational',
		perfdata => 'Battery0_T=26;;;; Battery0_V=4053;;;;',
		longoutput => [
			"Battery0:",
			" - State: Operational",
			" - Charging status: None",
			" - Learn cycle requested: No",
			" - Learn cycle active: No",
			" - Missing: No",
			" - Replacement required: Yes",
			" - About to fail: No",
			" - Temperature: OK (26 C)",
			" - Voltage: OK (4053 mV)",
		],
		c => 'issue39.2',
	},
	{
		status => WARNING,
		pdlist => 'issue39/batteries.pdlist.3',
		ldinfo => 'issue39/batteries.ldinfo.3',,
		battery => 'issue39/batteries.bbustatus.3',
		message => 'Volumes(1): DISK0.0:Optimal; Devices(2): 04,05=Online; Batteries(1): 0=Non Operational',
		perfdata => 'Battery0_T=22;;;; Battery0_V=4090;;;;',
		longoutput => [
			"Battery0:",
			" - State: Non Operational",
			" - Charging status: Charging",
			" - Learn cycle requested: Yes",
			" - Learn cycle active: Yes",
			" - Missing: No",
			" - Replacement required: No",
			" - About to fail: No",
			" - Temperature: OK (22 C)",
			" - Voltage: OK (4090 mV)",
		],
		c => 'issue39.3',
	},
	{
		status => CRITICAL,
		bbulearn_status => CRITICAL,
		pdlist => 'issue39/batteries.pdlist.3',
		ldinfo => 'issue39/batteries.ldinfo.3',,
		battery => 'issue39/batteries.bbustatus.3',
		message => 'Volumes(1): DISK0.0:Optimal; Devices(2): 04,05=Online; Batteries(1): 0=Non Operational',
		perfdata => 'Battery0=22;4090',
		perfdata => 'Battery0_T=22;;;; Battery0_V=4090;;;;',
		longoutput => [
			"Battery0:",
			" - State: Non Operational",
			" - Charging status: Charging",
			" - Learn cycle requested: Yes",
			" - Learn cycle active: Yes",
			" - Missing: No",
			" - Replacement required: No",
			" - About to fail: No",
			" - Temperature: OK (22 C)",
			" - Voltage: OK (4090 mV)",
		],
		c => 'issue39.3',
	},
	{
		status => OK,
		pdlist => 'issue45/MegaCli64-list.out',
		ldinfo => 'issue45/MegaCli64-ldinfo.out',
		battery => 'issue45/MegaCli64-adpbbucmd.out',
		message => 'Volumes(7): DISK0.0:Optimal,DISK1.1:Optimal,DISK2.2:Optimal,DISK3.3:Optimal,DISK4.4:Optimal,DISK5.5:Optimal,DISK6.6:Optimal; Devices(8): 11,12,13,14,10,15,09,08=Online; Batteries(1): 0=Optimal',
		perfdata => 'Battery0_T=34;;;; Battery0_V=4073;;;;',
		longoutput => [
			"Battery0:",
			" - State: Optimal",
			" - Charging status: None",
			" - Learn cycle requested: No",
			" - Learn cycle active: No",
			" - Missing: No",
			" - Replacement required: No",
			" - About to fail: No",
			" - Temperature: OK (34 C)",
			" - Voltage: OK (4073 mV)",
		],
		c => 'issue45',
	},
	{
		status => CRITICAL,
		pdlist => '3/pdlist',
		ldinfo => '3/ldinfo',
		battery => '3/bucmd',
		message => 'Volumes(1): DISK0.0:Optimal; Devices(12): 14=Hotspare 04,05,06,07,08,09,10,11,12,16=Online 13 (W1F3ZE1TST3000DM001-1CH166 CC27)=Unconfigured(bad); Batteries(1): 0=Faulty',
		perfdata => 'Battery0_T=29;;;; Battery0_V=4069;;;;',
		longoutput => [
			"Battery0:",
			" - State: Faulty",
			" - Charging status: None",
			" - Learn cycle requested: No",
			" - Learn cycle active: No",
			" - Missing: No",
			" - Replacement required: No",
			" - Temperature: OK (29 C)",
			" - Voltage: OK (4069 mV)",
		],
		c => 'megacli.3',
	},
	{
		status => OK,
		pdlist => 'pr74/pdlist',
		ldinfo => 'pr74/ldinfo',
		battery => 'empty',
		message => 'Volumes(1): raid10:Optimal; Devices(6): 00,01,02,03,04,05=Online',
		perfdata => '',
		longoutput => [],
		c => 'pr74',
	},
	{
		status => CRITICAL,
		pdlist => 'issue49/pdlist',
		ldinfo => 'empty', # faked, as original is MISSING, see #49
		battery => 'issue49/battery',
		message => 'Volumes(0): ; Devices(6): 10,09,13,08,11=Online 14 (IBM-ESXSST9300603SS F B53B3SE0WJ1Y0825B53B)=Predictive; Batteries(1): 0=Faulty',
		perfdata => 'Battery0_T=36;;;; Battery0_V=4049;;;;',
		longoutput => [
			"Battery0:",
			" - State: Faulty",
			" - Charging status: None",
			" - Learn cycle requested: No",
			" - Learn cycle active: No",
			" - Missing: No",
			" - Replacement required: Yes",
			" - Temperature: OK (36 C)",
			" - Voltage: OK (4049 mV)",
		],
		c => 'issue49',
	},
	{
		status => CRITICAL,
		pdlist => 'empty', # faked
		ldinfo => 'empty', # faked, as original is MISSING, see #32
		battery => 'issue32/bbustatus.MegaCli-8.01.06-1',
		message => 'Volumes(0): ; Devices(0): ',
		perfdata => '',
		longoutput => [],
		c => 'issue32.8.01',
	},
	{
		status => CRITICAL,
		pdlist => 'empty', # faked
		ldinfo => 'empty', # faked, as original is MISSING, see #32
		battery => 'issue32/bbustatus.MegaCli-8.07.10-1',
		message => 'Volumes(0): ; Devices(0): ',
		perfdata => '',
		longoutput => [],
		c => 'issue32.8.07',
	},
	{
		status => WARNING,
		pdlist => 'issue65/pdlist',
		ldinfo => 'issue65/ldinfo',
		battery => 'empty',
		message => 'Volumes(1): DISK0.0:Optimal,WriteCache:DISABLED; Devices(6): 00,01,02,03,04,05=Online',
		perfdata => '',
		longoutput => [],
		c => 'issue65',
	},
	{
		status => WARNING,
		pdlist => 'issue85/pdlist',
		ldinfo => 'issue85/ldinfo',
		battery => 'empty',
		message => 'Volumes(1): Virtual:Optimal,WriteCache:DISABLED; Devices(2): 00,01=Online',
		perfdata => '',
		longoutput => [],
		c => 'issue85',
	},
	{
		status => OK,
		pdlist => 'megacli.pdlist.jbod',
		ldinfo => 'megacli.ldinfo.jbod',
		battery => 'empty',
		message => 'Volumes(0): ; Devices(4): 00,01,02,03=JBOD',
		perfdata => '',
		longoutput => [],
		c => 'pr82',
	},
	{
		status => OK,
		pdlist => 'issue91/9924033.txt',
		ldinfo => 'issue91/9924032.txt',
		battery => 'issue91/9924031.txt',
		message => 'Volumes(2): raid6:Optimal; Devices(8): 00,01,02,03,04,05,06,07=Online; Batteries(1): 0=Operational',
		perfdata => 'Battery0_T=39;;;; Battery0_V=3933;;;;',
		longoutput => [
			"Battery0:",
			" - State: Operational",
			" - Charging status: None",
			" - Learn cycle requested: No",
			" - Learn cycle active: No",
			" - Missing: No",
			" - Replacement required: No",
			" - About to fail: No",
			" - Temperature: OK (39 C)",
			" - Voltage: OK (3933 mV)",
		],
		c => 'issue91',
	},
);

# test that plugin can be created
ok(megacli->new, "plugin created");

foreach my $test (@tests) {
	my %options = (
		bbu_monitoring => 1,
	);
	if (defined($test->{bbulearn_status})) {
		$options{bbulearn_status} = $test->{bbulearn_status};
	}

	my $plugin = megacli->new(
		commands => {
			'pdlist' => ['<', TESTDIR . '/data/megacli/' . $test->{pdlist}],
			'ldinfo' => ['<', TESTDIR . '/data/megacli/' . $test->{ldinfo}],
			'battery' => ['<', TESTDIR . '/data/megacli/' . $test->{battery}],
		},
		options => \%options,
	);

	ok($plugin, "plugin created");

	$plugin->check;
	ok(1, "check ran");

	ok(defined($plugin->status), "status code set");
	is($plugin->status, $test->{status}, "status code matches");
	is($plugin->message, $test->{message}, "status message");
	is($plugin->perfdata, $test->{perfdata}, "performance data");
	my $longoutput = join("\n", @{$test->{longoutput}});
	is($plugin->longoutput, $longoutput, "long output");

	my $c = $plugin->parse;
	my $df = TESTDIR . '/dump/megacli/' . $test->{c};
	if (!-f $df) {
		store_dump $df, $c;
		# trigger error so that we don't have feeling all is ok ;)
		ok(0, "Created dump for $df");
	}
	my $dump = read_dump($df);
	is_deeply($c, $dump, "controller structure");
}
