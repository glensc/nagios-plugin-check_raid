#!/usr/bin/perl -w
BEGIN {
	(my $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift @INC, $srcdir;
}

use strict;
use warnings;
use Test::More tests => 12;
use test;

# NOTE: this plugin has side effect of changing dir
use Cwd;
ok(chdir(TESTDIR), "dir changed");
my $cwd = Cwd::cwd();
ok(defined($cwd), "cwd set");

{
my $plugin = arcconf->new(
	commands => {
		'adapter list' => ['<', $cwd. '/data/arcconf/getconfig'],
	},
);


ok($plugin, "plugin created");
$plugin->check;
ok(1, "check ran");
ok(defined($plugin->status), "status code set");
ok($plugin->status == OK, "status OK");
print "[".$plugin->message."]\n";
ok($plugin->message eq 'Controller:Optimal, Logical Device 0:Optimal', "expected message");
}

{
my $plugin = arcconf->new(
	commands => {
		'adapter list' => ['<', $cwd. '/data/arcconf/getconfig.batteries'],
	},
);

ok($plugin, "plugin created");
$plugin->check;
ok(1, "check ran");
ok(defined($plugin->status), "status code set");
ok($plugin->status == OK, "status OK");
print "[".$plugin->message."]\n";
ok($plugin->message eq 'Controller:Optimal, Battery Status: Optimal, Battery Capacity: 100%, Battery Time: 3d17h20m, Logical Device 0:Optimal', "expected message");
}
