#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use Test::More tests => 10;
use test;

my @tests = (
##removed for the moment because I dont have an env w/ aprops display to match list and statu
	## no volumes, 12 drives in ready state
	{
		status => OK,
		list => 'pr71/sas2ircu-list.out',
		cstatus => 'pr71/sas2ircu-status.out',
		cdisplay => 'pr71/sas2ircu-display.out',
		message => 'ctrl #0: 0 Vols: No Volumes: 12 Drives: Ready (RDY)::',
	},
	{
		status => OK,
		list => 'test1/LIST.log',
		cstatus => 'test1/0-STATUS.log',
## this file is just a mockup based on the above test since I dont have original output for this case
		cdisplay => 'test1/sas2ircu-display.out',
#and similarly mocked up
	 	message => 'ctrl #0: 1 Vols: Optimal: 3 Drives: Ready (RDY)::',
	},
);

foreach my $test (@tests) {
	my $plugin = sas2ircu->new(
		program => '/bin/true',
		commands => {
			'controller list' => ['<', TESTDIR . '/data/sas2ircu/' . $test->{list} ],
			'controller status' => ['<', TESTDIR . '/data/sas2ircu/' . $test->{cstatus} ],
			'device status' => ['<', TESTDIR . '/data/sas2ircu/' . $test->{cdisplay} ],
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
