#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;

use Test::More tests => 18;
use test;

unshift(@utils::paths, TESTDIR . '/data/bin');

my $commands = {
	proc => ['<', '.'],
	mdstat => ['<', TESTDIR . '/data/mdstat/mdstat-failed'],
	read => ['<', TESTDIR . '/data/dmraid/pr35'],
};

my %params = (
	commands => $commands,
);

# check that all plugins are enabled
foreach my $pn (@utils::plugins) {
	my $plugin = $pn->new(%params);

	ok($plugin->active, "plugin $pn is active");
}
