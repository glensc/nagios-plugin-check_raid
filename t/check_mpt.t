#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use Test::More tests => 20;
use test;

my @tests = (
	{
		status => OK,
		input => 'mpt-status',
		message => 'Volume 0 (RAID-1, 2 disks, 136 GiB): OPTIMAL',
	},
	{
		status => CRITICAL,
		input => 'mpt-syncing',
		sync_status => 'mpt-syncing-n',
		message => 'Volume 0 (RAID-1, 2 disks, 68 GiB): DEGRADED RESYNCING: 70%/70%, Disk 1 (68 GiB):ONLINE OUT_OF_SYNC',
	},
	{
		status => OK,
		input => 'mpt-status-ata',
		message => 'Volume 0 (RAID-1, 2 disks, 73 GiB): OPTIMAL',
	},
	{
		status => OK,
		input => 'mpt-status-pr27',
		message => 'Volume 0 (RAID-1, 2 disks, 73 GiB): OPTIMAL',
	},
);

foreach my $test (@tests) {
	my $plugin = mpt->new(
		commands => {
			'status' => ['<', TESTDIR . '/data/mpt/' . $test->{input}],
			'sync status' => $test->{sync_status} ? ['<', TESTDIR . '/data/mpt/' . $test->{sync_status}] : undef,
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
