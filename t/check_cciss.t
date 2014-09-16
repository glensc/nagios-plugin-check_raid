#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use constant TESTS => 8;
use Test::More tests =>  TESTS * 6;
use test;

my @tests = (
	{
		status => OK,
		detect_hpsa => 'hpsa.refcnt',
		detect_cciss => 'no-file',
		version => 'cciss-1.09',
		controller => 'cciss_vol_status.zen',
		cciss_proc => '',
		smartctl => 'smartctl.cciss.$disk',
		message => '/dev/sda(Smart Array P410i): Volume 0 (RAID 1): OK',
		c => 'cciss_vol_status.zen',
	},
	{
		status => OK,
		detect_hpsa => 'no-such-file',
		detect_cciss => 'cciss',
		version => 'cciss-1.09',
		controller => 'cciss_vol_status.argos',
		cciss_proc => 'cciss/$controller',
		smartctl => 'smartctl.cciss.$disk',
		message => '/dev/cciss/c0d0(Smart Array P400i): Volume 0 (RAID 6): OK',
		c => 'cciss_vol_status.argos.argos',
	},
	{
		status => OK,
		detect_hpsa => 'no-such-file',
		detect_cciss => 'cciss',
		version => 'cciss-1.11',
		controller => 'cciss_vol_status.cache-status',
		cciss_proc => 'cciss/$controller',
		smartctl => '',
		message => '/dev/cciss/c0d0(Smart Array P400i): Volume 0 (RAID 1): OK, Drives(2): 1I-1-1,1I-1-2=OK, Cache: WriteCache ReadMem:104 MiB WriteMem:104 MiB',
		c => 'cciss_vol_status.cache-status',
	},
	{
		status => OK,
		detect_hpsa => 'no-such-file',
		detect_cciss => 'cciss',
		version => 'cciss-1.11',
		controller => 'cciss_vol_status.cache-status.bruno',
		cciss_proc => 'cciss/$controller',
		smartctl => '',
		message => '/dev/sda(Smart Array P410i): Volume 0 (RAID 1): OK, Drives(2): 1I-1-1,1I-1-2=OK, Cache: WriteCache FlashCache ReadMem:100 MiB WriteMem:300 MiB',
		c => 'cciss_vol_status.cache-status.bruno',
	},
	{
		status => WARNING,
		detect_hpsa => 'no-such-file',
		detect_cciss => 'cciss',
		version => 'cciss-1.11',
		controller => 'cciss_vol_status.argos2',
		cciss_proc => 'cciss/$controller',
		smartctl => 'smartctl.cciss.$disk',
		message => '/dev/cciss/c0d0(Smart Array P400i): Volume 0 (RAID 6): OK, Drives(4): 1I-1-1,1I-1-2,1I-1-3,1I-1-4=OK, Cache: WriteCache:DISABLED ReadMem:104 MiB WriteMem:104 MiB',
		c => 'cciss_vol_status.argos2',
	},
	{
		status => CRITICAL,
		detect_hpsa => 'no-such-file',
		detect_cciss => 'cciss',
		version => 'cciss-1.09',
		controller => 'cciss_vol_status.c1',
		cciss_proc => 'cciss/$controller',
		smartctl => '',
		message => '/dev/cciss/c0d0(Smart Array P400): Volume 0 (RAID 1): OK, /dev/cciss/c1d0(Smart Array P800): Volume 0 (RAID 1): OK, Enclosures: MSA70(SGA651004J): OK, MSA70(SGA6510007): Temperature problem',
		c => 'cciss_vol_status.c1',
	},
	{
		status => OK,
		detect_hpsa => 'no-such-file',
		detect_cciss => 'cciss',
		version => 'cciss-1.11',
		controller => 'cciss_vol_status.cetus',
		cciss_proc => 'cciss/$controller',
		smartctl => 'smartctl.cciss.$disk',
		message => '/dev/cciss/c0d0(Smart Array P400): Volume 0 (RAID 1): OK, Drives(2): 2I-1-1,2I-1-2=OK, Cache: WriteCache ReadMem:52 MiB WriteMem:156 MiB, /dev/cciss/c1d0(Smart Array P800): Volume 0 (RAID 1): OK, Drives(50): 1E-1-1,1E-1-10,1E-1-11,1E-1-12,1E-1-13,1E-1-14,1E-1-15,1E-1-16,1E-1-17,1E-1-18,1E-1-19,1E-1-2,1E-1-20,1E-1-21,1E-1-22,1E-1-23,1E-1-24,1E-1-25,1E-1-3,1E-1-4,1E-1-5,1E-1-6,1E-1-7,1E-1-8,1E-1-9,1E-2-1,1E-2-10,1E-2-11,1E-2-12,1E-2-13,1E-2-14,1E-2-15,1E-2-16,1E-2-17,1E-2-18,1E-2-19,1E-2-2,1E-2-20,1E-2-21,1E-2-22,1E-2-23,1E-2-24,1E-2-25,1E-2-3,1E-2-4,1E-2-5,1E-2-6,1E-2-7,1E-2-8,1E-2-9=OK, Enclosures: MSA70(SGA651004J): OK, MSA70(SGA6510007): OK, Cache: WriteCache ReadMem:114 MiB WriteMem:342 MiB',
		c => 'cciss_vol_status.cetus',
	},
	{
		status => WARNING,
		detect_hpsa => 'no-such-file',
		detect_cciss => 'cciss',
		version => 'cciss-1.11',
		controller => 'cciss_vol_status.lupus',
		cciss_proc => 'cciss/$controller',
		smartctl => '',
		message => '/dev/cciss/c0d0(Smart Array P800): Volume 0 (RAID 1): OK, Volume 1 (RAID 6): OK, Drives(10): 1E-1-1,1E-1-2,1E-1-3,1E-1-4,1E-1-5,1E-1-6,1E-1-7,1E-1-8,4I-1-1,4I-1-2=OK, Enclosures: MSA60(SGA710004E): OK, Cache: WriteCache:DISABLED ReadMem:114 MiB WriteMem:342 MiB',
		c => 'cciss_vol_status.lupus',
	},
);

foreach my $test (@tests) {
	my $plugin = cciss->new(
		commands => {
			'detect hpsa' => ['<', TESTDIR . '/data/' .$test->{detect_hpsa} ],
			'detect cciss' => ['<', TESTDIR . '/data/' .$test->{detect_cciss} ],
			'controller status' => ['<', TESTDIR . '/data/cciss/' .$test->{controller} ],
			'controller status verbose' => ['<', TESTDIR . '/data/cciss/' .$test->{controller} ],
			'cciss_vol_status version' => ['<', TESTDIR . '/data/cciss/' .$test->{version} ],
			'cciss proc' => ['<', TESTDIR . '/data/' .$test->{cciss_proc} ],
			'smartctl' => ['<', TESTDIR . '/data/' .$test->{smartctl} ],
		},
		no_smartctl => 1,
	);
	ok($plugin, "plugin created");

	$plugin->check;
	ok(1, "check ran");

	ok(defined($plugin->status), "status code set");
	is($plugin->status, $test->{status}, "status code matches");
	is($plugin->message, $test->{message}, "status message");

	my $c = $plugin->parse;
	my $df = TESTDIR . '/dump/cciss/' . $test->{c};
	if (!-f $df) {
		use Data::Dumper;
		print Dumper $c;
		die "Printed Dump for $df";
	}
	my $dump = read_dump($df);
	is_deeply($c, $dump, "controller structure");
}
