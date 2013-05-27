#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use Test::More tests => 5;
use test;

if (1) {
	my $plugin = megacli->new(
		commands => {
			'pdlist' => ['<', TESTDIR . '/data/megacli/megacli.pdlist.1'],
			'ldinfo' => ['<', TESTDIR . '/data/megacli/megacli.ldinfo.1'],
		},
	);

	ok($plugin, "plugin created");
	$plugin->check;
	ok(1, "check ran");
	ok(defined($plugin->status), "status code set");
	ok($plugin->status == OK, "status code");
	print "[".$plugin->message."]\n";
	ok($plugin->message eq 'Volumes(2): OS:Optimal,DATA:Optimal; Devices(12): 04,05,06,07,08,09,10,11,12,13: Online 14,16: Hotspare');
}
