#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use Test::More tests => 5;
use test;

my $plugin = megacli->new(
	commands => {
		'pdlist' => ['<', TESTDIR . '/data/megacli.pdlist.all'],
		'ldinfo' => ['<', TESTDIR . '/data/megacli-all'],
	},
);

ok($plugin, "plugin created");
$plugin->check;
ok(1, "check ran");
ok(defined($plugin->status), "status code set");
ok($plugin->status == OK, "status code");
print "[".$plugin->message."]\n";
ok($plugin->message eq '2 Vols: OS:Optimal,DATA:Optimal, 12 Devs: 04,05,06,07,08,09,10,11,12,13: Online 14,16: Hotspare', "status message");
