#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use Test::More tests => 10;
use test;

{
	my $plugin = cciss->new(
		commands => {
			'detect hpsa' => [ '<', TESTDIR . '/data/hpsa.refcnt'],
			'detect cciss' => ['<', 'no-file'],

			'controller status' => ['<', TESTDIR . '/data/cciss_vol_status.zen'],
			'smartctl' => ['<', TESTDIR . '/data/smartctl.cciss.$disk' ],

		},
		no_smartctl => 1,
	);

	ok($plugin, "plugin created");
	$plugin->check;
	ok(1, "check ran");
	ok(defined($plugin->status), "status code set");
	ok($plugin->status == OK, "status OK");
	print "[".$plugin->message."]\n";
	ok($plugin->message eq '/dev/sda: (Smart Array P410i) RAID 1 Volume 0 status: OK');
}

{
	my $plugin = cciss->new(
		commands => {
			'detect hpsa' => [ '<', 'no-such-file'],
			'detect cciss' => ['<', TESTDIR . '/data/cciss'],
			'controller status' => ['<', TESTDIR . '/data/cciss_vol_status.argos'],
			'cciss proc' => [ '<', TESTDIR . '/data/cciss/$controller' ],
			'smartctl' => ['<', TESTDIR . '/data/smartctl.cciss.$disk' ],
		},
		no_smartctl => 1,
	);

	ok($plugin, "plugin created");
	$plugin->check;
	ok(1, "check ran");
	ok(defined($plugin->status), "status code set");
	ok($plugin->status == OK, "status OK");
	print "[".$plugin->message."]\n";
	ok($plugin->message eq '/dev/cciss/c0d0: (Smart Array P400i) RAID 6 Volume 0 status: OK');
}
