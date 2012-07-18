#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use Test::More tests => 4;
use test;

my $plugin = sas2ircu->new(
	program => '/bin/true',
	commands => {
		'controller list' => ['<', TESTDIR . '/data/sas2ircu.LIST.log'],
		'controller status' => ['<', TESTDIR . '/data/sas2ircu.0-STATUS.log'],
	},
);


ok($plugin, "plugin created");
ok($plugin->check, "check ran");
ok($plugin->status == OK, "status code");
print "[".$plugin->message."]\n";
ok($plugin->message eq 'ctrl #0: Optimal', "status message");
