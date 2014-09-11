#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use constant TESTS => 15;
use Test::More tests => TESTS*7;
use test;

my @tests = (
	{
		status => OK,
		pdlist => 'megacli.pdlist.1',
		ldinfo => 'megacli.ldinfo.1',
		battery => 'empty',
		message => 'Volumes(2): OS:Optimal,DATA:Optimal; Devices(12): 14,16=Hotspare 04,05,06,07,08,09,10,11,12,13=Online',
		perfdata => '',
		longoutput => '',
	},
	{
		status => OK,
		pdlist => 'megacli.pdlist.2',
		ldinfo => 'megacli.ldinfo.2',
		battery => 'empty',
		message => 'Volumes(1): DISK0.0:Optimal; Devices(11): 16=Hotspare 11,12,13,14,15,17=Online 18,19,20,21=Unconfigured(good)',
		perfdata => '',
		longoutput => '',
	},
	{
		status => OK,
		pdlist => 'issue41/pdlist',
		ldinfo => 'issue41/ldinfo',
		battery => 'empty',
		message => 'Volumes(3): DISK0.0:Optimal,DISK1.1:Optimal,DISK2.2:Optimal; Devices(6): 11,10,09,08,12,13=Online',
		perfdata => '',
		longoutput => '',
	},
	{
		status => CRITICAL,
		pdlist => 'megacli.pdlist.2',
		ldinfo => 'empty',
		battery => 'empty',
		message => 'Volumes(0): ; Devices(11): 16=Hotspare 11,12,13,14,15,17=Online 18,19,20,21=Unconfigured(good)',
		perfdata => '',
		longoutput => '',
	},
	{
		status => CRITICAL,
		pdlist => 'issue39/batteries.pdlist',
		ldinfo => 'issue39/batteries.ldinfo',,
		battery => 'issue39/batteries.bbustatus',
		message => 'Volumes(1): DISK0.0:Optimal; Devices(12): 14,16=Hotspare 04,05,06,07,08,09,10,11,12,13=Online; Batteries(1): 0=Faulty',
		perfdata => 'Battery0_T=30;;;; Battery0_V=4026;;;;',
		longoutput => "Battery0:\n - State: Faulty\n - Charging status: None\n - Learn cycle requested: No\n - Learn cycle active: No\n - Missing: No\n - Replacement required: Yes\n - Temperature: OK (30 C)\n - Voltage: OK (4026 mV)",
	},
	{
		status => OK,
		pdlist => 'issue39/batteries.pdlist.1',
		ldinfo => 'issue39/batteries.ldinfo.1',,
		battery => 'issue39/batteries.bbustatus.1',
		message => 'Volumes(1): DISK0.0:Optimal; Devices(2): 08,07=Online; Batteries(1): 0=Operational',
		perfdata => 'Battery0_T=18;;;; Battery0_V=3923;;;;',
		longoutput => "Battery0:\n - State: Operational\n - Charging status: None\n - Learn cycle requested: No\n - Learn cycle active: No\n - Missing: No\n - Replacement required: No\n - About to fail: No\n - Temperature: OK (18 C)\n - Voltage: OK (3923 mV)",
	},
	{
		status => CRITICAL,
		pdlist => 'issue39/batteries.pdlist.2',
		ldinfo => 'issue39/batteries.ldinfo.2',,
		battery => 'issue39/batteries.bbustatus.2',
		message => 'Volumes(1): DISK0.0:Optimal; Devices(2): 04,05=Online; Batteries(1): 0=Operational',
		perfdata => 'Battery0_T=26;;;; Battery0_V=4053;;;;',
		longoutput => "Battery0:\n - State: Operational\n - Charging status: None\n - Learn cycle requested: No\n - Learn cycle active: No\n - Missing: No\n - Replacement required: Yes\n - About to fail: No\n - Temperature: OK (26 C)\n - Voltage: OK (4053 mV)",
	},
	{
		status => WARNING,
		pdlist => 'issue39/batteries.pdlist.3',
		ldinfo => 'issue39/batteries.ldinfo.3',,
		battery => 'issue39/batteries.bbustatus.3',
		message => 'Volumes(1): DISK0.0:Optimal; Devices(2): 04,05=Online; Batteries(1): 0=Non Operational',
		perfdata => 'Battery0_T=22;;;; Battery0_V=4090;;;;',
		longoutput => "Battery0:\n - State: Non Operational\n - Charging status: Charging\n - Learn cycle requested: Yes\n - Learn cycle active: Yes\n - Missing: No\n - Replacement required: No\n - About to fail: No\n - Temperature: OK (22 C)\n - Voltage: OK (4090 mV)",
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
		longoutput => "Battery0:\n - State: Non Operational\n - Charging status: Charging\n - Learn cycle requested: Yes\n - Learn cycle active: Yes\n - Missing: No\n - Replacement required: No\n - About to fail: No\n - Temperature: OK (22 C)\n - Voltage: OK (4090 mV)",
	},
	{
		status => OK,
		pdlist => 'issue45/MegaCli64-list.out',
		ldinfo => 'issue45/MegaCli64-ldinfo.out',
		battery => 'issue45/MegaCli64-adpbbucmd.out',
		message => 'Volumes(7): DISK0.0:Optimal,DISK1.1:Optimal,DISK2.2:Optimal,DISK3.3:Optimal,DISK4.4:Optimal,DISK5.5:Optimal,DISK6.6:Optimal; Devices(8): 11,12,13,14,10,15,09,08=Online; Batteries(1): 0=Optimal',
		perfdata => 'Battery0_T=34;;;; Battery0_V=4073;;;;',
		longoutput => "Battery0:\n - State: Optimal\n - Charging status: None\n - Learn cycle requested: No\n - Learn cycle active: No\n - Missing: No\n - Replacement required: No\n - About to fail: No\n - Temperature: OK (34 C)\n - Voltage: OK (4073 mV)",
	},
	{
		status => CRITICAL,
		pdlist => '3/pdlist',
		ldinfo => '3/ldinfo',
		battery => '3/bucmd',
		message => 'Volumes(1): DISK0.0:Optimal; Devices(12): 14=Hotspare 04,05,06,07,08,09,10,11,12,16=Online 13 (W1F3ZE1TST3000DM001-1CH166 CC27)=Unconfigured(bad); Batteries(1): 0=Faulty',
		perfdata => 'Battery0_T=29;;;; Battery0_V=4069;;;;',
		longoutput => "Battery0:\n - State: Faulty\n - Charging status: None\n - Learn cycle requested: No\n - Learn cycle active: No\n - Missing: No\n - Replacement required: No\n - Temperature: OK (29 C)\n - Voltage: OK (4069 mV)",
	},
	{
		status => OK,
		pdlist => 'pr74/pdlist',
		ldinfo => 'pr74/ldinfo',
		battery => 'empty',
		message => 'Volumes(1): raid10:Optimal; Devices(6): 00,01,02,03,04,05=Online',
		perfdata => '',
		longoutput => '',
	},
	{
		status => CRITICAL,
		pdlist => 'issue49/pdlist',
		ldinfo => 'empty', # faked, as original is MISSING, see #49
		battery => 'issue49/battery',
		message => 'Volumes(0): ; Devices(6): 10,09,13,08,11=Online 14 (IBM-ESXSST9300603SS F B53B3SE0WJ1Y0825B53B)=Predictive; Batteries(1): 0=Faulty',
		perfdata => 'Battery0_T=36;;;; Battery0_V=4049;;;;',
		longoutput => "Battery0:\n - State: Faulty\n - Charging status: None\n - Learn cycle requested: No\n - Learn cycle active: No\n - Missing: No\n - Replacement required: Yes\n - Temperature: OK (36 C)\n - Voltage: OK (4049 mV)"
	},
	{
		status => CRITICAL,
		pdlist => 'empty', # faked
		ldinfo => 'empty', # faked, as original is MISSING, see #32
		battery => 'issue32/bbustatus.MegaCli-8.01.06-1',
		message => 'Volumes(0): ; Devices(0): ',
		perfdata => '',
		longoutput => '',
	},
	{
		status => CRITICAL,
		pdlist => 'empty', # faked
		ldinfo => 'empty', # faked, as original is MISSING, see #32
		battery => 'issue32/bbustatus.MegaCli-8.07.10-1',
		message => 'Volumes(0): ; Devices(0): ',
		perfdata => '',
		longoutput => '',
	},
);

# save default value
my $saved_bbulearn_status = $plugin::bbulearn_status;

$plugin::bbu_monitoring = 1;

foreach my $test (@tests) {
	my $plugin = megacli->new(
		commands => {
			'pdlist' => ['<', TESTDIR . '/data/megacli/' . $test->{pdlist}],
			'ldinfo' => ['<', TESTDIR . '/data/megacli/' . $test->{ldinfo}],
			'battery' => ['<', TESTDIR . '/data/megacli/' . $test->{battery}],
		},
	);

	ok($plugin, "plugin created");

	if (defined($test->{bbulearn_status})) {
		$plugin::bbulearn_status = $test->{bbulearn_status};
	} else {
		$plugin::bbulearn_status = $saved_bbulearn_status;
	}

	$plugin->check;
	ok(1, "check ran");

	ok(defined($plugin->status), "status code set");
	ok($plugin->status == $test->{status}, "status code (got:".$plugin->status." exp:".$test->{status}.")");
	print "[".$plugin->message."]\n";
	ok($plugin->message eq $test->{message}, "status message");

	if ($test->{perfdata} ne '' || $plugin->perfdata ne '') {
		print "[".$plugin->perfdata."]\n";
	}
	ok($plugin->perfdata eq $test->{perfdata}, "performance data");

	if ($test->{longoutput} ne '' || $plugin->longoutput ne '') {
		print "[".$plugin->longoutput."]\n";
	}
	ok($plugin->longoutput eq $test->{longoutput}, "long output");
}
