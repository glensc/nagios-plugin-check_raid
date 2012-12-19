#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use Test::More tests => 30;
use test;

my @tests = (
	{ input => 'mdstat-centos6.2', status => OK,
		active => 1,
	   	message => 'md4(227.41 GiB raid1):UU, md3(450.00 GiB raid1):UU, md0(99.99 MiB raid1):UU, md1(8.00 GiB raid0):OK, md2(250.00 GiB raid1):UU'
	},
	{ input => 'mdstat-failed', status => CRITICAL,
		active => 1,
	   	message => 'md0(8.00 GiB raid5):F:sdc1:U_U'
	},
	{ input => 'mdstat-linear', status => OK,
		active => 1,
	   	message => 'md1(68.50 GiB raid1):UU, md0(55.59 GiB linear):OK'
	},
	{ input => 'mdstat-raid0', status => OK,
		active => 1,
	   	message => 'md2(20.00 GiB raid0):OK'
	},
	{ input => 'mdstat-resync', status => WARNING,
		active => 1,
	   	message => 'md0(54.81 MiB raid1):UU, md2(698.64 GiB raid1):UU (resync:11.2% 54928K/sec ETA: 197.2min), md1(698.58 GiB raid1):UU (resync:9.9% 51946K/sec ETA: 211.5min)'
	},
);

foreach my $test (@tests) {
	my $plugin = mdstat->new(
		commands => {
			'proc' => ['<', TESTDIR . '/data/mdstat/' . $test->{input}],
		},
	);

	ok($plugin, "plugin created");

	ok($plugin->active eq $test->{active}, "active matches");

	$plugin->check;
	ok(1, "check ran");

	ok(defined($plugin->status), "status code set");
	ok($plugin->status == $test->{status}, "status code");
	print "[".$plugin->message."]\n";
	ok($plugin->message eq $test->{message}, "status message");
}
