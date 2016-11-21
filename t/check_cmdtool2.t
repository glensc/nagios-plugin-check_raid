#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use Test::More tests => 6;
use test;

my @tests = (
	{
		status => OK,
		list => 'CmdTool2.adapters',
		config => 'CmdTool2.adapter-0',
		message => 'Logical Drive 0,0: Optimal',
	},
);

# test that plugin can be created
ok(cmdtool2->new, "plugin created");

foreach my $test (@tests) {
	my $plugin = cmdtool2->new(
		commands => {
			'adapter list' => ['<', TESTDIR . '/data/cmdtool2/' . $test->{list} ],
			'adapter config' => ['<', TESTDIR . '/data/cmdtool2/' . $test->{config} ],
		},
	);
	ok($plugin, "plugin created: $test->{list}");

	$plugin->check;
	ok(1, "check ran");

	ok(defined($plugin->status), "status code set");
	is($plugin->status, $test->{status}, "status code matches");
	is($plugin->message, $test->{message}, "status message");
}
