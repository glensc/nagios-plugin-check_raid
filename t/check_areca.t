#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use constant TESTS => 4;
use Test::More tests => TESTS*5;
use test;

my @tests = (
	{
		status => OK,
		rsf => 'cli64.rsf.info-1',
		disk => 'cli64.disk.info-1',
		message => 'Array#1(Raid Set # 000): Normal, Drive Assignment: 9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,31,32=Array#1 30=HotSpare',
	},
	{
		status => CRITICAL,
		rsf => 'cli64.rsf.info-16',
		disk => 'cli64.disk.info-16',
		message => 'Array#1(data): Rebuilding, Drive Assignment: 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15=Array#1 16=Failed',
	},
	{
		status => OK,
		rsf => 'ticket40/areca-rsf-info.txt',
		disk => 'ticket40/areca-disk-info.txt',
		message => 'Array#1(Raid Set # 00): Normal, Drive Assignment: 1,2,3,4,5,6,7,8,9=Array#1',
	},
	{
		status => OK,
		rsf => 'pr72/areca_cli64_rsf_info.out',
		disk => 'pr72/areca_cli64_disk_info.out',
		message => 'Array#1(Raid Set # 000): Normal, Array#2(data2): Normal, Array#3(PassThroughDisk): Normal, Drive Assignment: 9,10,11,12,13,14=Array#1 15,16,17,18,19,20=Array#2 21=Pass Through',
	},
);

foreach my $test (@tests) {
	my $plugin = areca->new(
		commands => {
			'rsf info' => ['<', TESTDIR . '/data/areca/' . $test->{rsf} ],
			'disk info' => ['<', TESTDIR . '/data/areca/' . $test->{disk} ],
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
