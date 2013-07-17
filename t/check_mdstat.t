#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use Test::More tests => 58;
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
	{ input => 'mdstat-resync', status => WARNING,
		active => 1,
		message => 'md0(54.81 MiB raid1):UU, md2(698.64 GiB raid1):UU (resync:11.2% 54928K/sec ETA: 197.2min), md1(698.58 GiB raid1):UU (resync:9.9% 51946K/sec ETA: 211.5min)',
	},
	{ input => 'mdstat-none',
		active => 0,
	},
	{ input => 'mdstat-inexistent',
		active => 0,
	},
	{ input => 'pr24', status => WARNING,
		active => 1,
		message => 'md2(2.73 TiB raid1):UU, md1(511.99 MiB raid1):UU, md0(2.00 GiB raid1):UU',
	},
	{ input => 'pr28_0', status => CRITICAL,
		active => 1, # When one md device is OK, and the other one is rebuilding:
		message => 'md1(927.52 GiB raid1):F::_U, md0(203.81 MiB raid1):F::_U',
	},
	{ input => 'pr28_1', status => WARNING,
		active => 1, # When one md device is resyncing and the other is set faulty or removed:
		message => 'md1(927.52 GiB raid1):F::_U, md0(203.81 MiB raid1):F::_U',
	},
	{ input => 'pr28_2', status => WARNING,
		active => 1, # When both md devices are resyncing (or planning to resync)
		message => 'md1(927.52 GiB raid1):UU, md0(203.81 MiB raid1):F::_U',
	},
);

foreach my $test (@tests) {
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
	ok($plugin->status == $test->{status}, "status code");
	print "[".$plugin->message."]\n";
	ok($plugin->message eq $test->{message}, "status message");
}
