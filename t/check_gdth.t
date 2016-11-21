#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use Test::More tests => 21;
use test;

my @tests = (
	{
		status => OK,
		proc => 'test1',
		entry => 'test1/$controller',
		message => 'Controller 0: Array 0(RAID-5) ready; Logical Drives: 0,1,2,3=ok',
	},
	{
		status => CRITICAL,
		proc => 'test-fail',
		entry => 'test-fail/$controller',
		message => 'Controller 0: Array 0(RAID-5) fail; Logical Drives: 0,1,2,3,4,5=ok',
	},
	{
		status => OK,
		proc => 'test-mammoth',
		entry => 'test-mammoth/$controller',
		message => 'Controller 0: Array(RAID-1) ok; Logical Drives: 11=ok',
	},
	{
		status => WARNING,
		proc =>  'test-missingdrv',
		entry => 'test-missingdrv/$controller',
		message => 'Controller 0: Array(RAID-1) ok (1 missing drives); Logical Drives: 0=ok; Disk B/00/0(MAXTOR  ATLAS10K4_73SCA) grown defects warning: 288, not assigned',
	},
);

# test that plugin can be created
ok(gdth->new, "plugin created");

foreach my $test (@tests) {
	my $plugin = gdth->new(
		commands => {
			'proc' => ['<', TESTDIR . '/data/gdth/' .$test->{proc} ],
			'proc entry' => ['<', TESTDIR . '/data/gdth/' .$test->{entry} ],
		},
	);

	ok($plugin, "plugin created: $test->{proc}");

	$plugin->check;
	ok(1, "check ran");

	ok(defined($plugin->status), "status code set");
	is($plugin->status, $test->{status}, "status code matches");
	is($plugin->message, $test->{message}, "status message");
}
