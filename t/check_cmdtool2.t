#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use Test::More tests => 5;
use test;

my @tests = (
	{
		status => OK,
		list => 'CmdTool2.adapters',
		config => 'CmdTool2.adapter-0',
		message => 'Logical Drive 0,0: Optimal',
	},
);

foreach my $test (@tests) {
	my $plugin = cmdtool2->new(
		commands => {
			'adapter list' => ['<', TESTDIR . '/data/cmdtool2/' . $test->{list} ],
			'adapter config' => ['<', TESTDIR . '/data/cmdtool2/' . $test->{config} ],
		},
	);
	ok($plugin, "plugin created");

	$plugin->check;
	ok(1, "check ran");

	ok(defined($plugin->status), "status code set");
	ok($plugin->status == $test->{status}, "status code (got:".$plugin->status." exp:".$test->{status}.")");

	print "[".$plugin->message."]\n";
	ok($plugin->message eq $test->{message}, "status message");
}
