#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use Test::More tests => 10;
use test;

if (1) {
my $plugin = mpt->new(
	commands => {
		'status' => ['<', TESTDIR . '/data/mpt/mpt-status'],
	},
);

ok($plugin, "plugin created");
$plugin->check;
ok(1, "check ran");
ok(defined($plugin->status), "status code set");
ok($plugin->status == OK, "status code");
print "[".$plugin->message."]\n";
ok($plugin->message eq 'Volume 0 (RAID-1, 2 disks, 136 GiB): OPTIMAL');
}

if (1) {
my $plugin = mpt->new(
	commands => {
		'status' => ['<', TESTDIR . '/data/mpt/mpt-syncing'],
	},
);

ok($plugin, "plugin created");
$plugin->check;
ok(1, "check ran");
ok(defined($plugin->status), "status code set");
ok($plugin->status == CRITICAL, "status code");
print "[".$plugin->message."]\n";
ok($plugin->message eq 'Volume 0 (RAID-1, 2 disks, 68 GiB): DEGRADED RESYNCING');
}
