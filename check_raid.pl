#!/usr/bin/perl
# vim:ts=4:sw=4:noet
# Nagios EPN Workaround:
# nagios: -epn
#
# Check RAID status. Look for any known types of RAID configurations, and check them all.
# Return CRITICAL if in a DEGRADED or FAILED state.
# Return UNKNOWN if there are no RAID configs that can be found.
# Return WARNING if rebuilding or initialising
#
# 2004-2006 Steve Shipway, university of auckland,
# http://www.steveshipway.org/forum/viewtopic.php?f=20&t=417&p=3211
# Steve Shipway Thanks M Carmier for megaraid section.
# 2009-2015 Elan Ruusamäe <glen@pld-linux.org>

# Requires: Perl 5.8 for the open(my $fh , '-|', @CMD) syntax.
# You can workaround for earlier Perl it as:
# open(my $fh , join(" ", @CMD, '|') or return;
# http://perldoc.perl.org/perl58delta.html#PerlIO-is-Now-The-Default
#
# License: GPL v2
# Homepage: https://github.com/glensc/nagios-plugin-check_raid
# Changes: https://github.com/glensc/nagios-plugin-check_raid/blob/master/ChangeLog.md
# Nagios Exchange Entry: http://exchange.nagios.org/directory/Plugins/Hardware/Storage-Systems/RAID-Controllers/check_raid/details
# Reporting Bugs: https://github.com/glensc/nagios-plugin-check_raid#reporting-bugs
#
# You can also mail patches directly to Elan Ruusamäe <glen@pld-linux.org>,
# but please attach them in unified format (diff -u) against latest version in github.
#
# Supports:
# - Adaptec AAC RAID via aaccli or afacli or arcconf
# - AIX software RAID via lsvg
# - HP/Compaq Smart Array via cciss_vol_status (hpsa supported too)
# - HP Smart Array Controllers and MSA Controllers via hpacucli (see hapacucli readme)
# - HP Smart Array (MSA1500) via serial line
# - Linux 3ware SATA RAID via tw_cli
# - Linux Device Mapper RAID via dmraid
# - Linux DPT/I2O hardware RAID controllers via /proc/scsi/dpt_i2o
# - Linux GDTH hardware RAID controllers via /proc/scsi/gdth
# - Linux LSI MegaRaid hardware RAID via CmdTool2
# - Linux LSI MegaRaid hardware RAID via megarc
# - Linux LSI MegaRaid hardware RAID via /proc/megaraid
# - Linux MegaIDE hardware RAID controllers via /proc/megaide
# - Linux MPT hardware RAID via mpt-status
# - Linux software RAID (md) via /proc/mdstat
# - LSI Logic MegaRAID SAS series via MegaCli
# - LSI MegaRaid via lsraid
# - Serveraid IPS via ipssend
# - Solaris software RAID via metastat
# - Areca SATA RAID Support via cli64/cli32
# - Detecting SCSI devices or hosts with lsscsi

use warnings;
use strict;

# do nothing in library mode
return 1 if caller;

use strict;
use warnings;
use Getopt::Long;

utils->import;
sudoers->import;

my ($opt_V, $opt_d, $opt_h, $opt_W, $opt_S, $opt_p, $opt_l);
my (%ERRORS) = (OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3);
my ($VERSION) = "3.2.5";
my ($message, $status);

#####################################################################
$ENV{'BASH_ENV'} = '';
$ENV{'ENV'} = '';

sub print_usage {
	print join "\n",
	"Usage: check_raid [-h] [-V] [-S] [list of devices to ignore]",
	"",
	"Options:",
	" -h, --help",
	"    Print help screen",
	" -V, --version",
	"    Print version information",
	" -S, --sudoers",
	"    Setup sudo rules",
	" -W, --warnonly",
	"    Treat CRITICAL errors as WARNING",
	" -p, --plugin <name(s)>",
	"    Force the use of selected plugins, comma separated",
	" -l, --list-plugins",
	"    Lists active plugins",
	" --noraid=STATE",
	"    Return STATE if no RAID controller is found. Defaults to UNKNOWN",
	" --resync=STATE",
	"    Return STATE if RAID is in resync state. Defaults to WARNING",
	" --check=STATE",
	"    Return STATE if RAID is in check state. Defaults to OK",
	" --cache-fail=STATE",
	"    Set status as STATE if Write Cache is present but disabled. Defaults to WARNING",
	" --bbulearn=STATE",
	"    Return STATE if Backup Battery Unit (BBU) learning cycle is in progress. Defaults to WARNING",
	" --bbu-monitoring",
	"    Enable experimental monitoring of the BBU status",
	"";
}

sub print_help {
	print "check_raid, v$VERSION\n";
	print "Copyright (c) 2004-2006 Steve Shipway,
Copyright (c) 2009-2015, Elan Ruusamäe <glen\@pld-linux.org>

This plugin reports the current server's RAID status
https://github.com/glensc/nagios-plugin-check_raid

";
	print_usage();
}

# Print active plugins
sub print_active_plugins {

	# go over all registered plugins
	foreach my $pn (@utils::plugins) {
		my $plugin = $pn->new;

		# skip inactive plugins (disabled or no tools available)
		next unless $plugin->active;

		# print plugin name
		print $plugin->{name}."\n";
	}
}

sub setstate {
	my ($key, $opt, $value) = @_;
	unless (exists $ERRORS{$value}) {
		print "Invalid value: '$value' for --$opt\n";
		exit $ERRORS{UNKNOWN};
	}
	$$key = $ERRORS{$value};
}

# obtain git hash of check_raid.pl
# http://stackoverflow.com/questions/460297/git-finding-the-sha1-of-an-individual-file-in-the-index#comment26055597_460315
sub git_hash_object {
	my $content = "blob ";
	$content .= -s $0;
	$content .= "\0";
	open my $fh, '<', $0 or die $!;
	local $/ = undef;
	$content .= <$fh>;
	close($fh) or die $!;

	# try Digest::SHA1
	my $digest;
	eval {
		require Digest::SHA1;
		$digest = Digest::SHA1::sha1_hex($content);
	};

	return $digest;
}

# plugin options (key=>value pairs) passed as 'options' key to each plugin constructor.
# the options are global, not plugin specific, but it's recommended to prefix option with plugin name.
# the convention is to have PLUGIN_NAME-OPTION_NAME=OPTION_VALUE syntax to namespace each plugin option.
#
# so "--plugin-option=hp_msa-serial=/dev/ttyS2" would define option 'serial'
# for 'hp_msa' plugin with value '/dev/ttyS2'.
#
my %plugin_options;

Getopt::Long::Configure('bundling');
GetOptions(
	'V' => \$opt_V, 'version' => \$opt_V,
	'd' => \$opt_d,
	'h' => \$opt_h, 'help' => \$opt_h,
	'S' => \$opt_S, 'sudoers' => \$opt_S,
	'W' => \$opt_W, 'warnonly' => \$opt_W,
	'resync=s' => sub { setstate(\$plugin_options{resync_status}, @_); },
	'check=s' => sub { setstate(\$plugin_options{check_status}, @_); },
	'noraid=s' => sub { setstate(\$plugin_options{noraid_state}, @_); },
	'bbulearn=s' => sub { setstate(\$plugin_options{bbulearn_status}, @_); },
	'cache-fail=s' => sub { setstate(\$plugin_options{cache_fail_status}, @_); },
	'plugin-option=s' => sub { my($k, $v) = split(/=/, $_[1], 2); $plugin_options{$k} = $v; },
	'bbu-monitoring' => \$plugin_options{bbu_monitoring},
	'p=s' => \$opt_p, 'plugin=s' => \$opt_p,
	'l' => \$opt_l, 'list-plugins' => \$opt_l,
) or exit($ERRORS{UNKNOWN});

if ($opt_S) {
	sudoers($opt_d);
	exit 0;
}

@utils::ignore = @ARGV if @ARGV;

if ($opt_V) {
	print "check_raid Version $VERSION\n";
	exit $ERRORS{'OK'};
}

if ($opt_d) {
	print "check_raid Version $VERSION\n";
	my $git_ver = `git describe --tags 2>/dev/null`;
	if ($git_ver) {
		print "Using git: $git_ver";
	}
	my $hash = git_hash_object();
	if ($hash) {
		print "git hash object: $hash\n";
	}
	print "See CONTRIBUTING.md how to report bugs with debug data:\n";
	print "https://github.com/glensc/nagios-plugin-check_raid/blob/master/CONTRIBUTING.md\n\n";
}

if ($opt_h) {
	print_help();
	exit $ERRORS{'OK'};
}

if ($opt_W) {
	plugin->set_critical_as_warning;
}

if ($opt_l) {
	print_active_plugins;
	exit $ERRORS{'OK'};
}

$status = $ERRORS{OK};
$message = '';
$utils::debug = $opt_d;

my @plugins = $opt_p ? grep { my $p = $_; grep { /^$p$/ } split(/,/, $opt_p) } @utils::plugins : @utils::plugins;

foreach my $pn (@plugins) {
	my $plugin = $pn->new(options => \%plugin_options);

	# skip inactive plugins (disabled or no tools available)
	next unless $plugin->active;
	# skip if no check method (not standalone checker)
	next unless $plugin->can('check');

	# perform the check
	$plugin->check;

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
