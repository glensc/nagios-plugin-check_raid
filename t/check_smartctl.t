#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use Test::More tests => 5;
use test;

my $plugin = smartctl->new(
	commands => {
		'smartctl' => ['<', TESTDIR . '/data/smartctl.cciss.$disk' ],
	},
);


ok($plugin, "plugin created");
$plugin->check(
	['/dev/cciss/c0d0', '-dcciss', 0],
	['/dev/cciss/c0d0', '-dcciss', 7],
	['/dev/cciss/c0d0', '-dcciss', 8],
);
ok(1, "check ran");
ok(defined($plugin->status), "status code set");
ok($plugin->status == OK, "status code");
print "[".$plugin->message."]\n";
ok($plugin->message eq '/dev/cciss/c0d0#0: OK', "status message");
