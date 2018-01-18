#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;

use Test::More tests => 29;
use test;

unshift(@App::Monitoring::Plugin::CheckRaid::Utils::paths, TESTDIR . '/data/bin');

my $commands = {
	proc => ['<', '.'],
	mdstat => ['<', TESTDIR . '/data/mdstat/mdstat-failed'],
	dmraid => ['<', TESTDIR . '/data/dmraid/pr35'],
	get_controller_no => ['<', TESTDIR . '/data/mpt/pr36/getctrlno1'],
	metastat => ['<', TESTDIR . '/data/metastat/metastat-snapshot-mirrors'],
};

my %params = (
	commands => $commands,
	options => {
		'hp_msa-serial' => '/dev/null',
		'hp_msa-enabled' => 1,
	},
);

# plugins known to be broken
my %blacklist = map { $_ => 1 } qw(
	lsraid
	lsvg
	megaide
	megaraid
	mvcli
);

use App::Monitoring::Plugin::CheckRaid;

my $mc = App::Monitoring::Plugin::CheckRaid->new(%params);
my @plugins = $mc->plugins;

# check that all plugins are enabled
# iterate over plugins, and check they report being active
# skip items in blacklist first
foreach my $plugin (@plugins) {
	my $pn = $plugin->{name};
	my $active = $plugin->active;

	if (exists $blacklist{$pn} && !$active) {
		ok(!$active, "plugin $pn blacklisted:YES active:NO");
		next;
	}
	if (!exists $blacklist{$pn} && $active) {
		ok($active, "plugin $pn blacklisted:NO active:YES");
		next;
	}

	ok(1, "$pn should be blacklisted and disabled");
}
