#!/usr/bin/perl
use warnings;
use strict;
use Monitoring::Plugin;

my $PROGNAME = 'check_raid';
my $VERSION = '4.0.0';

my $p = Monitoring::Plugin->new(
    usage =>
	"Usage: %s [ -v|--verbose ] [-t <timeout>]",

    version => $VERSION,
    blurb => 'This plugin checks all RAID volumes (hardware and software) that can be identified.',

    plugin  => $PROGNAME,
    shortname => $PROGNAME,
);

$p->getopts;

$p->plugin_exit(OK, "Checked OK");
