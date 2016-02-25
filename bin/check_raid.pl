#!/usr/bin/perl
use Monitoring::Plugin 0.37;
use App::Monitoring::Plugin::CheckRaid;
use App::Monitoring::Plugin::CheckRaid::Sudoers;
use App::Monitoring::Plugin::CheckRaid::Plugin;
use App::Monitoring::Plugin::CheckRaid::Utils;
use warnings;
use strict;

my $PROGNAME = 'check_raid';
my $VERSION = q/4.0.1/;

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
	spec => 'debug|d',
	help => 'debug mode, or dry-run for sudoers',
);
$mp->add_arg(
	spec => 'list_plugins|list-plugins|l',
	help => 'Lists active plugins',
);
$mp->add_arg(
	spec => 'plugin|p=s@',
	help => 'Force the use of selected plugins, comma separated',
);
$mp->add_arg(
	spec => 'plugin-option=s@',
	help => "Specify extra option for specific plugin.\n" .
'
Plugin options (key=>value pairs) passed as "options" key to each plugin constructor.
The options are global, not plugin specific, but it\'s recommended to prefix option with plugin name.
The convention is to have PLUGIN_NAME-OPTION_NAME=OPTION_VALUE syntax to namespace each plugin option.

For example "--plugin-option=hp_msa-serial=/dev/ttyS2"
would define option "serial" for "hp_msa" plugin with value "/dev/ttyS2".
'
);
$mp->add_arg(
	spec => 'noraid=s',
	help => 'Return STATE if no RAID controller is found. Defaults to UNKNOWN',
);
$mp->add_arg(
	spec => 'resync=s',
	help => 'Return STATE if RAID is in resync state. Defaults to WARNING',
);
$mp->add_arg(
	spec => 'check=s',
	help => 'Return STATE if RAID is in check state. Defaults to OK',
);
$mp->add_arg(
	spec => 'cache-fail=s',
	help => 'Set status as STATE if Write Cache is present but disabled. Defaults to WARNING',
);
$mp->add_arg(
	spec => 'bbulearn=s',
	help => 'Return STATE if Backup Battery Unit (BBU) learning cycle is in progress. Defaults to WARNING',
);
$mp->add_arg(
	spec => 'bbu-monitoring',
	help => 'Enable experimental monitoring of the BBU status',
);
$mp->add_arg(
	spec => 'warnonly|W',
	help => 'Treat CRITICAL errors as WARNING',
);

$mp->getopts;

if (@ARGV) {
	@App::Monitoring::Plugin::CheckRaid::Utils::ignore = @ARGV;
}

my (%ERRORS) = (OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3);

my %plugin_options;

if ($mp->opts->warnonly) {
	App::Monitoring::Plugin::CheckRaid::Plugin->set_critical_as_warning;
}
if ($mp->opts->get('bbu-monitoring')) {
	$plugin_options{options}{bbu_monitoring} = 1;
}

# setup state flags
my %state_flags = (
	'resync' => 'resync_status',
	'check' => 'check_status',
	'noraid' => 'noraid_state',
	'bbulearn' => 'bbulearn_status',
	'cache-fail' => 'cache_fail_status',
);
while (my($opt, $key) = each %state_flags) {
	if (my $value = $mp->opts->get($opt)) {
		unless (exists $ERRORS{$value}) {
			print "Invalid value: '$value' for --$opt\n";
			exit $ERRORS{UNKNOWN};
		}
		$plugin_options{options}{$key} = $ERRORS{$value};
	}
}

# enable only specified plugins
if (my $plugins = $mp->opts->plugin) {
	# split, as each value can contain commas
	$plugin_options{enable_plugins} = [ map { split(/,/, $_) } @$plugins ];
}

if (my $opts = $mp->opts->get('plugin-option')) {
	foreach my $o (@$opts) {
		my($k, $v) = split(/=/, $o, 2);
		$plugin_options{$k} = $v;
	}
}

my $mc = App::Monitoring::Plugin::CheckRaid->new(%plugin_options);

$App::Monitoring::Plugin::CheckRaid::Utils::debug = $mp->opts->debug;

my @plugins = $mc->active_plugins;
if (!@plugins) {
	$mp->plugin_exit($plugin_options{options}{noraid_state}, "No active plugins (No RAID found)");
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
	warn "$count active plugins\n";
	exit $ERRORS{OK};
}

my $message = '';
my $status = $ERRORS{OK};

# perform check of each active plugin
foreach my $plugin (@plugins) {
	# skip if no check method (not standalone checker)
	next unless $plugin->can('check');

	# perform the check
	$plugin->check;
	my $pn = $plugin->{name};

	# collect results
	unless (defined $plugin->status) {
		$status = $ERRORS{UNKNOWN} if $ERRORS{UNKNOWN} > $status;
		$message .= '; ' if $message;
		$message .= "$pn:[Plugin error]";
		next;
	}
	if ($plugin->message or $plugin->{options}{noraid_state} == $ERRORS{UNKNOWN}) {
		$status = $plugin->status if $plugin->status > $status;
	} else {
		$status = $plugin->{options}{noraid_state} if $plugin->{options}{noraid_state} > $status;
	}
	$message .= '; ' if $message;
	$message .= "$pn:[".$plugin->message."]";
	$message .= ' | ' . $plugin->perfdata if $plugin->perfdata;
	$message .= "\n" . $plugin->longoutput if $plugin->longoutput;
}

if ($message) {
	if ($status == $ERRORS{OK}) {
		print "OK: ";
	} elsif ($status == $ERRORS{WARNING}) {
		print "WARNING: ";
	} elsif ($status == $ERRORS{CRITICAL}) {
		print "CRITICAL: ";
	} else {
		print "UNKNOWN: ";
	}
	print "$message\n";
} elsif ($plugin::options{noraid_state} != $ERRORS{UNKNOWN}) {
	$status = $plugin::options{noraid_state};
	print "No RAID configuration found\n";
} else {
	$status = $ERRORS{UNKNOWN};
	print "No RAID configuration found (tried: ", join(', ', @plugins), ")\n";
}
exit $status;
