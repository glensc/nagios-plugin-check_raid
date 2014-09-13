#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use constant TESTS => 7;
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
				'board_name' => 'Smart Array P410i',
				'volume_number' => 0,
				'raid_level' => 'RAID 1',
				'certain' => 1,
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
				'board_name' => 'Smart Array P400i',
				'raid_level' => 'RAID 6',
				'volume_number' => 0,
				'certain' => 1,
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
		message => '/dev/cciss/c0d0: (Smart Array P400i) RAID 1 Volume 0: OK, Drives(2): 1I-1-1,1I-1-2=OK, Cache: WriteCache ReadMem:104 MiB WriteMem:104 MiB',
		c => {
			'/dev/cciss/c0d0' => {
				'board_name' => 'Smart Array P400i',
				'volume_number' => 0,
				'raid_level' => 'RAID 1',
				'certain' => 1,
				'status' => 'OK',
				'pd count' => '2',

			'drives' => {
				'1I-1-1' => {
					'slot' => '1I-1-1',
					'bay' => 1,
					'phys1' => '1',
					'phys2' => 'I',
					'status' => 'OK',
					'serial' => '3NP3K2JG00009921RS5B',
					'model' => 'HP      DG072BB975',
					'fw' => 'HPDC',
					'box' => 1,
				},

				'1I-1-2' => {
					'slot' => '1I-1-2',
					'bay' => 2,
					'phys1' => '1',
					'phys2' => 'I',
					'status' => 'OK',
					'serial' => '3NP3K40K00009920MTFH',
					'model' => 'HP      DG072BB975',
					'fw' => 'HPDC',
					'box' => 1
				},
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
		message => '/dev/sda: (Smart Array P410i) RAID 1 Volume 0: OK, Drives(2): 1I-1-1,1I-1-2=OK, Cache: WriteCache FlashCache ReadMem:100 MiB WriteMem:300 MiB',
		c => {
			'/dev/sda' => {
				'board_name' => 'Smart Array P410i',
				'volume_number' => 0,
				'raid_level' => 'RAID 1',
				'certain' => 1,
				'status' => 'OK',
				'pd count' => 2,

			'drives' => {
				'1I-1-1' => {
					'slot' => '1I-1-1',
					'bay' => 1,
					'phys1' => '1',
					'phys2' => 'I',
					'status' => 'OK',
					'serial' => '6XN06HGP0000B147NV0K',
					'model' => 'HP      EH0300FBQDD',
					'fw' => 'HPD1',
					'box' => 1,
				},

				'1I-1-2' => {
					'slot' => '1I-1-2',
					'bay' => 2,
					'phys1' => '1',
					'phys2' => 'I',
					'status' => 'OK',
					'serial' => '6XN07A4L0000S147YQP7',
					'model' => 'HP      EH0300FBQDD',
					'fw' => 'HPD1',
					'box' => 1,
				},
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
		message => '/dev/cciss/c0d0: (Smart Array P400i) RAID 6 Volume 0: OK, Drives(4): 1I-1-1,1I-1-3,1I-1-2,1I-1-4=OK, Cache: WriteCache:DISABLED ReadMem:104 MiB WriteMem:104 MiB',

		c => {
			'/dev/cciss/c0d0' => {
				'board_name' => 'Smart Array P400i',
				'volume_number' => 0,
				'raid_level' => 'RAID 6',
				'certain' => 1,
				'status' => 'OK',
				'pd count' => 4,

			'drives' => {
				'1I-1-1' => {
					'slot' => '1I-1-1',
					'bay' => 1,
					'phys1' => '1',
					'phys2' => 'I',
					'status' => 'OK',
					'serial' => '3NP3BQ2700009910VW93',
					'model' => 'HP      DG072BB975',
					'fw' => 'HPDC',
					'box' => 1,
				},
				'1I-1-2' => {
					'slot' => '1I-1-2',
					'bay' => 2,
					'phys1' => '1',
					'phys2' => 'I',
					'status' => 'OK',
					'serial' => '3NP3BQFM00009910VVWG',
					'model' => 'HP      DG072BB975',
					'fw' => 'HPDC',
					'box' => 1,
				},
				'1I-1-3' => {
					'slot' => '1I-1-3',
					'bay' => 3,
					'phys1' => '1',
					'phys2' => 'I',
					'status' => 'OK',
					'serial' => '3NP3FVRE00009917SQV1',
					'model' => 'HP      DG072BB975',
					'fw' => 'HPDC',
					'box' => 1,
				},
				'1I-1-4' => {
					'slot' => '1I-1-4',
					'bay' => 4,
					'phys1' => '1',
					'phys2' => 'I',
					'status' => 'OK',
					'serial' => '3NP3FVL400009917THQT',
					'model' => 'HP      DG072BB975',
					'fw' => 'HPDC',
					'box' => 1,
				},
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
		message => '/dev/cciss/c0d0: (Smart Array P400) RAID 1 Volume 0: OK, /dev/cciss/c1d0: (Smart Array P800) RAID 1 Volume 0: OK, Enclosures: MSA70(SGA6510007): Temperature problem, MSA70(SGA651004J): OK',
		c => {
			'/dev/cciss/c0d0' => {
				'board_name' => 'Smart Array P400',
				'volume_number' => 0,
				'raid_level' => 'RAID 1',
				'certain' => 1,
				'status' => 'OK',
			},

			'/dev/cciss/c1d0' => {
				'board_name' => 'Smart Array P800',
				'volume_number' => 0,
				'raid_level' => 'RAID 1',
				'certain' => 1,
				'status' => 'OK',

				'enclosures' => {
					'2' => {
						'bus' => 2,
						'status' => 'OK',
						'phys1' => '1',
						'phys2' => 'E',
						'sn' => 'SGA651004J',
						'name' => 'MSA70',
						'board_name' => 'Smart Array P800'
					},
					'3' => {
						'bus' => 3,
						'status' => 'Temperature problem',
						'phys1' => '1',
						'phys2' => 'E',
						'sn' => 'SGA6510007',
						'name' => 'MSA70',
						'board_name' => 'Smart Array P800'
					},
				},
			},
		},
	},
	{
		status => OK,
		detect_hpsa => 'no-such-file',
		detect_cciss => 'cciss',
		version => 'cciss-1.11',
		controller => 'cciss_vol_status.cetus',
		cciss_proc => 'cciss/$controller',
		smartctl => 'smartctl.cciss.$disk',
		message => '/dev/cciss/c0d0: (Smart Array P400) RAID 1 Volume 0: OK, Drives(2): 2I-1-1,2I-1-2=OK, Cache: WriteCache ReadMem:52 MiB WriteMem:156 MiB, /dev/cciss/c1d0: (Smart Array P800) RAID 1 Volume 0: OK, Drives(50): 1E-1-20,1E-1-16,1E-1-10,1E-1-4,1E-2-25,1E-2-4,1E-1-11,1E-2-7,1E-1-19,1E-1-21,1E-1-17,1E-1-9,1E-1-14,1E-2-22,1E-1-25,1E-1-5,1E-2-11,1E-2-17,1E-2-5,1E-2-18,1E-2-12,1E-2-1,1E-1-23,1E-1-18,1E-2-3,1E-1-3,1E-1-2,1E-2-8,1E-2-15,1E-2-6,1E-2-21,1E-2-13,1E-2-14,1E-2-9,1E-1-22,1E-2-2,1E-1-8,1E-2-19,1E-2-24,1E-1-7,1E-1-12,1E-1-6,1E-1-15,1E-1-24,1E-2-16,1E-2-20,1E-1-13,1E-1-1,1E-2-23,1E-2-10=OK, Enclosures: MSA70(SGA6510007): OK, MSA70(SGA651004J): OK, Cache: WriteCache ReadMem:114 MiB WriteMem:342 MiB',
		c => {
			'/dev/cciss/c0d0' => {
				'board_name' => 'Smart Array P400',
				'volume_number' => 0,
				'raid_level' => 'RAID 1',
				'certain' => 1,
				'status' => 'OK',
				'pd count' => 2,

			'drives' => {
				'2I-1-2' => {
					'slot' => '2I-1-2',
					'bay' => 2,
					'phys1' => '2',
					'phys2' => 'I',
					'status' => 'OK',
					'serial' => '3LB16JEV0000971881Q9',
					'model' => 'HP      DG072A8B54',
					'fw' => 'HPD7',
					'box' => 1,
				},

				'2I-1-1' => {
					'slot' => '2I-1-1',
					'bay' => 1,
					'phys1' => '2',
					'phys2' => 'I',
					'status' => 'OK',
					'serial' => '3LB1667000009717XQ6Q',
					'model' => 'HP      DG072A8B54',
					'fw' => 'HPD7',
					'box' => 1,
				},
			},

				'cache' => {
					'configured' => 'Yes',
					'file' => '/dev/cciss/c0d0',
					'write_cache_enabled' => 'Yes',
					'write_cache_memory' => '156 MiB',
					'board' => 'Smart Array P400',
					'read_cache_memory' => '52 MiB',
					'instance' => 0,
				}
			},

			'/dev/cciss/c1d0' => {
				'board_name' => 'Smart Array P800',
				'volume_number' => 0,
				'raid_level' => 'RAID 1',
				'certain' => 1,
				'status' => 'OK',
				'pd count' => 50,

				'drives' => {
					'1E-1-20' => {
						'slot' => '1E-1-20',
						'bay' => 20,
						'status' => 'OK',
						'serial' => 'B365P710D7F30704',
						'phys1' => '1',
						'model' => 'HP      DG072A9BB7',
						'phys2' => 'E',
						'fw' => 'HPD0',
						'box' => 1
					},
					'1E-1-16' => {
						'slot' => '1E-1-16',
						'bay' => 16,
						'status' => 'OK',
						'serial' => 'B365P710D6YB0704',
						'phys1' => '1',
						'model' => 'HP      DG072A9BB7',
						'phys2' => 'E',
						'fw' => 'HPD0',
						'box' => 1
					},
					'1E-1-10' => {
						'slot' => '1E-1-10',
						'bay' => 10,
						'status' => 'OK',
						'serial' => '3LB1DDBP00009725HP9H',
						'phys1' => '1',
						'model' => 'HP      DG072A8B54',
						'phys2' => 'E',
						'fw' => 'HPD7',
						'box' => 1
					},
					'1E-1-4' => {
						'slot' => '1E-1-4',
						'bay' => 4,
						'status' => 'OK',
						'serial' => '3LB1DCNV000097240T05',
						'phys1' => '1',
						'model' => 'HP      DG072A8B54',
						'phys2' => 'E',
						'fw' => 'HPD7',
						'box' => 1
					},
					'1E-2-25' => {
						'slot' => '1E-2-25',
						'bay' => 25,
						'status' => 'OK',
						'serial' => '3LB1D5TM00009724ZFM6',
						'phys1' => '1',
						'model' => 'HP      DG072A8B54',
						'phys2' => 'E',
						'fw' => 'HPD7',
						'box' => 2
					},
					'1E-2-4' => {
						'slot' => '1E-2-4',
						'bay' => 4,
						'status' => 'OK',
						'serial' => '3LB1D5HH00009724HCBF',
						'phys1' => '1',
						'model' => 'HP      DG072A8B54',
						'phys2' => 'E',
						'fw' => 'HPD7',
						'box' => 2
					},
					'1E-1-11' => {
						'slot' => '1E-1-11',
						'bay' => 11,
						'status' => 'OK',
						'serial' => 'B365P720EDCL0706',
						'phys1' => '1',
						'model' => 'HP      DG072A9BB7',
						'phys2' => 'E',
						'fw' => 'HPD0',
						'box' => 1
					},
					'1E-2-7' => {
						'slot' => '1E-2-7',
						'bay' => 7,
						'status' => 'OK',
						'serial' => 'B365P720EBRF0706',
						'phys1' => '1',
						'model' => 'HP      DG072A9BB7',
						'phys2' => 'E',
						'fw' => 'HPD0',
						'box' => 2
					},
					'1E-1-19' => {
						'slot' => '1E-1-19',
						'bay' => 19,
						'status' => 'OK',
						'serial' => 'B365P710CMLE0703',
						'phys1' => '1',
						'model' => 'HP      DG072A9BB7',
						'phys2' => 'E',
						'fw' => 'HPD0',
						'box' => 1
					},
					'1E-1-21' => {
						'slot' => '1E-1-21',
						'bay' => 21,
						'status' => 'OK',
						'serial' => 'B365P710D71N0704',
						'phys1' => '1',
						'model' => 'HP      DG072A9BB7',
						'phys2' => 'E',
						'fw' => 'HPD0',
						'box' => 1
					},
					'1E-1-17' => {
						'slot' => '1E-1-17',
						'bay' => 17,
						'status' => 'OK',
						'serial' => 'B365P710CJ5Y0703',
						'phys1' => '1',
						'model' => 'HP      DG072A9BB7',
						'phys2' => 'E',
						'fw' => 'HPD0',
						'box' => 1
					},
					'1E-1-9' => {
						'slot' => '1E-1-9',
						'bay' => 9,
						'status' => 'OK',
						'serial' => 'B365P710CMLH0703',
						'phys1' => '1',
						'model' => 'HP      DG072A9BB7',
						'phys2' => 'E',
						'fw' => 'HPD0',
						'box' => 1
					},
					'1E-1-14' => {
						'slot' => '1E-1-14',
						'bay' => 14,
						'status' => 'OK',
						'serial' => '3NP3NJBW00009936L3AW',
						'phys1' => '1',
						'model' => 'HP      DG072BB975',
						'phys2' => 'E',
						'fw' => 'HPDE',
						'box' => 1
					},
					'1E-2-22' => {
						'slot' => '1E-2-22',
						'bay' => 22,
						'status' => 'OK',
						'serial' => 'B365P6C09UP00649',
						'phys1' => '1',
						'model' => 'HP      DG072A9BB7',
						'phys2' => 'E',
						'fw' => 'HPD0',
						'box' => 2
					},
					'1E-1-25' => {
						'slot' => '1E-1-25',
						'bay' => 25,
						'status' => 'OK',
						'serial' => 'B365P6C09MPW0649',
						'phys1' => '1',
						'model' => 'HP      DG072A9BB7',
						'phys2' => 'E',
						'fw' => 'HPD0',
						'box' => 1
					},
					'1E-1-5' => {
						'slot' => '1E-1-5',
						'bay' => 5,
						'status' => 'OK',
						'serial' => 'B365P720ED0H0706',
						'phys1' => '1',
						'model' => 'HP      DG072A9BB7',
						'phys2' => 'E',
						'fw' => 'HPD0',
						'box' => 1
					},
					'1E-2-11' => {
						'slot' => '1E-2-11',
						'bay' => 11,
						'status' => 'OK',
						'serial' => 'B365P720EC500706',
						'phys1' => '1',
						'model' => 'HP      DG072A9BB7',
						'phys2' => 'E',
						'fw' => 'HPD0',
						'box' => 2
					},
					'1E-2-17' => {
						'slot' => '1E-2-17',
						'bay' => 17,
						'status' => 'OK',
						'serial' => '3LB1D0VA00009725KECN',
						'phys1' => '1',
						'model' => 'HP      DG072A8B54',
						'phys2' => 'E',
						'fw' => 'HPD7',
						'box' => 2
					},
					'1E-2-5' => {
						'slot' => '1E-2-5',
						'bay' => 5,
						'status' => 'OK',
						'serial' => '3LB1D9JF00009725KFQU',
						'phys1' => '1',
						'model' => 'HP      DG072A8B54',
						'phys2' => 'E',
						'fw' => 'HPD7',
						'box' => 2
					},
					'1E-2-18' => {
						'slot' => '1E-2-18',
						'bay' => 18,
						'status' => 'OK',
						'serial' => 'B365P720EE980706',
						'phys1' => '1',
						'model' => 'HP      DG072A9BB7',
						'phys2' => 'E',
						'fw' => 'HPD0',
						'box' => 2
					},
					'1E-2-12' => {
						'slot' => '1E-2-12',
						'bay' => 12,
						'status' => 'OK',
						'serial' => '3LB1DC2Z00009725357U',
						'phys1' => '1',
						'model' => 'HP      DG072A8B54',
						'phys2' => 'E',
						'fw' => 'HPD7',
						'box' => 2
					},
					'1E-2-1' => {
						'slot' => '1E-2-1',
						'bay' => 1,
						'status' => 'OK',
						'serial' => 'B365P710D6RR0704',
						'phys1' => '1',
						'model' => 'HP      DG072A9BB7',
						'phys2' => 'E',
						'fw' => 'HPD0',
						'box' => 2,
					},
					'1E-1-23' => {
						'slot' => '1E-1-23',
						'bay' => 23,
						'status' => 'OK',
						'serial' => 'B365P710CJ8M0703',
						'phys1' => '1',
						'model' => 'HP      DG072A9BB7',
						'phys2' => 'E',
						'fw' => 'HPD0',
						'box' => 1
					},
					'1E-1-18' => {
						'slot' => '1E-1-18',
						'bay' => 18,
						'status' => 'OK',
						'serial' => '3LB1D6JL000097251ZNL',
						'phys1' => '1',
						'model' => 'HP      DG072A8B54',
						'phys2' => 'E',
						'fw' => 'HPD7',
						'box' => 1
					},
					'1E-2-3' => {
						'slot' => '1E-2-3',
						'bay' => 3,
						'status' => 'OK',
						'serial' => '3LB1D48800009724Y7AZ',
						'phys1' => '1',
						'model' => 'HP      DG072A8B54',
						'phys2' => 'E',
						'fw' => 'HPD7',
						'box' => 2
					},
					'1E-1-3' => {
						'slot' => '1E-1-3',
						'bay' => 3,
						'status' => 'OK',
						'serial' => 'B365P720EE9K0706',
						'phys1' => '1',
						'model' => 'HP      DG072A9BB7',
						'phys2' => 'E',
						'fw' => 'HPD0',
						'box' => 1
					},
					'1E-1-2' => {
						'slot' => '1E-1-2',
						'bay' => 2,
						'status' => 'OK',
						'serial' => 'B365P720EAF70706',
						'phys1' => '1',
						'model' => 'HP      DG072A9BB7',
						'phys2' => 'E',
						'fw' => 'HPD0',
						'box' => 1
					},
					'1E-2-8' => {
						'slot' => '1E-2-8',
						'bay' => 8,
						'status' => 'OK',
						'serial' => 'B365P710CHH70703',
						'phys1' => '1',
						'model' => 'HP      DG072A9BB7',
						'phys2' => 'E',
						'fw' => 'HPD0',
						'box' => 2
					},
					'1E-2-15' => {
						'slot' => '1E-2-15',
						'bay' => 15,
						'status' => 'OK',
						'serial' => '3LB1DDW70000972532K1',
						'phys1' => '1',
						'model' => 'HP      DG072A8B54',
						'phys2' => 'E',
						'fw' => 'HPD7',
						'box' => 2
					},
					'1E-2-6' => {
						'slot' => '1E-2-6',
						'bay' => 6,
						'status' => 'OK',
						'serial' => 'B365P710CMTU0703',
						'phys1' => '1',
						'model' => 'HP      DG072A9BB7',
						'phys2' => 'E',
						'fw' => 'HPD0',
						'box' => 2
					},
					'1E-2-21' => {
						'slot' => '1E-2-21',
						'bay' => 21,
						'status' => 'OK',
						'serial' => '3LB1D4AW000097251ZP4',
						'phys1' => '1',
						'model' => 'HP      DG072A8B54',
						'phys2' => 'E',
						'fw' => 'HPD7',
						'box' => 2
					},
					'1E-2-13' => {
						'slot' => '1E-2-13',
						'bay' => 13,
						'status' => 'OK',
						'serial' => '3LB1D9Z4000097252BF5',
						'phys1' => '1',
						'model' => 'HP      DG072A8B54',
						'phys2' => 'E',
						'fw' => 'HPD7',
						'box' => 2
					},
					'1E-2-14' => {
						'slot' => '1E-2-14',
						'bay' => 14,
						'status' => 'OK',
						'serial' => 'B365P720EDTJ0706',
						'phys1' => '1',
						'model' => 'HP      DG072A9BB7',
						'phys2' => 'E',
						'fw' => 'HPD0',
						'box' => 2
					},
					'1E-2-9' => {
						'slot' => '1E-2-9',
						'bay' => 9,
						'status' => 'OK',
						'serial' => 'B365P720EE8K0706',
						'phys1' => '1',
						'model' => 'HP      DG072A9BB7',
						'phys2' => 'E',
						'fw' => 'HPD0',
						'box' => 2
					},
					'1E-1-22' => {
						'slot' => '1E-1-22',
						'bay' => 22,
						'status' => 'OK',
						'serial' => 'B365P710CJ8R0703',
						'phys1' => '1',
						'model' => 'HP      DG072A9BB7',
						'phys2' => 'E',
						'fw' => 'HPD0',
						'box' => 1
					},
					'1E-2-2' => {
						'slot' => '1E-2-2',
						'bay' => 2,
						'status' => 'OK',
						'serial' => 'B365P720EDJG0706',
						'phys1' => '1',
						'model' => 'HP      DG072A9BB7',
						'phys2' => 'E',
						'fw' => 'HPD0',
						'box' => 2
					},
					'1E-1-8' => {
						'slot' => '1E-1-8',
						'bay' => 8,
						'status' => 'OK',
						'serial' => 'B365P720EE4R0706',
						'phys1' => '1',
						'model' => 'HP      DG072A9BB7',
						'phys2' => 'E',
						'fw' => 'HPD0',
						'box' => 1
					},
					'1E-2-19' => {
						'slot' => '1E-2-19',
						'bay' => 19,
						'status' => 'OK',
						'serial' => '3LB1DDQ6000097240TNM',
						'phys1' => '1',
						'model' => 'HP      DG072A8B54',
						'phys2' => 'E',
						'fw' => 'HPD7',
						'box' => 2
					},
					'1E-2-24' => {
						'slot' => '1E-2-24',
						'bay' => 24,
						'status' => 'OK',
						'serial' => 'B365P6C09U0H0649',
						'phys1' => '1',
						'model' => 'HP      DG072A9BB7',
						'phys2' => 'E',
						'fw' => 'HPD0',
						'box' => 2
					},
					'1E-1-7' => {
						'slot' => '1E-1-7',
						'bay' => 7,
						'status' => 'OK',
						'serial' => 'B365P720EE060706',
						'phys1' => '1',
						'model' => 'HP      DG072A9BB7',
						'phys2' => 'E',
						'fw' => 'HPD0',
						'box' => 1
					},
					'1E-1-12' => {
						'slot' => '1E-1-12',
						'bay' => 12,
						'status' => 'OK',
						'serial' => 'B365P710D71K0704',
						'phys1' => '1',
						'model' => 'HP      DG072A9BB7',
						'phys2' => 'E',
						'fw' => 'HPD0',
						'box' => 1
					},
					'1E-1-6' => {
						'slot' => '1E-1-6',
						'bay' => 6,
						'status' => 'OK',
						'serial' => 'B365P720EDTU0706',
						'phys1' => '1',
						'model' => 'HP      DG072A9BB7',
						'phys2' => 'E',
						'fw' => 'HPD0',
						'box' => 1
					},
					'1E-1-15' => {
						'slot' => '1E-1-15',
						'bay' => 15,
						'status' => 'OK',
						'serial' => 'B365P720EE5R0706',
						'phys1' => '1',
						'model' => 'HP      DG072A9BB7',
						'phys2' => 'E',
						'fw' => 'HPD0',
						'box' => 1
					},
					'1E-1-24' => {
						'slot' => '1E-1-24',
						'bay' => 24,
						'status' => 'OK',
						'serial' => 'B365P710CHGE0703',
						'phys1' => '1',
						'model' => 'HP      DG072A9BB7',
						'phys2' => 'E',
						'fw' => 'HPD0',
						'box' => 1
					},
					'1E-2-16' => {
						'slot' => '1E-2-16',
						'bay' => 16,
						'status' => 'OK',
						'serial' => 'B365P6C09UND0649',
						'phys1' => '1',
						'model' => 'HP      DG072A9BB7',
						'phys2' => 'E',
						'fw' => 'HPD0',
						'box' => 2
					},
					'1E-2-20' => {
						'slot' => '1E-2-20',
						'bay' => 20,
						'status' => 'OK',
						'serial' => '3LB1D0BZ00009724GNHB',
						'phys1' => '1',
						'model' => 'HP      DG072A8B54',
						'phys2' => 'E',
						'fw' => 'HPD7',
						'box' => 2,
					},
					'1E-1-13' => {
						'slot' => '1E-1-13',
						'bay' => 13,
						'status' => 'OK',
						'serial' => '6SD10M9A0000B1063CMB',
						'phys1' => '1',
						'model' => 'HP      EG0146FAWHU',
						'phys2' => 'E',
						'fw' => 'HPDE',
						'box' => 1
					},
					'1E-1-1' => {
						'slot' => '1E-1-1',
						'bay' => 1,
						'status' => 'OK',
						'serial' => 'B365P720EE8W0706',
						'phys1' => '1',
						'model' => 'HP      DG072A9BB7',
						'phys2' => 'E',
						'fw' => 'HPD0',
						'box' => 1
					},
					'1E-2-23' => {
						'slot' => '1E-2-23',
						'bay' => 23,
						'status' => 'OK',
						'serial' => 'B365P6C09WVM0649',
						'phys1' => '1',
						'model' => 'HP      DG072A9BB7',
						'phys2' => 'E',
						'fw' => 'HPD0',
						'box' => 2
					},
					'1E-2-10' => {
						'slot' => '1E-2-10',
						'bay' => 10,
						'status' => 'OK',
						'serial' => 'B365P720EE510706',
						'phys1' => '1',
						'model' => 'HP      DG072A9BB7',
						'phys2' => 'E',
						'fw' => 'HPD0',
						'box' => 2
					},
				},

				'enclosures' => {
					'3' => {
						'bus' => 3,
						'status' => 'OK',
						'phys1' => '1',
						'sn' => 'SGA6510007',
						'name' => 'MSA70',
						'phys2' => 'E',
						'board_name' => 'Smart Array P800',
					},
					'2' => {
						'bus' => 2,
						'status' => 'OK',
						'phys1' => '1',
						'sn' => 'SGA651004J',
						'name' => 'MSA70',
						'phys2' => 'E',
						'board_name' => 'Smart Array P800',
					},
				},

				'cache' => {
					'configured' => 'Yes',
					'file' => '/dev/cciss/c1d0',
					'write_cache_enabled' => 'Yes',
					'write_cache_memory' => '342 MiB',
					'board' => 'Smart Array P800',
					'read_cache_memory' => '114 MiB',
					'instance' => 0,
				}
			}
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
		print Dumper $c;
		die;
	}
	is_deeply($c, $test->{c}, "controller structure");
}
