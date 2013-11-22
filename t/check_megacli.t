#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use Test::More tests => 30;
use test;

my @tests = (
	{
		status => OK,
		pdlist => 'megacli.pdlist.1',
		ldinfo => 'megacli.ldinfo.1',
		battery => 'empty',
		message => 'Volumes(2): OS:Optimal,DATA:Optimal; Devices(12): 14,16=Hotspare 04,05,06,07,08,09,10,11,12,13=Online',
	},
	{
		status => OK,
		pdlist => 'megacli.pdlist.2',
		ldinfo => 'megacli.ldinfo.2',
		battery => 'empty',
		message => 'Volumes(1): DISK0.0:Optimal; Devices(11): 16=Hotspare 11,12,13,14,15,17=Online 18,19,20,21=Unconfigured(good)',
	},
	{
		status => OK,
		pdlist => 'issue41/pdlist',
		ldinfo => 'issue41/ldinfo',
		battery => 'empty',
		message => 'Volumes(3): DISK0.0:Optimal,DISK1.1:Optimal,DISK2.2:Optimal; Devices(6): 11,10,09,08,12,13=Online',
	},
	{
		status => CRITICAL,
		pdlist => 'megacli.pdlist.2',
		ldinfo => 'empty',
		battery => 'empty',
		message => 'Volumes(0): ; Devices(11): 16=Hotspare 11,12,13,14,15,17=Online 18,19,20,21=Unconfigured(good)',
	},
	{
		status => CRITICAL,
		pdlist => 'issue39/batteries.pdlist',
		ldinfo => 'issue39/batteries.ldinfo',,
		battery => 'issue39/batteries.bbustatus',
		message => 'Volumes(1): DISK0.0:Optimal; Devices(12): 14,16=Hotspare 04,05,06,07,08,09,10,11,12,13=Online; Batteries(1): 0=???',
	},
	{
		status => OK,
		pdlist => 'issue45/MegaCli64-list.out',
		ldinfo => 'issue45/MegaCli64-ldinfo.out',
		battery => 'issue45/MegaCli64-adpbbucmd.out',
		message => 'Volumes(7): DISK0.0:Optimal,DISK1.1:Optimal,DISK2.2:Optimal,DISK3.3:Optimal,DISK4.4:Optimal,DISK5.5:Optimal,DISK6.6:Optimal; Devices(8): 11,12,13,14,10,15,09,08=Online; Batteries(1): 0=Optimal',
	},
);

foreach my $test (@tests) {
	my $plugin = megacli->new(
		commands => {
			'pdlist' => ['<', TESTDIR . '/data/megacli/' . $test->{pdlist}],
			'ldinfo' => ['<', TESTDIR . '/data/megacli/' . $test->{ldinfo}],
			'battery' => ['<', TESTDIR . '/data/megacli/' . $test->{battery}],
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
