#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use Test::More tests => 4;
use test;

my $plugin = afacli->new(
	commands => {
		'container list' => ['<', TESTDIR . '/data/afacli'],
	},
);

ok($plugin, "plugin created");
ok($plugin->check, "check ran");
ok($plugin->status == OK, "status OK");
ok($plugin->message eq '0/00/0:Normal, 0/01/0:Normal', "expected message");
