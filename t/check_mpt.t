#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use Test::More tests => 31;
use test;

my @tests = (
	{
		status => OK,
		get_controller_no => 'pr36/getctrlno1', # FAKE
		input => 'mpt-status',
		message => 'Volume 0 (RAID-1, 2 disks, 136 GiB): OPTIMAL',
	},
	{
		status => CRITICAL,
		get_controller_no => 'pr36/getctrlno1', # FAKE
		input => 'mpt-syncing',
		sync_status => 'mpt-syncing-n',
		message => 'Volume 0 (RAID-1, 2 disks, 68 GiB): DEGRADED RESYNCING: 70%/70%, Disk 1 (68 GiB):ONLINE OUT_OF_SYNC',
	},
	{
		status => OK,
		get_controller_no => 'pr36/getctrlno1', # FAKE
		input => 'mpt-status-ata',
		message => 'Volume 0 (RAID-1, 2 disks, 73 GiB): OPTIMAL',
	},
	{
		status => OK,
		get_controller_no => 'pr36/getctrlno1', # FAKE
		input => 'mpt-status-pr27',
		message => 'Volume 0 (RAID-1, 2 disks, 73 GiB): OPTIMAL',
	},
	{
		status => OK,
		get_controller_no => 'pr36/getctrlno1',
		input => 'pr36/status1',
		message => 'Volume 1 (RAID-1, 2 disks, 135 GiB): OPTIMAL',
	},
	{
		status => OK,
		get_controller_no => 'pr57/getctrlno13',
		input => 'pr57/status13',
		message => 'Volume 13 (RAID-1, 2 disks, 135 GiB): OPTIMAL',
	},
);

# test that plugin can be created
ok(mpt->new, "plugin created");

foreach my $test (@tests) {
	my $plugin = mpt->new(
		commands => {
			'status' => ['<', TESTDIR . '/data/mpt/' . $test->{input}],
			'sync status' => $test->{sync_status} ? ['<', TESTDIR . '/data/mpt/' . $test->{sync_status}] : undef,
			'get_controller_no' => ['<', TESTDIR . '/data/mpt/' . $test->{get_controller_no}],
		},
	);

	ok($plugin, "plugin created: $test->{input}");

	$plugin->check;
	ok(1, "check ran");

	ok(defined($plugin->status), "status code set");
	is($plugin->status, $test->{status}, "status code matches");
	is($plugin->message, $test->{message}, "status message");
}
