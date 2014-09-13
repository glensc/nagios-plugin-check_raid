#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use constant TESTS => 6;
use Test::More tests => TESTS * 6;
use test;

my @tests = (
	{
		status => OK,
		info => '1/info',
		unitstatus => '1/info.c.unitstatus',
		drivestatus => '1/info.c.drivestatus',
		message => 'c0(9650SE-16ML): u0(RAID-6): OK, Drives(16): p0,p1,p10,p11,p13,p14,p15,p2,p3,p4,p5,p6,p7,p8,p9=OK p12=SPARE, BBU: OK',
		c => {
			'c0' => {
				'model' => '9650SE-16ML',
				'ports' => 16,
				'drives' => 16,
				'units' => 1,
				'optimal' => 1,
				'rrate' => 5,
				'vrate' => 1,
				'bbu' => 'OK',

				'unitstatus' => {
					'u0' => {
						'status' => 'OK',
						'size' => '12107.1',
						'rebuild_percent' => '-',
						'strip' => '64K',
						'type' => 'RAID-6',
						'vim_percent' => '-',
						'avrify' => 'OFF',
						'cache' => 'ON'
					}
				},

				'drivestatus' => {
					'p5' => {
						'unit' => 'u0',
						'blocks' => 1953525168,
						'serial' => 'S13PJ1NQC03011',
						'status' => 'OK',
						'size' => '931.51 GB'
					},
					'p7' => {
						'unit' => 'u0',
						'blocks' => 1953525168,
						'serial' => 'S13PJ1NQC03017',
						'status' => 'OK',
						'size' => '931.51 GB'
					},
					'p0' => {
						'unit' => 'u0',
						'blocks' => 1953525168,
						'serial' => 'S246JDWZ134931',
						'status' => 'OK',
						'size' => '931.51 GB'
					},
					'p11' => {
						'unit' => 'u0',
						'blocks' => 1953525168,
						'serial' => 'S13PJ1NQC03014',
						'status' => 'OK',
						'size' => '931.51 GB'
					},
					'p10' => {
						'unit' => 'u0',
						'blocks' => 1953525168,
						'serial' => 'S246JDWZ134930',
						'status' => 'OK',
						'size' => '931.51 GB'
					},
					'p13' => {
						'unit' => 'u0',
						'blocks' => 1953525168,
						'serial' => 'S13PJ1NQC03018',
						'status' => 'OK',
						'size' => '931.51 GB'
					},
					'p14' => {
						'unit' => 'u0',
						'blocks' => 1953525168,
						'serial' => 'S13PJ1NQC03021',
						'status' => 'OK',
						'size' => '931.51 GB'
					},
					'p6' => {
						'unit' => 'u0',
						'blocks' => 1953525168,
						'serial' => 'S13PJ1NQC03012',
						'status' => 'OK',
						'size' => '931.51 GB'
					},
					'p1' => {
						'unit' => 'u0',
						'blocks' => 1953525168,
						'serial' => 'S246JDWZ134929',
						'status' => 'OK',
						'size' => '931.51 GB'
					},
					'p4' => {
						'unit' => 'u0',
						'blocks' => 1953525168,
						'serial' => 'S246JDWZ134927',
						'status' => 'OK',
						'size' => '931.51 GB'
					},
					'p2' => {
						'unit' => 'u0',
						'blocks' => 1953525168,
						'serial' => 'S246JDWZ134928',
						'status' => 'OK',
						'size' => '931.51 GB'
					},
					'p8' => {
						'unit' => 'u0',
						'blocks' => 1953525168,
						'serial' => '9QJ16BC3',
						'status' => 'OK',
						'size' => '931.51 GB'
					},
					'p15' => {
						'unit' => 'u0',
						'blocks' => 1953525168,
						'serial' => 'S13PJ1NQC03019',
						'status' => 'OK',
						'size' => '931.51 GB'
					},
					'p3' => {
						'unit' => 'u0',
						'blocks' => 1953525168,
						'serial' => 'S246JDWZ134932',
						'status' => 'OK',
						'size' => '931.51 GB'
					},
					'p12' => {
						'unit' => '-',
						'blocks' => 1953525168,
						'serial' => '9QJ2NWT2',
						'status' => 'OK',
						'size' => '931.51 GB'
					},
					'p9' => {
						'unit' => 'u0',
						'blocks' => 1953525168,
						'serial' => 'S13PJ1NQC03015',
						'status' => 'OK',
						'size' => '931.51 GB'
					},
				},
			},
		},
	},
	{
		status => RESYNC,
		info => '2/info',
		unitstatus => '2/info.c0.unitstatus',
		drivestatus => '2/info.c0.drivestatus',
		message => 'c0(9750-4i): u0(RAID-5): VERIFYING 16%, Drives(4): p0,p1,p2,p3=OK, BBU: OK',
		c => {
			'c0' => {
				'model' => '9750-4i',
				'ports' => 4,
				'drives' => 4,
				'units' => 1,
				'optimal' => 1,
				'rrate' => 1,
				'vrate' => 1,
				'bbu' => 'OK',

				'unitstatus' => {
					'u0' => {
						'status' => 'VERIFYING',
						'size' => '5587.9',
						'rebuild_percent' => '-',
						'strip' => '256K',
						'type' => 'RAID-5',
						'vim_percent' => '16%',
						'avrify' => 'ON',
						'cache' => 'RiW'
					}
				},
				'drivestatus' => {
					'p0' => {
						'unit' => 'u0',
						'phy' => 0,
						'status' => 'OK',
						'encl' => '-',
						'model' => 'SEAGATE ST32000444SS',
						'type' => 'SAS',
						'size' => '1.82 TB',
					},
					'p1' => {
						'unit' => 'u0',
						'phy' => 1,
						'status' => 'OK',
						'encl' => '-',
						'model' => 'SEAGATE ST32000444SS',
						'type' => 'SAS',
						'size' => '1.82 TB',
					},
					'p2' => {
						'unit' => 'u0',
						'phy' => 2,
						'status' => 'OK',
						'encl' => '-',
						'model' => 'SEAGATE ST32000444SS',
						'type' => 'SAS',
						'size' => '1.82 TB',
					},
					'p3' => {
						'unit' => 'u0',
						'phy' => 3,
						'status' => 'OK',
						'encl' => '-',
						'model' => 'SEAGATE ST32000444SS',
						'type' => 'SAS',
						'size' => '1.82 TB',
					},
				},
			},
		},
	},
	{
		status => CRITICAL,
		info => 'lumpy/info',
		unitstatus => 'lumpy/unitstatus',
		drivestatus => 'lumpy/drivestatus',
		message => 'c0(9650SE-2LP): u0(RAID-1): REBUILDING 98%, Drives(2): p0=DEGRADED p1=OK',
		c => {
			'c0' => {
				'model' => '9650SE-2LP',
				'ports' => 2,
				'drives' => 2,
				'units' => 1,
				'optimal' => 0,
				'rrate' => 1,
				'vrate' => 1,
				'bbu' => '-',

				'unitstatus' => {
					'u0' => {
						'status' => 'REBUILDING',
						'size' => '465.651',
						'rebuild_percent' => '98%',
						'strip' => '-',
						'type' => 'RAID-1',
						'vim_percent' => '-',
						'avrify' => 'OFF',
						'cache' => 'OFF',
					},
				},

				'drivestatus' => {
					'p1' => {
						'unit' => 'u0',
						'blocks' => 976773168,
						'serial' => '9QM1TQFZ',
						'status' => 'OK',
						'size' => '465.76 GB',
					},
					'p0' => {
						'unit' => 'u0',
						'blocks' => 976773168,
						'serial' => '9QM1SHZY',
						'status' => 'DEGRADED',
						'size' => '465.76 GB',
					},
				},
			},
		},
	},
	{
		status => OK,
		info => 'ichy/info',
		unitstatus => 'ichy/info.c0.unitstatus',
		drivestatus => 'ichy/info.c0.drivestatus',
		message => 'c0(9650SE-12ML): u0(RAID-5): OK, Drives(6): p0,p1,p2,p3,p4,p5=OK, BBU: OK',
		c => {
			'c0' => {
				'model' => '9650SE-12ML',
				'ports' => 12,
				'drives' => 6,
				'units' => 1,
				'optimal' => 1,
				'rrate' => 3,
				'vrate' => 3,
				'bbu' => 'OK',

				'unitstatus' => {
					'u0' => {
						'status' => 'OK',
						'size' => '4656.56',
						'rebuild_percent' => '-',
						'strip' => '64K',
						'type' => 'RAID-5',
						'vim_percent' => '-',
						'avrify' => 'OFF',
						'cache' => 'ON',
					},
				},

				'drivestatus' => {
					'p0' => {
						'unit' => 'u0',
						'blocks' => 1953525168,
						'serial' => '9QJ1X1YY',
						'status' => 'OK',
						'size' => '931.51 GB',
					},
					'p1' => {
						'unit' => 'u0',
						'blocks' => 1953525168,
						'serial' => '9QJ1WZ52',
						'status' => 'OK',
						'size' => '931.51 GB',
					},
					'p2' => {
						'unit' => 'u0',
						'blocks' => 1953525168,
						'serial' => '9QJ28HP8',
						'status' => 'OK',
						'size' => '931.51 GB',
					},
					'p3' => {
						'unit' => 'u0',
						'blocks' => 1953525168,
						'serial' => '9QJ285DT',
						'status' => 'OK',
						'size' => '931.51 GB',
					},
					'p4' => {
						'unit' => 'u0',
						'blocks' => 1953525168,
						'serial' => '9QJ2F26M',
						'status' => 'OK',
						'size' => '931.51 GB',
					},
					'p5' => {
						'unit' => 'u0',
						'blocks' => 1953525168,
						'serial' => '9QJ2A0TF',
						'status' => 'OK',
						'size' => '931.51 GB',
					},
				},
			},
		},
	},
	{
		status => OK,
		info => 'black/info',
		unitstatus => 'black/unitstatus',
		drivestatus => 'black/drivestatus',
		message => 'c0(8006-2LP): u0(RAID-1): OK, Drives(2): p0,p1=OK',
		c => {
			'c0' => {
				'model' => '8006-2LP',
				'ports' => 2,
				'drives' => 2,
				'units' => 1,
				'optimal' => 1,
				'rrate' => 2,
				'vrate' => '-',
				'bbu' => '-',

				'unitstatus' => {
					'u0' => {
						'status' => 'OK',
						'size' => '698.637',
						'rebuild_percent' => '-',
						'strip' => '-',
						'type' => 'RAID-1',
						'vim_percent' => '-',
						'avrify' => '-',
						'cache' => 'W',
					},
				},

				'drivestatus' => {
					'p0' => {
						'unit' => 'u0',
						'blocks' => 1953525168,
						'serial' => '9VPD4HXW',
						'status' => 'OK',
						'size' => '931.51 GB',
					},
					'p1' => {
						'unit' => 'u0',
						'blocks' => 1465149168,
						'serial' => '9QK13E0L',
						'status' => 'OK',
						'size' => '698.63 GB',
					},
				},
			},
		},
	},
	{
		status => OK,
		info => 'rover/info',
		unitstatus => 'rover/unitstatus',
		drivestatus => 'rover/drivestatus',
		message => 'c0(9500S-8): u0(RAID-5): OK, Drives(6): p0,p1,p2,p3,p4,p5=OK',
		c => {
			'c0' => {
				'model' => '9500S-8',
				'ports' => 8,
				'drives' => 6,
				'units' => 1,
				'optimal' => 1,
				'rrate' => 1,
				'vrate' => 1,
				'bbu' => undef,

				'unitstatus' => {
					'u0' => {
						'status' => 'OK',
						'size' => '1396.93',
						'rebuild_percent' => '-',
						'strip' => '64K',
						'type' => 'RAID-5',
						'vim_percent' => '-',
						'avrify' => 'OFF',
						'cache' => 'OFF'
					},
				},

				'drivestatus' => {
					'p0' => {
						'unit' => 'u0',
						'blocks' => 586072368,
						'serial' => '3NF07VGV',
						'status' => 'OK',
						'size' => '279.46 GB',
					},
					'p1' => {
						'unit' => 'u0',
						'blocks' => 586072368,
						'serial' => '3NF0DXAH',
						'status' => 'OK',
						'size' => '279.46 GB',
					},
					'p2' => {
						'unit' => 'u0',
						'blocks' => 586072368,
						'serial' => '3NF0A39B',
						'status' => 'OK',
						'size' => '279.46 GB',
					},
					'p3' => {
						'unit' => 'u0',
						'blocks' => 586072368,
						'serial' => '3NF0C1KJ',
						'status' => 'OK',
						'size' => '279.46 GB',
					},
					'p4' => {
						'unit' => 'u0',
						'blocks' => 586072368,
						'serial' => '3NF0D3JR',
						'status' => 'OK',
						'size' => '279.46 GB',
					},
					'p5' => {
						'unit' => 'u0',
						'blocks' => 625142448,
						'serial' => '6QF1JJY8',
						'status' => 'OK',
						'size' => '298.09 GB',
					},
				},
			}
		},
	},
);

foreach my $test (@tests) {
	my $plugin = tw_cli->new(
		commands => {
			'info' => ['<', TESTDIR . '/data/tw_cli/' .$test->{info} ],
			'unitstatus' => ['<', TESTDIR . '/data/tw_cli/' .$test->{unitstatus} ],
			'drivestatus' => ['<', TESTDIR . '/data/tw_cli/' .$test->{drivestatus} ],
		},
	);
	ok($plugin, "plugin created");

	$plugin->check;
	ok(1, "check ran");

	ok(defined($plugin->status), "status code set");
	is($plugin->status, $test->{status}, "status code matches");
	is($plugin->message, $test->{message}, "status message");

	my $c = $plugin->parse;
	is_deeply($c, $test->{c}, "controller structure");
}
