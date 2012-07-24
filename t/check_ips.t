#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use Test::More tests => 5;
use test;

my $plugin = ips->new(
	commands => {
		'list logical drive' => ['<', TESTDIR . '/data/ipssend'],
	},
);

ok($plugin, "plugin created");
$plugin->check;
ok(1, "check ran");
ok(defined($plugin->status), "status code set");
ok($plugin->status == CRITICAL, "status code");
print "[".$plugin->message."]\n";
ok($plugin->message eq '1:Okay, 2:Critical', "status message");
