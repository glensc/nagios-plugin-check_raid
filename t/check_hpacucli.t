#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use constant TESTS => 7;
use Test::More tests => 1 + TESTS * 6;
use test;

my @tests = (
	{
		status => OK,
		controller => 'hpacucli.controller.all.show.status',
		logical => 'hpacucli.slot=0.logicaldrive.all.show',
		message => 'MY STORAGE: Array A(OK)[LUN1:OK], Smart Array P400i: Array A(OK)[LUN1:OK]',
		c => '1',
	},
	{
		status => CRITICAL,
		controller => 'hpacucli.controller.all.show.status',
		logical => 'hpacucli.interim_recovery_mode.show',
		message => 'MY STORAGE: Array A(OK)[LUN1:Interim Recovery Mode], Smart Array P400i: Array A(OK)[LUN1:Interim Recovery Mode]',
		c => '2',
	},
	{
		status => UNKNOWN,
		controller => 'heracles/controller.all.show.status',
		logical => 'heracles/logicaldrive.all.show',
		message => 'Smart Array P400: ',
		c => '3',
	},
	{
		status => OK,
		controller => 'PR94/ctrl-status',
		logical => 'PR94/ld-show',
		message => 'Smart Array P410i: Array A(OK)[LUN1:OK]',
		c => '4',
	},
	{
		status => CRITICAL,
		controller => 'issue98/controller.status',
		logical => 'issue98/logical.status',
		message => 'Smart Array P410: Array A(OK)[LUN1:OK], Array B(Failed)[LUN2:OK], Array C(OK)[LUN3:OK]',
		c => '5',
	},
	{
		status => OK,
		controller => 'issue106/ctrl.status',
		logical => 'issue106/logical.status',
		message => 'Smart HBA H240ar: Array A(OK)[LUN1:OK]',
		c => '6',
	},
	{
		status => UNKNOWN,
		controller => '145/controller',
		logical => '145/logicaldrive',
		message => 'Smart HBA H244br: Array A(OK)[LUN1:OK], Smart Array P840: Array A(OK)[LUN1:OK]',
		c => '145',
	},
);

# test that plugin can be created
ok(hpacucli->new, "plugin created");

foreach my $test (@tests) {
	my $plugin = hpacucli->new(
		program => '/bin/true',
		commands => {
			'controller status' => ['<', TESTDIR . '/data/hpacucli/' . $test->{controller} ],
			'logicaldrive status' => ['<', TESTDIR . '/data/hpacucli/' .$test->{logical} ],
		},
	);

	ok($plugin, "plugin created");

	$plugin->check;
	ok(1, "check ran");

	ok(defined($plugin->status), "status code set");
	is($plugin->status, $test->{status}, "status code matches");
	is($plugin->message, $test->{message}, "status message");

	my $c = $plugin->parse;
	my $df = TESTDIR . '/dump/hpacucli/' . $test->{c};
	if (!-f $df) {
		store_dump $df, $c;
		# trigger error so that we don't have feeling all is ok ;)
		ok(0, "Created dump for $df");
	}
	my $dump = read_dump($df);
	is_deeply($c, $dump, "controller structure");
}
