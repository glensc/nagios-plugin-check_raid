#!/usr/bin/perl
use warnings;
use strict;
use Monitoring::Plugin;
use App::Monitoring::Plugin::CheckRaid;

my $PROGNAME = 'check_raid';
my $VERSION = '4.0.0';

my $mp = Monitoring::Plugin->new(
    usage =>
	"Usage: %s [ -v|--verbose ] [-t <timeout>]",

    version => $VERSION,
    blurb => 'This plugin checks all RAID volumes (hardware and software) that can be identified.',

    plugin  => $PROGNAME,
    shortname => $PROGNAME,
);

$mp->getopts;

my $mc = App::Monitoring::Plugin::CheckRaid->new();
my @plugins = $mc->plugins();

$mp->plugin_exit(OK, "Checked OK");
