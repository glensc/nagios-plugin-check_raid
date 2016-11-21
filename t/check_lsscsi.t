#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use constant TESTS => 3;
use Test::More tests => 1 + 2 * TESTS;
use test;

my @tests = (
	{
		file => 'lsscsi-with-sg-module',
		scan => [{
			'hctl' => '0:0:0:0',
			'devnode' => '/dev/sda',
			'sgnode' => '/dev/sg1',
			'rev' => '5.14',
			'model' => 'LOGICAL VOLUME',
			'type' => 'disk',
			'vendor' => 'HP'
		}, {
			'hctl' => '0:3:0:0',
			'devnode' => '-',
			'sgnode' => '/dev/sg0',
			'rev' => '5.14',
			'model' => 'P410i',
			'type' => 'storage',
			'vendor' => 'HP'
		}]
	},
	{
		file => 'lsscsi-no-sg-module',
		scan => [{
			'hctl' => '0:0:0:0',
			'devnode' => '/dev/sda',
			'sgnode' => '-',
			'rev' => '5.14',
			'model' => 'LOGICAL VOLUME',
			'type' => 'disk',
			'vendor' => 'HP'
		}, {
			'hctl' => '0:3:0:0',
			'devnode' => '-',
			'sgnode' => '-',
			'rev' => '5.14',
			'model' => 'P410i',
			'type' => 'storage',
			'vendor' => 'HP'
		}]
	},
	{
		file => 'lsscsi.argos',
		scan => [{
			'hctl' => '0:0:0:0',
			'devnode' => '/dev/sr0',
			'sgnode' => '/dev/sg0',
			'rev' => 'KS03',
			'model' => 'DVDRAM GSA-T40L',
			'type' => 'cd/dvd',
			'vendor' => 'HL-DT-ST'
		}]
	},
);

# test that plugin can be created
ok(lsscsi->new, "plugin created");

foreach my $test (@tests) {
	my $plugin = lsscsi->new(
		commands => {
			'lsscsi list' => ['<', TESTDIR . '/data/lsscsi/' .$test->{file} ],
		}
	);
	ok($plugin, "plugin created: $test->{file}");

	my $scan = $plugin->scan;
	is_deeply($scan, $test->{scan}, "scan structure");
}
