#!/usr/bin/perl
use warnings;
use strict;
use Monitoring::Plugin 0.37;
use App::Monitoring::Plugin::CheckRaid;
use App::Monitoring::Plugin::CheckRaid::Sudoers;

my $PROGNAME = 'check_raid';
my $VERSION = '4.0.0';

my $mp = Monitoring::Plugin->new(
    usage =>
	"Usage: %s [-h] [-V] [-S] [list of devices to ignore]",

    version => $VERSION,
    blurb => 'This plugin checks all RAID volumes (hardware and software) that can be identified.',

    plugin  => $PROGNAME,
    shortname => $PROGNAME,
);

$mp->add_arg(
	spec => 'sudoers|S',
	help => 'Setup sudo rules',
);
$mp->add_arg(
	spec => 'warnonly|W',
	help => 'Treat CRITICAL errors as WARNING',
);
$mp->add_arg(
	spec => 'list_plugins|list-plugins|l',
	help => 'Lists active plugins',
);
$mp->add_arg(
	spec => 'plugin|p=s',
	help => 'Force the use of selected plugins, comma separated',
);
$mp->add_arg(
	spec => 'noraid',
	help => 'Return STATE if no RAID controller is found. Defaults to UNKNOWN',
);
$mp->add_arg(
	spec => 'resync',
	help => 'Return STATE if RAID is in resync state. Defaults to WARNING',
);
$mp->add_arg(
	spec => 'check',
	help => 'Return STATE if RAID is in check state. Defaults to OK',
);
$mp->add_arg(
	spec => 'cache-fail',
	help => 'Set status as STATE if Write Cache is present but disabled. Defaults to WARNING',
);
$mp->add_arg(
	spec => 'bbulearn',
	help => 'Return STATE if Backup Battery Unit (BBU) learning cycle is in progress. Defaults to WARNING',
);
$mp->add_arg(
	spec => 'bbu-monitoring',
	help => 'Enable experimental monitoring of the BBU status',
);

$mp->getopts;

my %options;

# enable only specified plugins
if ($mp->opts->plugin) {
	$options{enable_plugins} = [ split(/,/, $mp->opts->plugin) ];
}

my $mc = App::Monitoring::Plugin::CheckRaid->new(%options);

my @plugins = $mc->active_plugins;
if (!@plugins) {
	$mp->plugin_exit(UNKNOWN, "No active plugins")
}

if ($mp->opts->sudoers) {
	sudoers($mp->opts->debug, @plugins);
	$mp->plugin_exit(OK, "sudoers updated");
}

# print active plugins
if ($mp->opts->list_plugins) {
	foreach my $p (@plugins) {
		print $p->{name}, "\n";
	}
	my $count = @plugins;
	$mp->plugin_exit(OK, "$count active plugins");
}

# perform check of each active plugin
foreach my $plugin (@plugins) {
	# skip if no check method (not standalone checker)
	next unless $plugin->can('check');

	# perform the check
	$plugin->check;
}

my ($code, $message) = $mp->check_messages;

$mp->plugin_exit($code, $message);
