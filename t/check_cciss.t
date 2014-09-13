#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use constant TESTS => 6;
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
		message => '/dev/sda: (Smart Array P410i) RAID 1 Volume 0: OK',
		c => {
			'/dev/sda' => {
				'controller' => 'Smart Array P410i',
				'volume' => 'RAID 1 Volume 0',
				'status' => 'OK',
			},
		},
	},
	{
		status => OK,
		detect_hpsa => 'no-such-file',
		detect_cciss => 'cciss',
		version => 'cciss-1.09',
		controller => 'cciss_vol_status.argos',
		cciss_proc => 'cciss/$controller',
		smartctl => 'smartctl.cciss.$disk',
		message => '/dev/cciss/c0d0: (Smart Array P400i) RAID 6 Volume 0: OK',
		c => {
			'/dev/cciss/c0d0' => {
				'controller' => 'Smart Array P400i',
				'volume' => 'RAID 6 Volume 0',
				'status' => 'OK',
			},
		},
	},
	{
		status => OK,
		detect_hpsa => 'no-such-file',
		detect_cciss => 'cciss',
		version => 'cciss-1.11',
		controller => 'cciss_vol_status.cache-status',
		cciss_proc => 'cciss/$controller',
		smartctl => '',
		message => '/dev/cciss/c0d0: (Smart Array P400i) RAID 1 Volume 0: OK, Drives: 3NP3K2JG00009921RS5B,3NP3K40K00009920MTFH=OK, Cache: WriteCache ReadMem:104 MiB WriteMem:104 MiB',
		c => {
			'/dev/cciss/c0d0' => {
				'controller' => 'Smart Array P400i',
				'volume' => 'RAID 1 Volume 0',
				'status' => 'OK',
				'pd count' => '2',

				'pd 1' => {
					'bay' => 1,
					'conn2' => 'I',
					'status' => 'OK',
					'serial' => '3NP3K2JG00009921RS5B',
					'model' => 'HP      DG072BB975',
					'fw' => 'HPDC',
					'conn1' => '1',
					'box' => 1,
				},

				'pd 2' => {
					'bay' => 2,
					'conn2' => 'I',
					'status' => 'OK',
					'serial' => '3NP3K40K00009920MTFH',
					'model' => 'HP      DG072BB975',
					'fw' => 'HPDC',
					'conn1' => '1',
					'box' => 1
				},

				'cache' => {
					'configured' => 'Yes',
					'file' => '/dev/cciss/c0d0',
					'write_cache_enabled' => 'Yes',
					'write_cache_memory' => '104 MiB',
					'board' => 'Smart Array P400i',
					'read_cache_memory' => '104 MiB',
					'instance' => 0
				},
			}
		},
	},
	{
		status => OK,
		detect_hpsa => 'no-such-file',
		detect_cciss => 'cciss',
		version => 'cciss-1.11',
		controller => 'cciss_vol_status.cache-status.bruno',
		cciss_proc => 'cciss/$controller',
		smartctl => '',
		message => '/dev/sda: (Smart Array P410i) RAID 1 Volume 0: OK, Drives: 6XN06HGP0000B147NV0K,6XN07A4L0000S147YQP7=OK, Cache: WriteCache FlashCache ReadMem:100 MiB WriteMem:300 MiB',
		c => {
			'/dev/sda' => {
				'pd count' => 2,
				'controller' => 'Smart Array P410i',
				'volume' => 'RAID 1 Volume 0',
				'status' => 'OK',

				'pd 1' => {
					'bay' => 1,
					'conn2' => 'I',
					'status' => 'OK',
					'serial' => '6XN06HGP0000B147NV0K',
					'model' => 'HP      EH0300FBQDD',
					'fw' => 'HPD1',
					'conn1' => '1',
					'box' => 1,
				},

				'pd 2' => {
					'bay' => 2,
					'conn2' => 'I',
					'status' => 'OK',
					'serial' => '6XN07A4L0000S147YQP7',
					'model' => 'HP      EH0300FBQDD',
					'fw' => 'HPD1',
					'conn1' => '1',
					'box' => 1,
				},

				'cache' => {
					'configured' => 'Yes',
					'file' => '/dev/sg0',
					'write_cache_enabled' => 'Yes',
					'write_cache_memory' => '300 MiB',
					'board' => 'Smart Array P410i',
					'read_cache_memory' => '100 MiB',
					'instance' => 0,
					'flash_cache' => 1,
				},
			},
		},
	},
	{
		status => CRITICAL,
		detect_hpsa => 'no-such-file',
		detect_cciss => 'cciss',
		version => 'cciss-1.11',
		controller => 'cciss_vol_status.argos2',
		cciss_proc => 'cciss/$controller',
		smartctl => 'smartctl.cciss.$disk',
		message => '/dev/cciss/c0d0: (Smart Array P400i) RAID 6 Volume 0: OK, Drives: 3NP3BQ2700009910VW93,3NP3BQFM00009910VVWG,3NP3FVRE00009917SQV1,3NP3FVL400009917THQT=OK, Cache: WriteCache:DISABLED ReadMem:104 MiB WriteMem:104 MiB',
		c => {
			'/dev/cciss/c0d0' => {
				'controller' => 'Smart Array P400i',
				'volume' => 'RAID 6 Volume 0',
				'status' => 'OK',
				'pd count' => 4,

				'pd 1' => {
					'bay' => 1,
					'conn2' => 'I',
					'status' => 'OK',
					'serial' => '3NP3BQ2700009910VW93',
					'model' => 'HP      DG072BB975',
					'fw' => 'HPDC',
					'conn1' => '1',
					'box' => 1,
				},
				'pd 2' => {
					'bay' => 2,
					'conn2' => 'I',
					'status' => 'OK',
					'serial' => '3NP3BQFM00009910VVWG',
					'model' => 'HP      DG072BB975',
					'fw' => 'HPDC',
					'conn1' => '1',
					'box' => 1,
				},
				'pd 3' => {
					'bay' => 3,
					'conn2' => 'I',
					'status' => 'OK',
					'serial' => '3NP3FVRE00009917SQV1',
					'model' => 'HP      DG072BB975',
					'fw' => 'HPDC',
					'conn1' => '1',
					'box' => 1,
				},
				'pd 4' => {
					'bay' => 4,
					'conn2' => 'I',
					'status' => 'OK',
					'serial' => '3NP3FVL400009917THQT',
					'model' => 'HP      DG072BB975',
					'fw' => 'HPDC',
					'conn1' => '1',
					'box' => 1,
				},

				'cache' => {
					'disabled_temporarily' => 1,
					'disabled_temporarily diagnostic' => 'Temporary disable condition. Posted write operations have been disabled due to the fact that less than 75% of the battery packs are at the sufficient voltage level.',
					'configured' => 'Yes',
					'file' => '/dev/cciss/c0d0',
					'write_cache_enabled' => 'No',
					'write_cache_memory' => '104 MiB',
					'board' => 'Smart Array P400i',
					'read_cache_memory' => '104 MiB',
					'instance' => 0,
				},
			}
		},
	},
	{
		status => CRITICAL,
		detect_hpsa => 'no-such-file',
		detect_cciss => 'cciss',
		version => 'cciss-1.09',
		controller => 'cciss_vol_status.c1',
		cciss_proc => 'cciss/$controller',
		smartctl => '',
		message => '/dev/cciss/c0d0: (Smart Array P400) RAID 1 Volume 0: OK, /dev/cciss/c1d0: (Smart Array P800) Enclosure MSA70 (S/N: SGA6510007) on Bus 3, Physical Port 1E: Temperature problem',
		c => {
			'/dev/cciss/c0d0' => {
				'controller' => 'Smart Array P400',
				'volume' => 'RAID 1 Volume 0',
				'status' => 'OK',
			},
			'/dev/cciss/c1d0' => {
				'controller' => 'Smart Array P800) Enclosure MSA70 (S/N: SGA6510007',
				'volume' => 'on Bus 3, Physical Port 1E',
				'status' => 'Temperature problem',
			},
		},
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
	if (!$test->{c}) {
		use Data::Dumper;
		die Dumper $c;
	}
	is_deeply($c, $test->{c}, "controller structure");
}
