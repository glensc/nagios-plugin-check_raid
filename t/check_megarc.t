#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use Test::More tests => 5;
use test;

my $plugin = megarc->new(
	commands => {
		'controller list' => ['<', TESTDIR . '/data/megarc.adapters'],
		'controller config' => ['<', TESTDIR . '/data/megarc.adapter-0'],
	},
);


ok($plugin, "plugin created");
$plugin->check;
ok(1, "check ran");
ok(defined($plugin->status), "status code set");
ok($plugin->status == OK, "status code");
print "[".$plugin->message."]\n";
ok($plugin->message eq 'Logical Drive 0: OPTIMAL', "status message");
