#!/usr/bin/perl
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use constant TESTS => 14;
use Test::More tests => 1 + TESTS * 6;
use test;

my @tests = (
	{
		status => OK,
		controller => 'hpacucli.controller.all.show.status',
		logical => 'hpacucli.slot=0.logicaldrive.all.show',
		message => 'MY STORAGE[OK]: Array A(OK)[LUN1:OK], Smart Array P400i[OK]: Array A(OK)[LUN1:OK]',
		c => '1',
	},
	{
		status => CRITICAL,
		controller => 'hpacucli.controller.all.show.status',
		logical => 'hpacucli.interim_recovery_mode.show',
		message => 'MY STORAGE[OK]: Array A(OK)[LUN1:Interim Recovery Mode], Smart Array P400i[OK]: Array A(OK)[LUN1:Interim Recovery Mode]',
		c => '2',
	},
	{
		status => UNKNOWN,
		controller => 'heracles/controller.all.show.status',
		logical => 'heracles/logicaldrive.all.show',
		message => 'Smart Array P400[OK, Invalid target syntax. "attr_value_slot_unknown" is not a valid target]',
		c => '3',
	},
	{
		status => OK,
		controller => 'PR94/ctrl-status',
		logical => 'PR94/ld-show',
		message => 'Smart Array P410i[OK]: Array A(OK)[LUN1:OK]',
		c => '4',
	},
	{
		status => CRITICAL,
		controller => 'issue98/controller.status',
		logical => 'issue98/logical.status',
		message => 'Smart Array P410[OK]: Array A(OK)[LUN1:OK], Array B(Failed)[LUN2:OK], Array C(OK)[LUN3:OK]',
		c => '5',
	},
	{
		status => OK,
		controller => 'issue106/ctrl.status',
		logical => 'issue106/logical.status',
		message => 'Smart HBA H240ar[OK]: Array A(OK)[LUN1:OK]',
		c => '6',
	},
	{
		status => OK,
		controller => '145/controller',
		logical => '145/logicaldrive.slot0',
		message => 'Smart HBA H244br[OK]: Array A(OK)[LUN1:OK], Smart Array P840[OK]: Array A(OK)[LUN1:OK]',
		c => '145',
	},
	{
		status => CRITICAL,
		controller => '145/controller',
		logical => '145/logicaldrive.slot0',
		message => 'Controller slot=30 not found',
		targets => 'slot=30',
		c => '145_error',
	},
	{
		status => UNKNOWN,
		controller => '145/controller',
		logical => '145/logicaldrive.slot1',
		message => 'Smart Array P840[OK, Not configured]',
		targets => 'slot=1',
		c => '145_slot1',
	},
	{
		status => OK,
		controller => 'issue139/controller',
		logical => 'issue139/logicaldrive',
		message => 'Dynamic Smart Array B140i[OK]: Array A(OK)[LUN1:OK]',
		c => 'issue139',
	},
	# framework does not allow testing two logical devices, so two tests here instead
	{
		status => OK,
		controller => '151/controller',
		logical => '151/logicaldrive.slot0',
		message => 'Smart Array P410i[OK]: Array A(OK)[LUN1:OK]',
		targets => 'slot=0',
		c => 'issue151_0',
	},
	{
		status => UNKNOWN,
		controller => '151/controller',
		logical => '151/logicaldrive.slot3',
		message => 'Smart Array P411[OK, Not configured]',
		targets => 'slot=3',
		c => 'issue151_3',
	},
	{
		status => OK,
		controller => '154/controller',
		logical => '154/logicaldrive.slot0',
		message => 'Smart Array 5i[OK]: Array A(OK)[LUN1:OK]',
		targets => 'slot=0',
		c => 'issue154_0',
	},
	{
		status => UNKNOWN,
		controller => '154/controller',
		logical => '154/logicaldrive.slot1',
		message => 'Smart Array 642[OK, Not configured]',
		targets => 'slot=1',
		c => 'issue154_1',
	},
);

# test that plugin can be created
ok(hpacucli->new, "plugin created");

foreach my $test (@tests) {
	my %args = (
		program => '/bin/true',
		commands => {
			'controller status' => ['<', TESTDIR . '/data/hpacucli/' . $test->{controller} ],
			'logicaldrive status' => ['<', TESTDIR . '/data/hpacucli/' .$test->{logical} ],
		},
		options => {
		},
	);

	if ($test->{targets}) {
		$args{'options'}{'hpacucli-target'} = $test->{targets};
	}

	my $plugin = hpacucli->new(%args);

	ok($plugin, "plugin created: $test->{c}");

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
