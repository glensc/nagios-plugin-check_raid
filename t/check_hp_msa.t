#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;

	if ($ENV{TRAVIS}) {
		use Test::More;
		plan skip_all => "Skipping test as can't open /dev in travis";
		exit 0;
	}
}

use strict;
use warnings;
use Test::More tests => 5;
use test;

my $plugin = hp_msa->new(
	tty_device => '/dev/ttyNOTTY',
	lockdir => '.',
	commands => {
	},
);

ok($plugin, "plugin created");
$plugin->check;
ok(1, "check ran");
ok(defined($plugin->status), "status code set");
ok($plugin->status == WARNING, "status code");
print "[".$plugin->message."]\n";
ok($plugin->message eq "Can't open /dev/ttyNOTTY", "status message");
