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
		list => 'test1/LIST.log',
		cstatus => 'test1/0-STATUS.log',
		message => 'ctrl #0: Optimal',
	},
);

foreach my $test (@tests) {
	my $plugin = sas2ircu->new(
		program => '/bin/true',
		commands => {
			'controller list' => ['<', TESTDIR . '/data/sas2ircu/' . $test->{list} ],
			'controller status' => ['<', TESTDIR . '/data/sas2ircu/' . $test->{cstatus} ],
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
