#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use Test::More tests => 5;
use test;

my $plugin = sas2ircu->new(
	program => '/bin/true',
	commands => {
		'controller list' => ['<', TESTDIR . '/data/sas2ircu.LIST.log'],
		'controller status' => ['<', TESTDIR . '/data/sas2ircu.0-STATUS.log'],
	},
);


ok($plugin, "plugin created");
$plugin->check;
ok(1, "check ran");
ok(defined($plugin->status), "status code set");
ok($plugin->status == OK, "status code");
print "[".$plugin->message."]\n";
ok($plugin->message eq 'ctrl #0: Optimal', "status message");
