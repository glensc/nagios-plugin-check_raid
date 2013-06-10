#!/usr/bin/perl -w
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use Test::More tests => 22;
use test;

# NOTE: this plugin has side effect of changing dir
use Cwd;
ok(chdir(TESTDIR), "dir changed");
my $cwd = Cwd::cwd();
ok(defined($cwd), "cwd set");

if (1) {
my $plugin = arcconf->new(
	commands => {
		'getstatus' => ['<', $cwd. '/data/arcconf/1/getstatus'],
		'getconfig' => ['<', $cwd. '/data/arcconf/1/getconfig'],
	},
);


ok($plugin, "plugin created");
$plugin->check;
ok(1, "check ran");
ok(defined($plugin->status), "status code set");
ok($plugin->status == OK, "status OK");
print "[".$plugin->message."]\n";
ok($plugin->message eq 'Controller:Optimal, Logical Device 0:Optimal');
}

if (1) {
my $plugin = arcconf->new(
	commands => {
		'getstatus' => ['<', $cwd. '/data/arcconf/1/getstatus'],
		'getconfig' => ['<', $cwd. '/data/arcconf/2/getconfig'],
	},
);

ok($plugin, "plugin created");
$plugin->check;
ok(1, "check ran");
ok(defined($plugin->status), "status code set");
ok($plugin->status == OK, "status OK");
print "[".$plugin->message."]\n";
ok($plugin->message eq 'Controller:Optimal, Battery Status: Optimal, Battery Capacity Remaining: 100%, Battery Time: 3d16h0m, Logical Device 0:Optimal');
}

if (1) {
my $plugin = arcconf->new(
	commands => {
		'getstatus' => ['<', $cwd. '/data/arcconf/3/getstatus'],
		'getconfig' => ['<', $cwd. '/data/arcconf/3/getconfig'],
	},
);


ok($plugin, "plugin created");
$plugin->check;
ok(1, "check ran");
ok(defined($plugin->status), "status code set");
ok($plugin->status == OK, "status OK");
print "[".$plugin->message."]\n";
ok($plugin->message eq 'Controller:Optimal, Logical device #0: Build/Verify: In Progress 11%, ZMM Status: ZMM Optimal, Logical Device 0(Volume01):Optimal');
}

if (1) {
my $plugin = arcconf->new(
	commands => {
		'getstatus' => ['<', $cwd. '/data/arcconf/4/arcconf_getstatus_1.out'],
		'getconfig' => ['<', $cwd. '/data/arcconf/4/arcconf_getconfig_1_al.out'],
	},
);


ok($plugin, "plugin created");
$plugin->check;
ok(1, "check ran");
ok(defined($plugin->status), "status code set");
ok($plugin->status == OK, "status OK");
print "[".$plugin->message."]\n";
ok($plugin->message eq 'Controller:Okay, Logical Device 1(MailMerak):Okay');
}
