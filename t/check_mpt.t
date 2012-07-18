#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use Test::More tests => 4;
use test;

my $plugin = mpt->new(
	commands => {
		'status' => ['<', TESTDIR . '/data/mpt-status'],
	},
);


ok($plugin, "plugin created");
ok($plugin->check, "check ran");
ok($plugin->status == OK, "status code");
print "[".$plugin->message."]\n";
ok($plugin->message eq 'Logical Volume 0:OPTIMAL', "status message");
