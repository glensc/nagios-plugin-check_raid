#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use constant TESTS => 3;
use Test::More tests => 1 + TESTS * 5;
use test;

my @tests = (
	{
		status => OK,
		metastat => 'metastat.mirror',
		message => 'd30:d31:Okay, d30:d32:Okay, d3:d8:Okay, d3:d9:Okay, d1:d6:Okay, d1:d7:Okay, d0:d4:Okay, d0:d5:Okay, d2:d10:Okay, d2:d11:Okay',
	},
	{
		status => OK,
		metastat => 'metastat-mirrors-with-hotspares',
		message => 'd9:d19:Okay, d9:d29:Okay, d8:d18:Okay, d8:d28:Okay, d4:d14:Okay, d4:d24:Okay, d3:d13:Okay, d3:d23:Okay, d1:d11:Okay, d1:d21:Okay, d0:d10:Okay, d0:d20:Okay, hsp001:c1t5d0s0:Available, hsp002:c2t5d0s0:Available',
	},
	{
		status => OK,
		metastat => 'metastat-snapshot-with-soft-partition',
		message => 'd50:d51:Okay, d50:d52:Okay, d40:d41:Okay, d40:d42:Okay, d30:d31:Okay, d30:d32:Okay, d20:d21:Okay, d20:d22:Okay, d10:d11:Okay, d10:d12:Okay, d100:d60:Okay, d60:d61:Okay, d60:d62:Okay',
	},
);

# test that plugin can be created
ok(metastat->new, "plugin created");

foreach my $test (@tests) {
	my $plugin = metastat->new(
		commands => {
			'metastat' => ['<', TESTDIR . '/data/metastat/' .$test->{metastat} ],
		},
	);
	ok($plugin, "plugin created");

	$plugin->check;
	ok(1, "check ran");

	ok(defined($plugin->status), "status code set");
	is($plugin->status, $test->{status}, "status code matches");
	is($plugin->message, $test->{message}, "status message");
}
