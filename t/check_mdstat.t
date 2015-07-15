#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use constant INACTIVE_TESTS => 2;
use constant ACTIVE_TESTS => 18;
use Test::More tests => ACTIVE_TESTS * 6 + INACTIVE_TESTS * 2;
use test;

my @tests = (
	{ input => 'mdstat-centos6.2', status => OK,
		active => 1,
		message => 'md4(227.41 GiB raid1):UU, md3(450.00 GiB raid1):UU, md0(99.99 MiB raid1):UU, md1(8.00 GiB raid0):OK, md2(250.00 GiB raid1):UU',
	},
	{ input => 'mdstat-failed', status => CRITICAL,
		active => 1,
		message => 'md0(8.00 GiB raid5):F:sdc1:U_U',
	},
	{ input => 'mdstat-linear', status => OK,
		active => 1,
		message => 'md1(68.50 GiB raid1):UU, md0(55.59 GiB linear):OK',
	},
	{ input => 'mdstat-raid0', status => OK,
		active => 1,
		message => 'md2(20.00 GiB raid0):OK',
	},
	{ input => 'mdstat-resync', status => RESYNC,
		active => 1,
		message => 'md0(54.81 MiB raid1):UU, md2(698.64 GiB raid1):UU (resync:11.2% 54928K/sec ETA: 197.2min), md1(698.58 GiB raid1):UU (resync:9.9% 51946K/sec ETA: 211.5min)',
	},
	{ input => 'mdstat-none',
		active => 0,
	},
	{ input => 'mdstat-inexistent',
		active => 0,
	},
	{ input => 'pr28_0', status => RESYNC,
		active => 1, # When one md device is OK, and the other one is rebuilding:
		message => 'md1(927.52 GiB raid1):UU, md0(203.81 MiB raid1):_U (recovery:0.4% 12K/sec ETA: 276.9min)',
	},
	{ input => 'pr28_1', status => CRITICAL,
		active => 1, # When one md device is resyncing and the other is set faulty or removed:
		message => 'md1(927.52 GiB raid1):F::_U, md0(203.81 MiB raid1):_U (recovery:3.6% 12K/sec ETA: 259.6min)',
	},
	{ input => 'pr28_2', status => RESYNC,
		active => 1, # When both md devices are resyncing (or planning to resync)
		message => 'md1(927.52 GiB raid1):_U (resync=DELAYED), md0(203.81 MiB raid1):_U (recovery:3.9% 12K/sec ETA: 267.0min)',
	},
	# issues #23 and #24
	{ input => 'pr24', status => WARNING, check_status => WARNING,
		active => 1,
		message => 'md2(2.73 TiB raid1):UU (check:98.3% 9854K/sec ETA: 81.7min), md1(511.99 MiB raid1):UU, md0(2.00 GiB raid1):UU',
	},
	{ input => 'pr24', status => OK, check_status => OK,
		active => 1,
		message => 'md2(2.73 TiB raid1):UU (check:98.3% 9854K/sec ETA: 81.7min), md1(511.99 MiB raid1):UU, md0(2.00 GiB raid1):UU',
	},
	{ input => 'pr77', status => OK, check_status => OK,
		active => 1,
		message => 'md1(445.64 GiB raid1):UU (check=DELAYED), md0(20.00 GiB raid1):UU (check:6.4% 97293K/sec ETA: 3.3min)',
	},
	{ input => 'issue34', status => OK,
		active => 1,
		message => 'md127(931.51 GiB raid1):UU, md0(5.16 MiB):',
	},
	{ input => 'issue34_2', status => OK,
		active => 1,
		message => 'md126(931.51 GiB raid1):UU, md127(5.16 MiB):',
	},
	{ input => 'issue43/reshape', status => WARNING, resync_status => WARNING,
		active => 1,
		message => 'md0(5.46 TiB raid6):UUUU__ (reshape:48.4% 9898K/sec ETA: 1271.8min), md0(5.46 TiB raid6):UUUU__ (reshape:48.4% 9898K/sec ETA: 1271.8min)',
	},
	{ input => 'issue43/recovery', status => WARNING, resync_status => WARNING,
		active => 1,
		message => 'md0(5.46 TiB raid6):UUUU__ (recovery:19.6% 13810K/sec ETA: 1420.1min), md0(5.46 TiB raid6):UUUU__ (recovery:19.6% 13810K/sec ETA: 1420.1min)',
	},
	{ input => 'issue43/mdstat-rebuilt', status => CRITICAL, resync_status => WARNING,
		active => 1,
		message => 'md0(5.46 TiB raid6):F::U_UUUU',
	},
	{ input => 'issue43/mdstat-readd', status => WARNING, resync_status => WARNING,
		active => 1,
		message => 'md0(5.46 TiB raid6):U_UUUU (recovery:0.2% 14868K/sec ETA: 1638.2min)',
	},
	{ input => 'issue64', status => OK,
		active => 1,
		message => 'md2(1.64 TiB raid1):UU, md1(186.26 GiB raid1):UU, md0(486.99 MiB raid1):UU',
	},
);

# save default value
my $saved_resync_status = $plugin::resync_status;
my $saved_check_status = $plugin::check_status;

foreach my $test (@tests) {
	if (defined $test->{resync_status}) {
		$plugin::resync_status = $test->{resync_status};
	} else {
		$plugin::resync_status = $saved_resync_status;
	}
	if (defined $test->{check_status}) {
		$plugin::check_status = $test->{check_status};
	} else {
		$plugin::check_status = $saved_check_status;
	}
	my $plugin = mdstat->new(
		commands => {
			'mdstat' => ['<', TESTDIR . '/data/mdstat/' . $test->{input}],
		},
	);

	ok($plugin, "plugin created");

	my $active = $plugin->active;
	ok($active == $test->{active}, "active matches");

	# can't check if plugin not active
	next unless $active;

	$plugin->check;
	ok(1, "check ran");

	ok(defined($plugin->status), "status code set");
	is($plugin->status, $test->{status}, "status code matches");
	is($plugin->message, $test->{message}, "status message");
}
