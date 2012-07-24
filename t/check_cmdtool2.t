#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use Test::More tests => 5;
use test;

my $plugin = cmdtool2->new(
	commands => {
		'adapter list' => ['<', TESTDIR . '/data/CmdTool2.adapters'],
		'adapter config' => ['<', TESTDIR . '/data/CmdTool2.adapter-0'],
	},
);

ok($plugin, "plugin created");
$plugin->check;
ok(1, "check ran");
ok(defined($plugin->status), "status code set");
ok($plugin->status == OK, "status OK");
print "[".$plugin->message."]\n";
ok($plugin->message eq 'Logical Drive 0,0: Optimal', "expected message");
