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

{
package utils;

my @EXPORT = qw(which find_sudo);
my @EXPORT_OK = @EXPORT;

# registered plugins
our @plugins;

# devices to ignore
our @ignore;

# debug level
our $debug = 0;

# paths for which()
our @paths = split /:/, $ENV{'PATH'};
unshift(@paths, qw(/usr/local/nrpe /usr/local/bin /sbin /usr/sbin /bin /usr/sbin /opt/bin));

# lookup program from list of possible filenames
# search is performed from $PATH plus additional hardcoded @paths
# NOTE: we do not check for execute bit as it may fail for non-root. #104
sub which {
	for my $prog (@_) {
		for my $path (@paths) {
			return "$path/$prog" if -f "$path/$prog";
		}
	}
	return undef;
}

our @sudo;
sub find_sudo() {
	# no sudo needed if already root
	return [] unless $>;

	# detect once
	return \@sudo if @sudo;

	my $sudo = which('sudo') or die "Can't find sudo";
	push(@sudo, $sudo);

	# detect if sudo supports -A, issue #88
	use IPC::Open3;
	my $fh;
	my @cmd = ($sudo, '-h');
	my $pid = open3(undef, $fh, undef, @cmd) or die "Can't run 'sudo -h': $!";
	local $/ = undef;
	local $_ = <$fh>;
	close($fh) or die $!;
	push(@sudo, '-A') if /-A/;

	return \@sudo;
}

} # package utils

{
package plugin;
use Carp qw(croak);

# Nagios standard error codes
my (%ERRORS) = (OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3);

# status to set when RAID is in resync state
our $resync_status = $ERRORS{WARNING};

# status to set when RAID is in check state
our $check_status = $ERRORS{OK};

# status to set when PD is spare
our $spare_status = $ERRORS{OK};

# status to set when BBU is in learning cycle.
our $bbulearn_status = $ERRORS{WARNING};

# status to set when Write Cache has failed.
our $cache_fail_status = $ERRORS{WARNING};

# check status of BBU
our $bbu_monitoring = 0;

# return list of programs this plugin needs
# @internal
sub program_names {
}

# return hash of canonical commands that plugin can use
# @internal
sub commands {
	{}
}

# return sudo rules if program needs it
# may be SCALAR or LIST of scalars
# @internal
sub sudo {
	();
}

# constructor for plugins
sub new {
	my $class = shift;

	croak 'Odd number of elements in argument hash' if @_ % 2;

	my $self = {
		program_names => [ $class->program_names ],
		commands => $class->commands,
		sudo => $class->sudo ? utils::find_sudo() : '',
		@_,
		name => $class,
		status => undef,
		message => undef,
		perfdata => undef,
		longoutput => undef,
	};

	# lookup program, if not defined by params
	if (!$self->{program}) {
		$self->{program} = utils::which(@{$self->{program_names}});
	}

	return bless $self, $class;
}

# see if plugin is active (disabled or no tools available)
sub active {
	my $this = shift;

	# no tool found, return false
	return 0 unless $this->{program};

	# program file must exist, don't check for execute bit. #104
	-f $this->{program};
}

# set status code for plugin result
# does not overwrite status with lower value
# returns the current status code
sub status {
	my ($this, $status) = @_;

	if (defined $status) {
		$this->{status} = $status unless defined($this->{status}) and $status < $this->{status};
	}
	$this->{status};
}

sub set_critical_as_warning {
	$ERRORS{CRITICAL} = $ERRORS{WARNING};
}

# helper to set status to WARNING
# returns $this to allow fluent api
sub warning {
	my ($this) = @_;
	$this->status($ERRORS{WARNING});
	return $this;
}

# helper to set status to CRITICAL
# returns $this to allow fluent api
sub critical {
	my ($this) = @_;
	$this->status($ERRORS{CRITICAL});
	return $this;
}

# helper to set status to UNKNOWN
# returns $this to allow fluent api
sub unknown {
	my ($this) = @_;
	$this->status($ERRORS{UNKNOWN});
	return $this;
}

# helper to set status to OK
sub ok {
	my ($this) = @_;
	$this->status($ERRORS{OK});
	return $this;
}

# helper to set status for resync
# returns $this to allow fluent api
sub resync {
	my ($this) = @_;
	$this->status($resync_status);
	return $this;
}

# helper to set status for check
# returns $this to allow fluent api
sub check_status {
	my ($this) = @_;
	$this->status($check_status);
	return $this;
}

# helper to set status for spare
# returns $this to allow fluent api
sub spare {
	my ($this) = @_;
	$this->status($spare_status);
	return $this;
}

# helper to set status for BBU learning cycle
# returns $this to allow fluent api
sub bbulearn {
	my ($this) = @_;
	$this->status($bbulearn_status);
	return $this;
}

# helper to set status when Write Cache fails
# returns $this to allow fluent api
sub cache_fail {
	my ($this) = @_;
	$this->status($cache_fail_status);
	return $this;
}

# helper to get/set bbu monitoring
sub bbu_monitoring {
	my ($this, $val) = @_;

	if (defined $val) {
		$bbu_monitoring = $val;
	}
	$bbu_monitoring;
}

# setup status message text
sub message {
	my ($this, $message) = @_;
	if (defined $message) {
		# TODO: append if already something there
		$this->{message} = $message;
	}
	$this->{message};
}

# Set performance data output.
sub perfdata {
	my ($this, $perfdata) = @_;
	if (defined $perfdata) {
		# TODO: append if already something there
		$this->{perfdata} = $perfdata;
	}
	$this->{perfdata};
}

# Set plugin long output.
sub longoutput {
	my ($this, $longoutput) = @_;
	if (defined $longoutput) {
		# TODO: append if already something there
		$this->{longoutput} = $longoutput;
	}
	$this->{longoutput};
}

# a helper to join similar statuses for items
# instead of printing
#  0: OK, 1: OK, 2: OK, 3: NOK, 4: OK
# it would print
#  0-2,4: OK, 3: NOK
# takes as input list:
#  { status => @items }
sub join_status {
	my $this = shift;
	my %status = %{$_[0]};

	my @status;
	for my $status (sort {$a cmp $b} keys %status) {
		my $disks = $status{$status};
		my @s;
		foreach my $disk (@$disks) {
			push(@s, $disk);
		}
		push(@status, join(',', @s).'='.$status);
	}

	return join ' ', @status;
}

# return true if parameter is not in ignore list
sub valid($) {
	my $this = shift;
	my ($v) = lc $_[0];

	foreach (@utils::ignore) {
		return 0 if lc $_ eq $v;
	}
	return 1;
}

use constant K => 1024;
use constant M => K * 1024;
use constant G => M * 1024;
use constant T => G * 1024;

sub format_bytes($) {
	my $this = shift;

	my ($bytes) = @_;
	if ($bytes > T) {
		return sprintf("%.2f TiB", $bytes / T);
	}
	if ($bytes > G) {
		return sprintf("%.2f GiB", $bytes / G);
	}
	if ($bytes > M) {
		return sprintf("%.2f MiB", $bytes / M);
	}
	if ($bytes > K) {
		return sprintf("%.2f KiB", $bytes / K);
	}
	return "$bytes B";
}

# disable sudo temporarily
sub nosudo_cmd {
	my ($this, $command, $cb) = @_;

	my ($res, @res);

	my $sudo = $this->{sudo};
	$this->{sudo} = 0;

	if (wantarray) {
		@res = $this->cmd($command, $cb);
	} else {
		$res = $this->cmd($command, $cb);
	}

	$this->{sudo} = $sudo;

	return wantarray ? @res : $res;
}

# build up command for $command
# returns open filehandle to process output
# if command fails, program is exited (caller needs not to worry)
sub cmd {
	my ($this, $command, $cb) = @_;

	# build up command
	my @CMD = $this->{program};

	# add sudo if program needs
	unshift(@CMD, @{$this->{sudo}}) if $> and $this->{sudo};

	my $args = $this->{commands}{$command} or croak "command '$command' not defined";

	# callback to replace args in command
	my $cb_ = sub {
		my $param = shift;
		if ($cb) {
			if (ref $cb eq 'HASH' and exists $cb->{$param}) {
				return wantarray ? @{$cb->{$param}} : $cb->{$param};
			}
			return &$cb($param) if ref $cb eq 'CODE';
		}

		if ($param eq '@CMD') {
			# command wanted, but not found
			croak "Command for $this->{name} not found" unless defined $this->{program};
			return @CMD;
		}
		return $param;
	};

	# add command arguments
	my @cmd;
	for my $arg (@$args) {
		local $_ = $arg;
		# can't do arrays with s///
		# this limits that @arg must be single argument
		if (/@/) {
			push(@cmd, $cb_->($_));
		} else {
			s/([\$]\w+)/$cb_->($1)/ge;
			push(@cmd, $_);
		}
	}

	my $op = shift @cmd;
	my $fh;
	if ($op eq '=' and ref $cb eq 'SCALAR') {
		# Special: use open2
		use IPC::Open2;
		warn "DEBUG EXEC: $op @cmd" if $utils::debug;
		my $pid = open2($fh, $$cb, @cmd) or croak "open2 failed: @cmd: $!";
	} elsif ($op eq '>&2') {
		# Special: same as '|-' but reads both STDERR and STDOUT
		use IPC::Open3;
		warn "DEBUG EXEC: $op @cmd" if $utils::debug;
		my $pid = open3(undef, $fh, $cb, @cmd);

	} else {
		warn "DEBUG EXEC: @cmd" if $utils::debug;
		open($fh, $op, @cmd) or croak "open failed: @cmd: $!";
	}

	# for dir handles, reopen as opendir
	if (-d $fh) {
		undef($fh);
		warn "DEBUG OPENDIR: $cmd[0]" if $utils::debug;
		opendir($fh, $cmd[0]) or croak "opendir failed: @cmd: $!";
	}

	return $fh;
}

} # package plugin

package lsscsi;
use base 'plugin';

push(@utils::plugins, __PACKAGE__);

sub program_names {
	__PACKAGE__;
}

sub commands {
	{
		'lsscsi list' => ['-|', '@CMD', '-g'],
	}
}

# lists contoller devices (type=storage)
# this will fail (return empty list) if sg module is not present
# return /dev/sgX nodes
sub list_sg {
	my $this = shift;

	my @scan = $this->scan;

	my @devs = map { $_->{sgnode} } grep { $_->{type} eq 'storage' && $_->{sgnode} ne '-' } @scan;
	return wantarray ? @devs : \@devs;
}

# list disk nodes one for each controller
# return /dev/sdX nodes
sub list_dd {
	my $this = shift;

	my @scan = $this->scan;
	my @devs = map { $_->{devnode} } grep { $_->{type} eq 'disk' && $_->{devnode} ne '-' && $_->{sgnode} } @scan;
	return wantarray ? @devs : \@devs;
}

# scan lsscsi output
sub scan {
	my $this = shift;

	# cache inside single run
	return wantarray ? @{$this->{sdevs}} : $this->{sdevs} if $this->{sdevs};

	# Scan such output:
	# [0:0:0:0]    disk    HP       LOGICAL VOLUME   3.00  /dev/sda   /dev/sg0
	# [0:3:0:0]    storage HP       P410i            3.00  -          /dev/sg1
	# or without sg driver:
	# [0:0:0:0]    disk    HP       LOGICAL VOLUME   3.00  /dev/sda   -
	# [0:3:0:0]    storage HP       P410i            3.00  -          -

	my $fh = $this->cmd('lsscsi list');
	my @sdevs;
	while (<$fh>) {
		chop;
		if (my($hctl, $type, $vendor, $model, $rev, $devnode, $sgnode) = m{^
			\[([\d:]+)\] # SCSI Controller, SCSI bus, SCSI target, and SCSI LUN
			\s+(\S+) # type
			\s+(\S+) # vendor
			\s+(.*?) # model, match everything as it may contain spaces
			\s+(\S+) # revision
			\s+((?:/dev/\S+|-)) # /dev node
			\s+((?:/dev/\S+|-)) # /dev/sg node
		}x) {
			push(@sdevs, {
				'hctl' => $hctl,
				'type' => $type,
				'vendor' => $vendor,
				'model' => $model,
				'rev' => $rev,
				'devnode' => $devnode,
				'sgnode' => $sgnode,
			});
		}
	}
	close $fh;

	$this->{sdevs} = \@sdevs;
	return wantarray ? @sdevs : \@sdevs;
}

package metastat;
# Solaris, software RAID
use base 'plugin';

push(@utils::plugins, __PACKAGE__);

sub program_names {
	__PACKAGE__;
}

sub commands {
	{
		'metastat' => ['>&2', '@CMD'],
	}
}

sub sudo {
	my ($this, $deep) = @_;
	# quick check when running check
	return 1 unless $deep;

	my $cmd = $this->{program};
	"CHECK_RAID ALL=(root) NOPASSWD: $cmd"
}

sub active($) {
	my ($this) = @_;

	# program not found
	return 0 unless $this->{program};

	my $output = $this->get_metastat;
	return !!@$output;
}

sub get_metastat {
	my $this = shift;

	# cache inside single run
	return $this->{output} if defined $this->{output};

	my $fh = $this->cmd('metastat');
	my @data;
	while (<$fh>) {
		chomp;
		last if /there are no existing databases/;
		push(@data, $_);
	}

	return $this->{output} = \@data;
}

sub check {
	my $this = shift;

	my ($d, $sd);

	# status messages pushed here
	my @status;
	my $output = $this->get_metastat;

	foreach (@$output) {
		if (/^(\S+):/) { $d = $1; $sd = ''; next; }
		if (/Submirror \d+:\s+(\S+)/) { $sd = $1; next; }
		if (/Device:\s+(\S+)/) { $sd = $1; next; }
		if (my($s) = /State: (\S.+\w)/) {
			if ($sd and $this->valid($sd) and $this->valid($d)) {
				if ($s =~ /Okay/i) {
					# no worries...
				} elsif ($s =~ /Resync/i) {
					$this->resync;
				} else {
					$this->critical;
				}
				push(@status, "$d:$sd:$s");
			}
		}

		if (defined $d && $d =~ /hsp/) {
			if (/(c[0-9]+t[0-9]+d[0-9]+s[0-9]+)\s+(\w+)/) {
				$sd = $1;
				my $s = $2;
				$this->warning if ($s !~ /Available/);
				push(@status, "$d:$sd:$s");
			}
		}
	}

	return unless @status;

	$this->ok->message(join(', ', @status));
}

package megaide;
# MegaIDE RAID controller
use base 'plugin';

# register
# Status: BROKEN: no test data
#push(@utils::plugins, __PACKAGE__);

sub sudo {
	my $cat = utils::which('cat');

	"CHECK_RAID ALL=(root) NOPASSWD: $cat /proc/megaide/0/status";
}

sub check {
	my $this = shift;
	my $fh;

	# status messages pushed here
	my @status;

	foreach my $f (</proc/megaide/*/status>) { # / silly comment to fix vim syntax hilighting
		if (-r $f) {
			open $fh, '<', $f or next;
=cut
		} else {
			my @CMD = ($cat, $f);
			unshift(@CMD, $sudo) if $> and $sudo;
			open($fh , '-|', @CMD) or next;
=cut
		}
		while (<$fh>) {
			next unless (my($s, $n) = /Status\s*:\s*(\S+).*Logical Drive.*:\s*(\d+)/i);
			next unless $this->valid($n);
			if ($s ne 'ONLINE') {
				$this->critical;
				push(@status, "$n:$s");
			} else {
				push(@status, "$n:$s");
			}
			last;
		}
		close $fh;
	}

	return unless @status;

	$this->message(join(' ', @status));
}

package mdstat;
# Linux Multi-Device (md)
use base 'plugin';

# register
push(@utils::plugins, __PACKAGE__);

sub commands {
	{
		'mdstat' => ['<', '/proc/mdstat'],
	}
}

sub active ($) {
	my ($this) = @_;
	# easy way out. no /proc/mdstat
	return 0 unless -e $this->{commands}{mdstat}[1];

	# extra check if mdstat is empty
	my @md = $this->parse;
	return $#md >= 0;
}

sub parse {
	my $this = shift;

	my (@md, %md);
	my $fh = $this->cmd('mdstat');
	my $arr_checking = 0;
	while (<$fh>) {
		chomp;

		# skip first line
		next if (/^Personalities : /);

		# kernel-3.0.101/drivers/md/md.c, md_seq_show
		# md1 : active raid1 sdb2[0] sda2[1]
		if (my($dev, $active, $ro, $rest) = m{^
			(\S+)\s+:\s+ # mdname
			(\S+)\s+     # active: "inactive", "active"
			(\((?:auto-)?read-only\)\s+)? # readonly
			(.+)         # personality name + disks
		}x) {
			my @parts = split /\s/, $rest;
			my $re = qr{^
				(\S+)           # devname
				(?:\[(\d+)\])   # desc_nr
				(?:\((.)\))?    # flags: (W|F|S) - WriteMostly, Faulty, Spare
			$}x;
			my @disks = ();
			my $personality;
			while (my($disk) = pop @parts) {
				last if !$disk;
				if ($disk !~ $re) {
					$personality = $disk;
					last;
				}
				my($dev, $number, $flags) = $disk =~ $re;
				push(@disks, {
					'dev' => $dev,
					'number' => int($number),
					'flags' => $flags || '',
				});
			}

			die "Unexpected parse" if @parts;

			# first line resets %md
			%md = (dev => $dev, personality => $personality, readonly => $ro, active => $active, disks => [ @disks ]);

			next;
		}

		# variations:
		#"      8008320 blocks [2/2] [UU]"
		#"      58291648 blocks 64k rounding" - linear
		#"      5288 blocks super external:imsm"
		#"      20969472 blocks super 1.2 512k chunks"
		#
		# Metadata version:
		# This is one of
		# - 'none' for arrays with no metadata (good luck...)
		# - 'external' for arrays with externally managed metadata,
		# - or N.M for internally known formats
		#
		if (my($b, $mdv, $status) = m{^
			\s+(\d+)\sblocks\s+ # blocks
			# metadata version
			(super\s(?:
				(?:\d+\.\d+) | # N.M
				(?:external:\S+) |
				(?:non-persistent)
			))?\s*
			(.+) # mddev->pers->status (raid specific)
		$}x) {
			# linux-2.6.33/drivers/md/dm-raid1.c, device_status_char
			# A => Alive - No failures
			# D => Dead - A write failure occurred leaving mirror out-of-sync
			# S => Sync - A sychronization failure occurred, mirror out-of-sync
			# R => Read - A read failure occurred, mirror data unaffected
			# U => for the rest
			my ($s) = $status =~ /\s+\[([ADSRU_]+)\]/;

			$md{status} = $s || '';
			$md{blocks} = int($b);
			$md{md_version} = $mdv;

			# if external try to parse dev
			if ($mdv) {
				($md{md_external}) = $mdv =~ m{external:(\S+)};
			}
			next;
		}

		# linux-2.6.33/drivers/md/md.c, md_seq_show
		if (my($action) = m{(resync=(?:PENDING|DELAYED))}) {
			$md{resync_status} = $action;
			next;
		}
		# linux-2.6.33/drivers/md/md.c, status_resync
		# [==>..................]  resync = 13.0% (95900032/732515712) finish=175.4min speed=60459K/sec
		# [=>...................]  check =  8.8% (34390144/390443648) finish=194.2min speed=30550K/sec
		if (my($action, $perc, $eta, $speed) = m{(resync|recovery|reshape)\s+=\s+([\d.]+%) \(\d+/\d+\) finish=([\d.]+min) speed=(\d+K/sec)}) {
			$md{resync_status} = "$action:$perc $speed ETA: $eta";
			next;
		} elsif (($perc, $eta, $speed) = m{check\s+=\s+([\d.]+%) \(\d+/\d+\) finish=([\d.]+min) speed=(\d+K/sec)}) {
			$md{check_status} = "check:$perc $speed ETA: $eta";
			$arr_checking = 1;
			next;
		}

		# we need empty line denoting end of one md
		next unless /^\s*$/;

		next unless $this->valid($md{dev});

		push(@md, { %md } ) if %md;
	}
	close $fh;

	# One of the arrays is in checking state, which could be because there is a scheduled sync of all MD arrays
	# In such a case, all of the arrays are scheduled to by checked, but only one of them is actually running the check
	# while the others are in "resync=DELAYED" state.
	# We don't want to receive notifications in such case, so we check for this particular case here
	if ($arr_checking && scalar(@md) >= 2) {
		foreach my $dev (@md) {
			if ($dev->{resync_status} && $dev->{resync_status} eq "resync=DELAYED") {
				delete $dev->{resync_status};
				$dev->{check_status} = "check=DELAYED";
			}
		}
	}

	return wantarray ? @md : \@md;
}

sub check {
	my $this = shift;

	my (@status);
	my @md = $this->parse;

	foreach (@md) {
		my %md = %$_;

		# common status
		my $size = $this->format_bytes($md{blocks} * 1024);
		my $personality = $md{personality} ? " $md{personality}" : "";
		my $s = "$md{dev}($size$personality):";

		# failed disks
		my @fd = map { $_->{dev} } grep { $_->{flags} =~ /F/ } @{$md{disks}};

		# raid0 is just there or its not. raid0 can't degrade.
		# same for linear, no $md_status available
		if ($personality =~ /linear|raid0/) {
			$s .= "OK";

		} elsif ($md{resync_status}) {
			$this->resync;
			$s .= "$md{status} ($md{resync_status})";

		} elsif ($md{check_status}) {
			$this->check_status;
			$s .= "$md{status} ($md{check_status})";

		} elsif ($md{status} =~ /_/) {
			$this->critical;
			my $fd = join(',', @fd);
			$s .= "F:$fd:$md{status}";

		} elsif (@fd > 0) {
			# FIXME: this is same as above?
			$this->warning;
			$s .= "hot-spare failure:". join(",", @{$md{failed_disks}}) .":$md{status}";

		} else {
			$s .= "$md{status}";
		}
		push(@status, $s);
	}

	return unless @status;

	# denote this plugin as ran ok
	$this->ok;

	$this->message(join(', ', @status));
}

package lsraid;
# Linux, software RAID
use base 'plugin';

# register
# Broken: missing test data
#push(@utils::plugins, __PACKAGE__);

sub program_names {
	__PACKAGE__;
}

sub commands {
	{
		'list' => ['-|', '@CMD', '-A', '-p'],
	}
}

sub sudo {
	my ($this, $deep) = @_;
	# quick check when running check
	return 1 unless $deep;

	my $cmd = $this->{program};
	"CHECK_RAID ALL=(root) NOPASSWD: $cmd -A -p"
}

sub check {
	my $this = shift;

	# status messages pushed here
	my @status;

	my $fh = $this->cmd('list');
	while (<$fh>) {
		next unless (my($n, $s) = m{/dev/(\S+) \S+ (\S+)});
		next unless $this->valid($n);
		if ($s =~ /good|online/) {
			# no worries
		} elsif ($s =~ /sync/) {
			$this->warning;
		} else {
			$this->critical;
		}
		push(@status, "$n:$s");
	}
	close $fh;

	return unless @status;

	$this->message(join(', ', @status));
}

package megacli;
# MegaRAID SAS 8xxx controllers
# based on info from here:
# http://www.bxtra.net/Articles/2008-09-16/Dell-Perc6i-RAID-Monitoring-Script-using-MegaCli-LSI-CentOS-52-64-bits
# TODO: http://www.techno-obscura.com/~delgado/code/check_megaraid_sas
# TODO: process several adapters
# TODO: process drive temperatures
# TODO: check error counts
# TODO: hostspare information
use base 'plugin';

# register
push(@utils::plugins, __PACKAGE__);

sub program_names {
	qw(MegaCli64 MegaCli megacli);
}

sub commands {
	{
		'pdlist' => ['-|', '@CMD', '-PDList', '-aALL', '-NoLog'],
		'ldinfo' => ['-|', '@CMD', '-LdInfo', '-Lall', '-aALL', '-NoLog'],
		'battery' => ['-|', '@CMD', '-AdpBbuCmd', '-GetBbuStatus', '-aALL', '-NoLog'],
	}
}

# TODO: process from COMMANDS
sub sudo {
	my ($this, $deep) = @_;
	# quick check when running check
	return 1 unless $deep;

	my $cmd = $this->{program};

	(
		"CHECK_RAID ALL=(root) NOPASSWD: $cmd -PDList -aALL -NoLog",
		"CHECK_RAID ALL=(root) NOPASSWD: $cmd -LdInfo -Lall -aALL -NoLog",
		"CHECK_RAID ALL=(root) NOPASSWD: $cmd -AdpBbuCmd -GetBbuStatus -aALL -NoLog",
	);
}

# parse physical devices
sub parse_pd {
	my $this = shift;

	my (@pd, %pd);
	my $rc = -1;
	my $fh = $this->cmd('pdlist');
	while (<$fh>) {
		if (my($s) = /Device Id: (\S+)/) {
			push(@pd, { %pd }) if %pd;
			%pd = ( dev => $s, state => undef, name => undef, predictive => undef );
			next;
		}

		if (my($s) = /Firmware state: (.+)/) {
			# strip the extra state:
			# 'Hotspare, Spun Up'
			# 'Hotspare, Spun down'
			# 'Online, Spun Up'
			# 'Online, Spun Up'
			# 'Online, Spun down'
			# 'Unconfigured(bad)'
			# 'Unconfigured(good), Spun Up'
			# 'Unconfigured(good), Spun down'
			$s =~ s/,.+//;
			$pd{state} = $s;

			if (defined($pd{predictive})) {
				$pd{state} = $pd{predictive};
			}
			next;
		}

		if (my($s) = /Predictive Failure Count: (\d+)/) {
			if ($s > 0) {
				$pd{predictive} = 'Predictive';
			}
			next;
		}

		if (my($s) = /Inquiry Data: (.+)/) {
			# trim some spaces
			$s =~ s/\s+/ /g; $s =~ s/^\s+|\s+$//g;
			$pd{name} = $s;
			next;
		}

		if (my($s) = /Exit Code: (\d+x\d+)/) {
			$rc = hex($s);
		}
		else {
			$rc = 0;
		}
	}
	push(@pd, { %pd }) if %pd;

	$this->critical unless close $fh;
	$this->critical if $rc;

	return \@pd;
}

sub parse_ld {
	my $this = shift;

	my (@ld, %ld);
	my $rc = -1;
	my $fh = $this->cmd('ldinfo');
	while (<$fh>) {
		if (my($drive_id, $target_id) = /Virtual (?:Disk|Drive)\s*:\s*(\d+)\s*\(Target Id:\s*(\d+)\)/i) {
			push(@ld, { %ld }) if %ld;
			# Default to DriveID:TargetID in case no Name is given ...
			%ld = ( name => "DISK$drive_id.$target_id", state => undef );
			next;
		}

		if (my($name) = /Name\s*:\s*(\S+)/) {
			# Add a symbolic name, if given
			$ld{name} = $name;
			next;
		}

		if (my($s) = /Virtual Drive Type\s*:\s*(\S+)/) {
			$ld{type} = $s;
			next;
		}

		if (my($s) = /State\s*:\s*(\S+)/) {
			$ld{state} = $s;
			next;
		}

		if (my($s) = /Default Cache Policy\s*:\s*(.+)/) {
			$ld{default_cache} = [split /,\s*/, $s];
			next;
		}

		if (my($s) = /Current Cache Policy\s*:\s*(.+)/) {
			$ld{current_cache} = [split /,\s*/, $s];
			next;
		}

		if (my($s) = /Exit Code: (\d+x\d+)/) {
			$rc = hex($s);
		} else {
			$rc = 0;
		}
	}
	push(@ld, { %ld }) if %ld;

	$this->critical unless close $fh;
	$this->critical if $rc;

	return \@ld;
}

# check battery
sub parse_bbu {
	my $this = shift;

	return undef unless $this->bbu_monitoring;

	my %default_bbu = (
		name => undef, state => '???', charging_status => '???', missing => undef,
		learn_requested => undef, replacement_required => undef,
		learn_cycle_requested => undef, learn_cycle_active => '???',
		pack_will_fail => undef, temperature => undef, temperature_state => undef,
		voltage => undef, voltage_state => undef
	);

	my (@bbu, %bbu);
	my $fh = $this->cmd('battery');
	while (<$fh>) {
		# handle when bbu status get gives an error. see issue #32
		if (my($s) = /Get BBU Status Failed/) {
			last;
		}

		if (my($s) = /BBU status for Adapter: (.+)/) {
			push(@bbu, { %bbu }) if %bbu;
			%bbu = %default_bbu;
			$bbu{name} = $s;
			next;
		}
#=cut
# according to current sample data, Battery State never has value
		if (my($s) = /Battery State\s*: ?(.*)/i) {
			if (!$s) { $s = 'Faulty'; };
			$bbu{state} = $s;
			next;
		}
#=cut
		if (my($s) = /Charging Status\s*: (\w*)/) {
			$bbu{charging_status} = $s;
			next;
		}
		if (my($s) = /Battery Pack Missing\s*: (\w*)/) {
			$bbu{missing} = $s;
			next;
		}
		if (my($s) = /Battery Replacement required\s*: (\w*)/) {
			$bbu{replacement_required} = $s;
			next;
		}
		if (my($s) = /Learn Cycle Requested\s*: (\w*)/) {
			$bbu{learn_cycle_requested} = $s;
			next;
		}
		if (my($s) = /Learn Cycle Active\s*: (\w*)/) {
			$bbu{learn_cycle_active} = $s;
			next;
		}
		if (my($s) = /Pack is about to fail & should be replaced\s*: (\w*)/) {
			$bbu{pack_will_fail} = $s;
			next;
		}
		# Temperature: 18 C
		if (my($s) = /Temperature: (\d+) C/) {
			$bbu{temperature} = $s;
			next;
		}
		# Temperature : OK
		if (my($s) = /  Temperature\s*: (\w*)/) {
			$bbu{temperature_state} = $s;
			next;
		}
		# Voltage: 4074 mV
		if (my($s) = /Voltage: (\d+) mV/) {
			$bbu{voltage} = $s;
			next;
		}
		# Voltage : OK
		if (my($s) = /Voltage\s*: (\w*)/) {
			$bbu{voltage_state} = $s;
			next;
		}

	}
	$this->critical unless close $fh;

	push(@bbu, { %bbu }) if %bbu;

	return \@bbu;
}

sub parse {
	my $this = shift;

	my $pd = $this->parse_pd;
	my $ld = $this->parse_ld;
	my $bbu = $this->parse_bbu;

	my @devs = @$pd if $pd;
	my @vols = @$ld if $ld;
	my @bats = @$bbu if $bbu;

	return {
		logical => $ld,
		physical => $pd,
		battery => $bbu,
	};
}

sub check {
	my $this = shift;

	my $c = $this->parse;

	my @vstatus;
	foreach my $vol (@{$c->{logical}}) {
		# skip CacheCade for now. #91
		if ($vol->{type} && $vol->{type} eq 'CacheCade') {
			next;
		}

		push(@vstatus, sprintf "%s:%s", $vol->{name}, $vol->{state});
		if ($vol->{state} ne 'Optimal') {
			$this->critical;
		}

		# check cache policy, #65
		my @wt = grep { /WriteThrough/ } @{$vol->{current_cache}};
		if (@wt) {
			my @default = grep { /WriteThrough/ } @{$vol->{default_cache}};
			# alert if WriteThrough is configured in default
			$this->cache_fail unless @default;
			push(@vstatus, "WriteCache:DISABLED");
		}
	}

	my %dstatus;
	foreach my $dev (@{$c->{physical}}) {
		if ($dev->{state} eq 'Online' || $dev->{state} eq 'Hotspare' || $dev->{state} eq 'Unconfigured(good)' || $dev->{state} eq 'JBOD') {
			push(@{$dstatus{$dev->{state}}}, sprintf "%02d", $dev->{dev});

		} else {
			$this->critical;
			# TODO: process other statuses
			push(@{$dstatus{$dev->{state}}}, sprintf "%02d (%s)", $dev->{dev}, $dev->{name});
		}
	}

	my (%bstatus, @bpdata, @blongout);
	foreach my $bat (@{$c->{battery}}) {
		if ($bat->{state} !~ /^(Operational|Optimal)$/) {
			# BBU learn cycle in progress.
			if ($bat->{charging_status} =~ /^(Charging|Discharging)$/ && $bat->{learn_cycle_active} eq 'Yes') {
				$this->bbulearn;
			} else {
				$this->critical;
			}
		}
		if ($bat->{missing} ne 'No') {
			$this->critical;
		}
		if ($bat->{replacement_required} ne 'No') {
			$this->critical;
		}
		if (defined($bat->{pack_will_fail}) && $bat->{pack_will_fail} ne 'No') {
			$this->critical;
		}
		if ($bat->{temperature_state} ne 'OK') {
			$this->critical;
		}
		if ($bat->{voltage_state} ne 'OK') {
			$this->critical;
		}

		# Short output.
		#
		# CRITICAL: megacli:[Volumes(1): NoName:Optimal; Devices(2): 06,07=Online; Batteries(1): 0=Non Operational]
		push(@{$bstatus{$bat->{state}}}, sprintf "%d", $bat->{name});
		# Performance data.
		# Return current battery temparature & voltage.
		#
		# Battery0=18;4074
		push(@bpdata, sprintf "Battery%s_T=%s;;;; Battery%s_V=%s;;;;", $bat->{name}, $bat->{temperature}, $bat->{name}, $bat->{voltage});

		# Long output.
		# Detailed plugin output.
		#
		# Battery0:
		#  - State: Non Operational
		#  - Missing: No
		#  - Replacement required: Yes
		#  - About to fail: No
		#  - Temperature: OK (18 °C)
		#  - Voltage: OK (4015 mV)
		push(@blongout, join("\n", grep {/./}
			"Battery$bat->{name}:",
			" - State: $bat->{state}",
			" - Charging status: $bat->{charging_status}",
			" - Learn cycle requested: $bat->{learn_cycle_requested}",
			" - Learn cycle active: $bat->{learn_cycle_active}",
			" - Missing: $bat->{missing}",
			" - Replacement required: $bat->{replacement_required}",
			defined($bat->{pack_will_fail}) ? " - About to fail: $bat->{pack_will_fail}" : "",
			" - Temperature: $bat->{temperature_state} ($bat->{temperature} C)",
			" - Voltage: $bat->{voltage_state} ($bat->{voltage} mV)",
		));
	}

	my @cstatus;
	push(@cstatus, 'Volumes(' . ($#{$c->{logical}} + 1) . '): ' . join(',', @vstatus));
	push(@cstatus, 'Devices(' . ($#{$c->{physical}} + 1) . '): ' . $this->join_status(\%dstatus));
	push(@cstatus, 'Batteries(' . ($#{$c->{battery}} + 1) . '): ' . $this->join_status(\%bstatus)) if @{$c->{battery}};
	my @status = join('; ', @cstatus);

	my @pdata;
	push(@pdata,
		join('\n', @bpdata)
	);
	my @longout;
	push(@longout,
		join('\n', @blongout)
	);
	return unless @status;

	# denote this plugin as ran ok
	$this->ok;

	$this->message(join(' ', @status));
	$this->perfdata(join(' ', @pdata));
	$this->longoutput(join(' ', @longout));
}

package lsvg;
# AIX LVM
use base 'plugin';

# register
# Status: broken (no test data)
#push(@utils::plugins, __PACKAGE__);

sub program_names {
	__PACKAGE__;
}

sub commands {
	{
		'lsvg' => ['-|', '@CMD'],
		'lsvg list' => ['-|', '@CMD', '-l', '$vg'],
	}
}

sub sudo {
	my ($this, $deep) = @_;
	# quick check when running check
	return 1 unless $deep;

	my $cmd = $this->{program};
	(
		"CHECK_RAID ALL=(root) NOPASSWD: $cmd",
		"CHECK_RAID ALL=(root) NOPASSWD: $cmd -l *",
	)
}

sub check {
	my $this = shift;

	# status messages pushed here
	my @status;

	my @vg;
	my $fh = $this->cmd('lsvg');
	while (<$fh>) {
		chomp;
		push @vg, $_;
	}
	close $fh;

	foreach my $vg (@vg) {
		next unless $this->valid($vg); # skip entire VG

		my $fh = $this->cmd('lsvg list', { '$vg' => $vg });

		while (<$fh>) {
			my @f = split /\s/;
			my ($n, $s) = ($f[0], $f[5]);
			next if (!$this->valid($n) or !$s);
			next if ($f[3] eq $f[2]); # not a mirrored LV

			if ($s =~ m#open/(\S+)#i) {
				$s = $1;
				if ($s ne 'syncd') {
					$this->critical;
				}
				push(@status, "lvm:$n:$s");
			}
		}
		close $fh;
	}

	return unless @status;

	$this->message(join(', ', @status));
}

package ips;
# Serveraid IPS
# Tested on IBM xSeries 346 servers with Adaptec ServeRAID 7k controllers.
# The ipssend version was v7.12.14.
use base 'plugin';

# register
push(@utils::plugins, __PACKAGE__);

sub program_names {
	qw(ipssend);
}

sub commands {
	{
		'list logical drive' => ['-|', '@CMD', 'GETCONFIG', '1', 'LD'],
	}
}

sub sudo {
	my ($this, $deep) = @_;
	# quick check when running check
	return 1 unless $deep;

	my $cmd = $this->{program};
	"CHECK_RAID ALL=(root) NOPASSWD: $cmd getconfig 1 LD"
}

sub check {
	my $this = shift;

	# status messages pushed here
	my @status;

	my $n;
	my $fh = $this->cmd('list logical drive');
	while (<$fh>) {
		if (/drive number (\d+)/i){
			$n = $1;
			next;
		}

		next unless $n;
		next unless $this->valid($n);
		next unless (my($s, $c) = /Status .*: (\S+)\s+(\S+)/);

		if ($c =~ /SYN|RBL/i) { # resynching
			$this->resync;
		} elsif ($c !~ /OKY/i) { # not OK
			$this->critical;
		}

		push(@status, "$n:$s");
	}
	close $fh;

	return unless @status;

	$this->ok->message(join(', ', @status));
}

package aaccli;
# Adaptec ServeRAID
use base 'plugin';

# register
push(@utils::plugins, __PACKAGE__);

sub program_names {
	__PACKAGE__;
}

sub commands {
	{
		'container list' => ['=', '@CMD'],
	}
}

sub sudo {
	my ($this, $deep) = @_;
	# quick check when running check
	return 1 unless $deep;

	my $cmd = $this->{program};
	"CHECK_RAID ALL=(root) NOPASSWD: $cmd container list /full"
}

sub check {
	my $this = shift;

	# status messages pushed here
	my @status;

	my $write = "";
	$write .= "open aac0\n";
	$write .= "container list /full\n";
	$write .= "exit\n";
	my $read = $this->cmd('container list', \$write);

#File foo receiving all output.
#
#AAC0>
#COMMAND: container list /full=TRUE
#Executing: container list /full=TRUE
#Num          Total  Oth Stripe          Scsi   Partition                                       Creation
#Label Type   Size   Ctr Size   Usage   C:ID:L Offset:Size   State   RO Lk Task    Done%  Ent Date   Time
#----- ------ ------ --- ------ ------- ------ ------------- ------- -- -- ------- ------ --- ------ --------
# 0    Mirror 74.5GB            Open    0:02:0 64.0KB:74.5GB Normal                        0  051006 13:48:54
# /dev/sda             Auth             0:03:0 64.0KB:74.5GB Normal                        1  051006 13:48:54
#
#
#AAC0>
#COMMAND: logfile end
#Executing: logfile end
	while (<$read>) {
		if (my($dsk, $stat) = /(\d:\d\d?:\d+)\s+\S+:\S+\s+(\S+)/) {
			next unless $this->valid($dsk);
			$dsk =~ s#:#/#g;
			next unless $this->valid($dsk);

			push(@status, "$dsk:$stat");

			$this->critical if ($stat eq "Broken");
			$this->warning if ($stat eq "Rebuild");
			$this->warning if ($stat eq "Bld/Vfy");
			$this->critical if ($stat eq "Missing");
			if ($stat eq "Verify") {
				$this->resync;
			}
			$this->warning if ($stat eq "VfyRepl");
		}
	}
	close $read;

	return unless @status;

	$this->message(join(', ', @status));
}

package afacli;
# Adaptec AACRAID
use base 'plugin';

# register
push(@utils::plugins, __PACKAGE__);

sub program_names {
	__PACKAGE__;
}

sub commands {
	{
		'container list' => ['=', '@CMD'],
	}
}

sub check {
	my $this = shift;

	# status messages pushed here
	my @status;

	my $write = "";
	$write .= "open afa0\n";
	$write .= "container list /full\n";
	$write .= "exit\n";

	my $read = $this->cmd('container list', \$write);
	while (<$read>) {
		# 0    Mirror  465GB            Valid   0:00:0 64.0KB: 465GB Normal                        0  032511 17:55:06
		# /dev/sda             root             0:01:0 64.0KB: 465GB Normal                        1  032511 17:55:06
		if (my($dsk, $stat) = /(\d:\d\d?:\d+)\s+\S+:\s?\S+\s+(\S+)/) {
			next unless $this->valid($dsk);
			$dsk =~ s#:#/#g;
			next unless $this->valid($dsk);
			push(@status, "$dsk:$stat");

			$this->critical if ($stat eq "Broken");
			$this->warning if ($stat eq "Rebuild");
			$this->warning if ($stat eq "Bld/Vfy");
			$this->critical if ($stat eq "Missing");
			if ($stat eq "Verify") {
				$this->resync;
			}
			$this->warning if ($stat eq "VfyRepl");
		}
	}
	close $read;

	return unless @status;

	$this->ok->message(join(', ', @status));
}

package mpt;
use base 'plugin';

# LSILogic MPT ServeRAID

# register
push(@utils::plugins, __PACKAGE__);

sub program_names {
	qw(mpt-status);
}

sub commands {
	{
		'get_controller_no' => ['-|', '@CMD', '-p'],
		'status' => ['-|', '@CMD', '-i', '$id'],
		'sync status' => ['-|', '@CMD', '-n'],
	}
}

sub sudo {
	my ($this, $deep) = @_;
	# quick check when running check
	return 1 unless $deep;

	my $cmd = $this->{program};
	(
	"CHECK_RAID ALL=(root) NOPASSWD: $cmd -i [0-9]",
	"CHECK_RAID ALL=(root) NOPASSWD: $cmd -i [1-9][0-9]",
	"CHECK_RAID ALL=(root) NOPASSWD: $cmd -n",
	"CHECK_RAID ALL=(root) NOPASSWD: $cmd -p",
	);
}

sub active ($) {
	my ($this) = @_;

	# return if parent said NO
	my $res = $this->SUPER::active(@_);
	return $res unless $res;

	# there should be a controller. #95
	my $id = $this->get_controller;
	return defined($id);
}

# get controller from mpt-status -p
# FIXME: could there be multiple controllers?
sub get_controller {
	my $this = shift;

	my $fh = $this->cmd('get_controller_no');
	my $id;
	while (<$fh>) {
		chomp;
		if (/^Found.*id=(\d{1,2}),.*/) {
			$id = $1;
			last;
		}
	}
	close $fh;

	return $id;
}

sub parse {
	my ($this, $id) = @_;

	my (%ld, %pd);

	my $fh = $this->cmd('status', { '$id' => $id });

	my %VolumeTypesHuman = (
		IS => 'RAID-0',
		IME => 'RAID-1E',
		IM => 'RAID-1',
	);

	while (<$fh>) {
		chomp;
		# mpt-status.c __print_volume_classic
		# ioc0 vol_id 0 type IM, 2 phy, 136 GB, state OPTIMAL, flags ENABLED
		if (my($vioc, $vol_id, $type, $disks, $vol_size, $vol_state, $vol_flags) =
			/^ioc(\d+)\s+ vol_id\s(\d+)\s type\s(\S+),\s (\d+)\sphy,\s (\d+)\sGB,\s state\s(\S+),\s flags\s(.+)/x) {
			$ld{$vol_id} = {
				ioc => int($vioc),
				vol_id => int($vol_id),
				# one of: IS, IME, IM
				vol_type => $type,
				raid_level => $VolumeTypesHuman{$type},
				phy_disks => int($disks),
				size => int($vol_size),
				# one of: OPTIMAL, DEGRADED, FAILED, UNKNOWN
				status => $vol_state,
				# array of: ENABLED, QUIESCED, RESYNC_IN_PROGRESS, VOLUME_INACTIVE or NONE
				flags => [ split ' ', $vol_flags ],
			};
		}

		# ./include/lsi/mpi_cnfg.h
		# typedef struct _RAID_PHYS_DISK_INQUIRY_DATA
		# {
		#   U8 VendorID[8];            /* 00h */
		#   U8 ProductID[16];          /* 08h */
		#   U8 ProductRevLevel[4];     /* 18h */
		#   U8 Info[32];               /* 1Ch */
		# }
		# mpt-status.c __print_physdisk_classic
		# ioc0 phy 0 scsi_id 0 IBM-ESXS PYH146C3-ETS10FN RXQN, 136 GB, state ONLINE, flags NONE
		# ioc0 phy 0 scsi_id 1 ATA      ST3808110AS      J   , 74 GB, state ONLINE, flags NONE
		# ioc0 phy 0 scsi_id 1 ATA      Hitachi HUA72101 AJ0A, 931 GB, state ONLINE, flags NONE
		elsif (my($pioc, $num, $phy_id, $vendor, $prod_id, $rev, $size, $state, $flags) =
			/^ioc(\d+)\s+ phy\s(\d+)\s scsi_id\s(\d+)\s (.{8})\s+(.{16})\s+(.{4})\s*,\s (\d+)\sGB,\s state\s(\S+),\s flags\s(.+)/x) {
			$pd{$num} = {
				ioc => int($pioc),
				num => int($num),
				phy_id => int($phy_id),
				vendor => $vendor,
				prod_id => $prod_id,
				rev => $rev,
				size => int($size),
				# one of: ONLINE, MISSING, NOT_COMPATIBLE, FAILED, INITIALIZING, OFFLINE_REQUESTED, FAILED_REQUESTED, OTHER_OFFLINE, UNKNOWN
				status => $state,
				# array of: OUT_OF_SYNC, QUIESCED or NONE
				flags => [ split ' ', $flags ],
			};
		} else {
			warn "mpt unparsed: [$_]";
			$this->unknown;
		}
	}
	close $fh;

	# extra parse, if mpt-status has -n flag, can process also resync state
	# TODO: if -n becames default can do this all in one run
	my $resyncing = grep {/RESYNC_IN_PROGRESS/} map { @{$_->{flags}} } values %ld;
	if ($resyncing) {
		my $fh = $this->cmd('sync status');
		while (<$fh>) {
			if (/^ioc:\d+/) {
				# ignore
			}
			# mpt-status.c GetResyncPercentage
			# scsi_id:0 70%
			elsif (my($scsi_id, $percent) = /^scsi_id:(\d+) (\d+)%/) {
				$pd{$scsi_id}{resync} = int($percent);
			} else {
				warn "mpt unparsed: [$_]";
				$this->unknown;
			}
		}
		close $fh;
	}

	return {
		'logical' => { %ld },
		'physical' => { %pd },
	};
}

sub check {
	my $this = shift;

	# status messages pushed here
	my @status;

	my $id = $this->get_controller;
	my $status = $this->parse($id);

	# process logical units
	while (my($d, $u) = each %{$status->{logical}}) {
		next unless $this->valid($d);

		my $s = $u->{status};
		if ($s =~ /INITIAL|INACTIVE/) {
			$this->warning;
		} elsif ($s =~ /RESYNC/) {
			$this->resync;
		} elsif ($s =~ /DEGRADED|FAILED/) {
			$this->critical;
		} elsif ($s !~ /ONLINE|OPTIMAL/) {
			$this->unknown;
		}

		# FIXME: this resync_in_progress is separate state of same as value in status?
		if (grep { /RESYNC_IN_PROGRESS/ } @{$u->{flags}}) {
			# find matching disks
			my @disks = grep {$_->{ioc} eq $u->{ioc} } values %{$status->{physical}};
			# collect percent for each disk
			my @percent = map { $_->{resync}.'%'} @disks;
			$s .= ' RESYNCING: '.join('/', @percent);
		}
		push(@status, "Volume $d ($u->{raid_level}, $u->{phy_disks} disks, $u->{size} GiB): $s");
	}

	# process physical units
	while (my($d, $u) = each %{$status->{physical}}) {
		my $s = $u->{status};
		# remove uninteresting flags
		my @flags = grep {!/NONE/} @{$u->{flags}};

		# skip print if nothing in flags and disk is ONLINE
		next unless @flags and $s eq 'ONLINE';

		$s .= ' ' . join(' ', @flags);
		push(@status, "Disk $d ($u->{size} GiB):$s");
		$this->critical;
	}

	return unless @status;

	$this->ok->message(join(', ', @status));
}

package megaraid;
# MegaRAID
use base 'plugin';

# register
# Status: BROKEN: no test data
#push(@utils::plugins, __PACKAGE__);

sub sudo {
	my $cat = utils::which('cat');

	my @sudo;
	foreach my $mr (</proc/mega*/*/raiddrives*>) {
		push(@sudo, "CHECK_RAID ALL=(root) NOPASSWD: $cat $mr") if -d $mr;
	}

	@sudo;
}

sub check {
	my $this = shift;
	# status messages pushed here
	my @status;

	foreach my $f (</proc/megaraid/*/raiddrives*>) { # vim/
		my $fh;
		if (-r $f) {
			open $fh, '<', $f or next;
=cut
		} else {
			my @CMD = ($cat, $f);
			unshift(@CMD, $sudo) if $> and $sudo;
			open($fh , '-|', @CMD) or next;
=cut
		}
		my ($n) = $f =~ m{/proc/megaraid/([^/]+)};
		while (<$fh>) {
			if (my($s) = /logical drive\s*:\s*\d+.*, state\s*:\s*(\S+)/i) {
				if ($s ne 'optimal') {
					$this->critical;
				}
				push(@status, "$n: $s");
				last;
			}
		}
		close $fh;
	}

	return unless @status;

	$this->message(join(', ', @status));
}

package gdth;
# Linux gdth RAID
use base 'plugin';

# register
push(@utils::plugins, __PACKAGE__);

sub commands {
	{
		'proc' => ['<', '/proc/scsi/gdth'],
		'proc entry' => ['<', '/proc/scsi/gdth/$controller'],
	}
}

sub active ($) {
	my ($this) = @_;
	return -d $this->{commands}{proc}[1];
}

sub parse {
	my $this = shift;

	my $fh = $this->cmd('proc');
	my @c = grep { !/^\./ } readdir($fh);
	close($fh);

	my %c;
	for my $c (@c) {
		my (%ld, %ad, %pd, %l, %a, %p, $section);

		my $fh = $this->cmd('proc entry', { '$controller' => $c });
		while (<$fh>) {
			chomp;

			# new section start
			if (my($s) = /^(\w.+):$/) {
				$section = $s;
				%a = %l = %p = ();
				next;
			}

			# skip unknown sections
			next unless /^\s/ or /^$/;

			# process each section
			if ($section eq 'Driver Parameters') {
				# nothing useful
			} elsif ($section eq 'Disk Array Controller Information') {
				# nothing useful
			} elsif ($section eq 'Physical Devices') {
				# Chn/ID/LUN:        B/05/0          Name:           FUJITSU MAX3147NC       0104
				# Capacity [MB]:     140239          To Log. Drive:  5
				# Retries:           1               Reassigns:      0
				# Grown Defects:     1

				if (my($id, $n, $rv) = m{^\s+Chn/ID/LUN:\s+(\S+)\s+Name:\s+(.+)(.{4})$}) {
					$n =~ s/\s+$//;
					$p{id} = $id;
					$p{name} = $n;
					$p{revision} = $rv;
				} elsif (my($unit, $c, $d) = m/^\s+Capacity\s\[(.B)\]:\s+(\d+)\s+To Log\. Drive:\s+(\d+|--)/) {
					$p{capacity} = int($c);
					$p{capacity_unit} = $unit;
					$p{drive} = $d;
				} elsif (my($r, $ra) = m/^\s+Retries:\s+(\d+)\s+Reassigns:\s+(\d+)/) {
					$p{retries} = int($r);
					$p{reassigns} = int($ra);
				} elsif (my($gd) = m/^\s+Grown Defects:\s+(\d+)/) {
					$p{defects} = int($gd);
				} elsif (/^$/) {
					if ($p{capacity} == 0 and $p{name} =~ /SCA HSBP/) {
						# HSBP is not a disk, so do not consider this an error
						# http://support.gateway.com/s/Servers/COMPO/MOTHERBD/4000832/4000832si69.shtml
						# Raid Hot Swap Backplane driver (recognized as "ESG-SHV SCA HSBP M16 SCSI Processor Device")
						# Chn/ID/LUN:    B/06/0          Name:           ESG-SHV SCA HSBP M16    0.05
						# Capacity [MB]: 0               To Log. Drive:  --
						next;
					}

					$pd{$p{id}} = { %p };
				} else {
					warn "[$section] [$_]";
					$this->unknown;
				}

			} elsif ($section eq 'Logical Drives') {
				# Number:              3               Status:         ok
				# Slave Number:        15              Status:         ok (older kernels)
				# Capacity [MB]:       69974           Type:           Disk
				if (my($num, $s) = m/^\s+(?:Slave )?Number:\s+(\d+)\s+Status:\s+(\S+)/) {
					$l{number} = int($num);
					$l{status} = $s;
				} elsif (my($unit, $c, $t) = m/^\s+Capacity\s\[(.B)\]:\s+(\d+)\s+Type:\s+(\S+)/) {
					$l{capacity} = "$c $unit";
					$l{type} = $t;
				} elsif (my($md, $id) = m/^\s+Missing Drv\.:\s+(\d+)\s+Invalid Drv\.:\s+(\d+|--)/) {
					$l{missing} = int($md);
					$l{invalid} = int($id);
				} elsif (my($n) = m/^\s+To Array Drv\.:\s+(\d+|--)/) {
					$l{array} = $n;
				} elsif (/^$/) {
					$ld{$l{number}} = { %l };
				} else {
					warn "[$section] [$_]";
					$this->unknown;
				}

			} elsif ($section eq 'Array Drives') {
				# Number:        0               Status:         fail
				# Capacity [MB]: 349872          Type:           RAID-5
				if (my($num, $s) = m/^\s+Number:\s+(\d+)\s+Status:\s+(\S+)/) {
					$a{number} = int($num);
					$a{status} = $s;
				} elsif (my($unit, $c, $t) = m/^\s+Capacity\s\[(.B)\]:\s+(\d+)\s+Type:\s+(\S+)/) {
					$a{capacity} = "$c $unit";
					$a{type} = $t;
				} elsif (/^(?: --)?$/) {
					if (%a) {
						$ad{$a{number}} = { %a };
					}
				} else {
					warn "[$section] [$_]";
					$this->unknown;
				}

			} elsif ($section eq 'Host Drives') {
				# nothing useful
			} elsif ($section eq 'Controller Events') {
				# nothing useful
			}
		}
		close($fh);

		$c{$c} = { id => $c, array => { %ad }, logical => { %ld }, physical => { %pd } };
	}

	return \%c;
}

sub check {
	my $this = shift;

	# status messages pushed here
	my @status;

	my $controllers = $this->parse;

	# process each controller separately
	for my $c (values %$controllers) {
		# array status
		my @ad;
		for my $n (sort {$a cmp $b} keys %{$c->{array}}) {
			my $ad = $c->{array}->{$n};
			if ($ad->{status} ne "ready") {
				$this->critical;
			}
			push(@ad, "Array $ad->{number}($ad->{type}) $ad->{status}");
		}

		# older raids have no Array drives, Look into Logical Drives for type!=Disk
		unless (@ad) {
			for my $n (sort {$a cmp $b} keys %{$c->{logical}}) {
				my $ld = $c->{logical}->{$n};
				if ($ld->{type} eq "Disk") {
					next;
				}

				# emulate Array Drive
				my $s = "Array($ld->{type}) $ld->{status}";
				# check for missing drives
				if ($ld->{missing} > 0) {
					$this->warning;
					$s .= " ($ld->{missing} missing drives)";
				}

				push(@ad, $s);
			}
		}

		# logical drive status
		my %ld;
		for my $n (sort {$a cmp $b} keys %{$c->{logical}}) {
			my $ld = $c->{logical}->{$n};
			if ($ld->{status} ne "ok") {
				$this->critical;
			}
			push(@{$ld{$ld->{status}}}, $ld->{number});
		}

		# physical drive status
		my @pd;
		for my $n (sort {$a cmp $b} keys %{$c->{physical}}) {
			my $pd = $c->{physical}->{$n};

			my @ds;
			# TODO: make tresholds configurable
			if ($pd->{defects} > 300) {
				$this->critical;
				push(@ds, "grown defects critical: $pd->{defects}");
			} elsif ($pd->{defects} > 30) {
				$this->warning;
				push(@ds, "grown defects warning: $pd->{defects}");
			}

			# report disk being not assigned
			if ($pd->{drive} eq '--') {
				push(@ds, "not assigned");
			}

			if (@ds) {
				push(@pd, "Disk $pd->{id}($pd->{name}) ". join(', ', @ds));
			}
		}

		my @cd;
		push(@cd, @ad) if @ad;
		push(@cd, "Logical Drives: ". $this->join_status(\%ld));
		push(@cd, @pd) if @pd;
		push(@status, "Controller $c->{id}: ". join('; ', @cd));
	}

	return unless @status;

	# denote this plugin as ran ok
	$this->ok;

	$this->message(join('; ', @status));
}

package dpt_i2o;
use base 'plugin';

# register
push(@utils::plugins, __PACKAGE__);

sub commands {
	{
		'proc' => ['<', '/proc/scsi/dpt_i2o'],
		'proc entry' => ['<', '/proc/scsi/dpt_i2o/$controller'],
	}
}

sub active ($) {
	my ($this) = @_;
	return -d $this->{commands}{proc}[1];
}

sub check {
	my $this = shift;
	# status messages pushed here
	my @status;

	my $fh = $this->cmd('proc');
	my @c = grep { !/^\./ } readdir($fh);
	close($fh);

	# TODO: check for failed disks!
	for my $c (@c) {
		my $fh = $this->cmd('proc entry', { '$controller' => $c });

		while (<$fh>) {
			if (my ($c, $t, $l, $s) = m/TID=\d+,\s+\(Channel=(\d+),\s+Target=(\d+),\s+Lun=(\d+)\)\s+\((\S+)\)/) {
				if ($s ne "online") {
					$this->critical;
				}
				push(@status, "$c,$t,$l:$s");
			}
		}
		close($fh);
	}

	return unless @status;

	# denote this plugin as ran ok
	$this->ok;

	$this->message(join(', ', @status));
}

package tw_cli;
# tw_cli(8) is a Command Line Interface Storage Management Software for
# AMCC/3ware ATA RAID Controller(s).
# Owned by LSI currently: https://en.wikipedia.org/wiki/3ware
#
# http://www.cyberciti.biz/files/tw_cli.8.html
use base 'plugin';

# register
push(@utils::plugins, __PACKAGE__);

sub program_names {
	qw(tw_cli-9xxx tw_cli tw-cli);
}

sub commands {
	{
		'info' => ['-|', '@CMD', 'info'],
		'unitstatus' => ['-|', '@CMD', 'info', '$controller', 'unitstatus'],
		'drivestatus' => ['-|', '@CMD', 'info', '$controller', 'drivestatus'],
	}
}

sub sudo {
	my ($this, $deep) = @_;
	# quick check when running check
	return 1 unless $deep;

	my $cmd = $this->{program};
	"CHECK_RAID ALL=(root) NOPASSWD: $cmd info*";
}

sub trim { my $s = shift; $s =~ s/^\s+|\s+$//g; return $s };

sub to_i {
	my $i = shift;
	return $i if $i !~ /^\d+$/;
	return int($i);
}

sub parse {
	my $this = shift;

	my (%c);
	# scan controllers
	my $fh = $this->cmd('info');
	while (<$fh>) {
		if (my($ctl, $model, $ports, $drives, $units, $notopt, $rrate, $vrate, $bbu) = m{^
			(c\d+)\s+   # Controller
			(\S+)\s+    # Model
			(\d+)\s+    # (V)Ports
			(\d+)\s+    # Drives
			(\d+)\s+    # Units
			(\d+)\s+    # NotOpt: Not Optional
						# Not Optimal refers to any state except OK and VERIFYING.
						# Other states include INITIALIZING, INIT-PAUSED,
						# REBUILDING, REBUILD-PAUSED, DEGRADED, MIGRATING,
						# MIGRATE-PAUSED, RECOVERY, INOPERABLE, and UNKNOWN.
			(\d+)\s+    # RRate: Rebuild Rate
			(\d+|-)\s+  # VRate: Verify Rate
			(\S+|-)?    # BBU
		}x) {
			$c{$ctl} = {
				model => $model,
				ports => int($ports),
				drives => int($drives),
				units => int($units),
				optimal => int(!$notopt),
				rrate => int($rrate),
				vrate => to_i($vrate),
				bbu => $bbu,
			};
		}
	}
	close $fh;

	# no controllers? skip early
	return unless %c;

	for my $c (keys %c) {
		# get each unit on controllers
		$fh = $this->cmd('unitstatus', { '$controller' => $c });
		while (<$fh>) {
			if (my($u, $type, $status, $p_rebuild, $p_vim, $strip, $size, $cache, $avrify) = m{^
				(u\d+)\s+ # Unit
				(\S+)\s+  # UnitType
				(\S+)\s+  # Status
				(\S+)\s+  # %RCmpl: The %RCompl reports the percent completion
						  # of the unit's Rebuild, if this task is in progress.
				(\S+)\s+  # %V/I/M: The %V/I/M reports the percent completion
						  # of the unit's Verify, Initialize, or Migrate,
						  # if one of these are in progress.
				(\S+)\s+  # Strip
				(\S+)\s+  # Size(GB)
				(\S+)\s+  # Cache
				(\S+)     # AVrify
			}x) {
				$c{$c}{unitstatus}{$u} = {
					type => $type,
					status => $status,
					rebuild_percent => $p_rebuild,
					vim_percent => $p_vim,
					strip => $strip,
					size => $size,
					cache => $cache,
					avrify => $avrify,
				};
				next;
			}

			if (m{^u\d+}) {
				$this->unknown;
				warn "unparsed: [$_]";
			}
		}
		close $fh;

		# get individual disk status
		$fh = $this->cmd('drivestatus', { '$controller' => $c });
		# common regexp
		my $r = qr{^
			(p\d+)\s+       # Port
			(\S+)\s+        # Status
			(\S+)\s+        # Unit
			([\d.]+\s[TG]B|-)\s+ # Size
		}x;

		while (<$fh>) {
			# skip empty line
			next if /^$/;

			# Detect version
			if (/^Port/) {
				# <=9.5.1: Blocks Serial
				$r .= qr{
					(\S+)\s+  # Blocks
					(.+)      # Serial
				}x;
				next;
			} elsif (/^VPort/) {
				# >=9.5.2: Type Phy Encl-Slot Model
				$r .= qr{
					(\S+)\s+ # Type
					(\S+)\s+ # Phy
					(\S+)\s+ # Encl-Slot
					(.+)     # Model
				}x;
				next;
			}

			if (my($port, $status, $unit, $size, @rest) = ($_ =~ $r)) {
				# do not report disks not present
				# tw_cli 9.5.2 and above do not list these at all
				next if $status eq 'NOT-PRESENT';
				my %p;

				if (@rest <= 2) {
					my ($blocks, $serial) = @rest;
					%p = (
						blocks => to_i($blocks),
						serial => trim($serial),
					);
				} else {
					my ($type, $phy, $encl, $model) = @rest;
					%p = (
						type => $type,
						phy => to_i($phy),
						encl => $encl,
						model => $model,
					);
				}

				$c{$c}{drivestatus}{$port} = {
					status => $status,
					unit => $unit,
					size => $size,
					%p,
				};

				next;
			}

			if (m{^p\d+}) {
				$this->unknown;
				warn "unparsed: [$_]";
			}
		}
		close $fh;
	}

	return \%c;
}

sub check {
	my $this = shift;

	# status messages pushed here
	my @status;

	my $c = $this->parse;
	if (!$c) {
		$this->unknown;
		$this->message("No Adapters were found on this machine");
	}

	# process each controller
	for my $cid (sort keys %$c) {
		my $c = $c->{$cid};
		my @cstatus;

		for my $uid (sort keys %{$c->{unitstatus}}) {
			my $u = $c->{unitstatus}->{$uid};
			my $s = $u->{status};

			if ($s =~ /INITIALIZING|MIGRATING/) {
				$this->warning;
				$s .= " $u->{vim_percent}";

			} elsif ($s eq 'VERIFYING') {
				$this->check_status;
				$s .= " $u->{vim_percent}";

			} elsif ($s eq 'REBUILDING') {
				$this->resync;
				$s .= " $u->{rebuild_percent}";

			} elsif ($s eq 'DEGRADED') {
				$this->critical;

			} elsif ($s ne 'OK') {
				$this->critical;

			}

			my @ustatus = $s;

			# report cache, no checking
			if ($u->{cache} && $u->{cache} ne '-') {
				push(@ustatus, "Cache:$u->{cache}");
			}

			push(@status, "$cid($c->{model}): $uid($u->{type}): ".join(', ', @ustatus));
		}

		# check individual disk status
		my %ds;
		foreach my $p (sort { $a cmp $b } keys %{$c->{drivestatus}}) {
			my $d = $c->{drivestatus}->{$p};
			my $ds = $d->{status};
			if ($ds eq 'VERIFYING') {
				$this->check_status;
			} elsif ($ds ne 'OK') {
				$this->critical;
			}

			if ($d->{unit} eq '-') {
				$ds = 'SPARE';
			}

			push(@{$ds{$ds}}, $p);
		}
		push(@status, "Drives($c->{drives}): ".$this->join_status(\%ds)) if %ds;

		# check BBU
		if ($c->{bbu} && $c->{bbu} ne '-') {
			$this->critical if $c->{bbu} ne 'OK';
			push(@status, "BBU: $c->{bbu}");
		}
	}

	return unless @status;

	$this->ok->message(join(', ', @status));
}

package arcconf;
# Adaptec AAC-RAID
# check designed from check-aacraid.py, Anchor System - <http://www.anchor.com.au>
# Oliver Hookins, Paul De Audney, Barney Desmond.
# Perl port (check_raid) by Elan Ruusamäe.
use base 'plugin';

# register
push(@utils::plugins, __PACKAGE__);

sub program_names {
	__PACKAGE__;
}

sub commands {
	{
		'getstatus' => ['-|', '@CMD', 'GETSTATUS', '1'],
		'getconfig' => ['-|', '@CMD', 'GETCONFIG', '1', 'AL'],
	}
}

sub sudo {
	my ($this, $deep) = @_;
	# quick check when running check
	return 1 unless $deep;

	my $cmd = $this->{program};
	(
		"CHECK_RAID ALL=(root) NOPASSWD: $cmd GETSTATUS 1",
		"CHECK_RAID ALL=(root) NOPASSWD: $cmd GETCONFIG 1 AL",
	);
}

sub parse_error {
	my ($this, $message) = @_;
	warn "arcconf: parse error: $message";
	$this->unknown->message("Parse Error: $message");
}

# parse GETSTATUS command
# parses
# - number of controllers
# - logical device tasks (if any running)
sub parse_status {
	my ($this) = @_;

	my $count = 0;
	my $ok = 0;
	my $fh = $this->cmd('getstatus');
	my %s;
	# controller task
	my %task;
	while (<$fh>) {
		chomp;
		# empty line
		next if /^$/;

		# termination
		if (/^Command completed successfully/) {
			$ok = 1;
			last;
		}

		if (my($c) = /^Controllers found: (\d+)/) {
			$count = int($c);
			next;
		}

		# termination
		if (/^(\S.+) Task:$/) {
			$task{type} = $1;
			next;
		}

		if (/^\s+Logical device\s+: (\d+)/) {
			$task{device} = $1;
		} elsif (/^\s+Task ID\s+: (\d+)/) {
			$task{id} = $1;
		} elsif (/^\s+Current operation\s+: (.+)/) {
			$task{operation} = $1;
		} elsif (/^\s+Status\s+: (.+)/) {
			$task{status} = $1;
		} elsif (/^\s+Priority\s+: (.+)/) {
			$task{priority} = $1;
		} elsif (/^\s+Percentage complete\s+: (\d+)/) {
			$task{percent} = $1;
		} elsif (/^Invalid controller number/) {
			;
		} else {
			warn "Unknown line: [$_]";
			# FIXME: ->message() gets overwritten later on
			$this->unknown->message("Unknown line: [$_]");
		}
	}
	close($fh);

	# Tasks seem to be Controller specific, but as we don't support over one controller, let it be global
	$s{tasks} = { %task } if %task;

	if ($count > 1) {
		# don't know how to handle this, so better just fail
		$this->unknown->message("More than one Controller found, this is not yet supported due lack of input data.");
		return undef;
	}

	if ($count == 0) {
		# if command completed, but no controllers,
		# assume no hardware present
		if (!$ok) {
			$this->unknown->message("No controllers found!");
		}
		return undef;
	}

	$s{controllers} = $count;

	return \%s;
}

# parse GETCONFIG command
# parses
# - ...
sub parse_config {
	my ($this, $status) = @_;

	# Controller information, Logical/Physical device info
	my (%c, @ld, $ld, @pd, $ch, $pd);

	my $fh = $this->cmd('getconfig');
	my ($section, $subsection, $ok);
	while (<$fh>) {
		chomp;
		# empty line
		if (/^$/) {
			next;
		}

		if (/^Command completed successfully/) {
			$ok = 1;
			last;
		}

		if (my($c) = /^Controllers found: (\d+)/) {
			if ($c != $status->{controllers}) {
				# internal error?!
				$this->unknown->message("Controller count mismatch");
			}
			next;
		}

		# section start
		if (/^---+/) {
			if (my($s) = <$fh> =~ /^(\w.+)$/) {
				$section = $s;
				unless (<$fh> =~ /^---+/) {
					$this->parse_error($_);
				}
				undef($ld);
				$ch = 0;
				undef($pd);
				undef($subsection);
				next;
			}
			$this->parse_error($_);
		}

		# sub section start
		# there are also sections in subsections, but currently section names
		# are unique enough
		if (/^\s+---+/) {
			if (my($s) = <$fh> =~ /^\s+(\S.+?)\s*?$/) {
				$subsection = $s;
				unless (<$fh> =~ /^\s+---+/) {
					$this->parse_error($_);
				}
				next;
			}
			$this->parse_error($_);
		}

		next unless defined $section;

		if ($section eq 'Controller information') {
			if (not defined $subsection) {
				# TODO: battery stuff is under subsection "Controller Battery Information"
				if (my($s) = /Controller Status\s*:\s*(.+)/) {
					$c{status} = $s;

				} elsif (my($df) = /Defunct disk drive count\s+:\s*(\d+)/) {
					$c{defunct_count} = int($df);

				} elsif (my($td, $fd, $dd) = m{Logical devices/Failed/Degraded\s*:\s*(\d+)/(\d+)/(\d+)}) {
					$c{logical_count} = int($td);
					$c{logical_failed} = int($fd);
					$c{logical_degraded} = int($fd);

				} elsif (my($td2, $fd2, $dd2) = m{Logical drives/Offline/Critical\s*:\s*(\d+)/(\d+)/(\d+)}) {
					# ARCCONF 9.30
					$c{logical_count} = int($td2);
					$c{logical_offline} = int($fd2);
					$c{logical_critical} = int($fd2);
				}

			} elsif ($subsection eq 'Controller Battery Information') {
				if (my($bs) = /^\s+Status\s*:\s*(.*)$/) {
					$c{battery_status} = $bs;

				} elsif (my($bt) = /Over temperature\s*:\s*(.+)$/) {
					$c{battery_overtemp} = $bt;

				} elsif (my($bc) = /Capacity remaining\s*:\s*(\d+)\s*percent.*$/) {
					$c{battery_capacity} = int($bc);

				} elsif (my($d, $h, $m) = /Time remaining \(at current draw\)\s*:\s*(\d+) days, (\d+) hours, (\d+) minutes/) {
					$c{battery_time} = int($d) * 1440 + int($h) * 60 + int($m);
					$c{battery_time_full} = "${d}d${h}h${m}m";

				} else {
					warn "Battery not parsed: [$_]";
				}

			} elsif ($subsection eq 'Controller ZMM Information') {
				if (my($bs) = /^\s+Status\s*:\s*(.*)$/) {
					$c{zmm_status} = $bs;
				} else {
					warn "ZMM not parsed: [$_]";
				}

			} elsif ($subsection eq 'Controller Version Information') {
				# not parsed yet
			} elsif ($subsection eq 'Controller Vital Product Data') {
				# not parsed yet
			} elsif ($subsection eq 'Controller Cache Backup Unit Information') {
				# not parsed yet
			} elsif ($subsection eq 'Supercap Information') {
				# this is actually sub section of cache backup unit
				# not parsed yet
			} elsif ($subsection eq 'Controller Vital Product Data') {
				# not parsed yet
			} elsif ($subsection eq 'RAID Properties') {
				# not parsed yet
			} elsif ($subsection eq 'Controller BIOS Setting Information') {
				# not parsed yet
			} else {
				warn "SUBSECTION of [$section] NOT PARSED: [$subsection] [$_]";
			}

		} elsif ($section eq 'Physical Device information') {
			if (my($c) = /Channel #(\d+)/) {
				$ch = int($c);
				undef($pd);
			} elsif (my($n) = /Device #(\d+)/) {
				$pd = int($n);
			} elsif (not defined $pd) {
				if (/Transfer Speed\s+:\s+(.+)/) {
					# not parsed yet
				} elsif (/Initiator at SCSI ID/) {
					# not parsed yet
				} elsif (/No physical drives attached/) {
					# ignored
				} else {
					warn "Unparsed Physical Device data: [$_]";
				}
			} else {
				if (my($ps) = /Power State\s+:\s+(.+)/) {
					$pd[$ch][$pd]{power_state} = $ps;
				} elsif (my($st) = /^\s+State\s+:\s+(.+)/) {
					$pd[$ch][$pd]{status} = $st;
				} elsif (my($su) = /Supported\s+:\s+(.+)/) {
					$pd[$ch][$pd]{supported} = $su;
				} elsif (my($sf) = /Dedicated Spare for\s+:\s+(.+)/) {
					$pd[$ch][$pd]{spare} = $sf;
				} elsif (my($vnd) = /Vendor\s+:\s*(.*)/) {
					# allow edits, i.e removed 'Vendor' value from test data
					$pd[$ch][$pd]{vendor} = $vnd;
				} elsif (my($mod) = /Model\s+:\s+(.+)/) {
					$pd[$ch][$pd]{model} = $mod;
				} elsif (my($fw) = /Firmware\s+:\s*(.*)/) {
					$pd[$ch][$pd]{firmware} = $fw;
				} elsif (my($sn) = /Serial number\s+:\s+(.+)/) {
					$pd[$ch][$pd]{serial} = $sn;
				} elsif (my($wwn) = /World-wide name\s+:\s+(.+)/) {
					$pd[$ch][$pd]{wwn} = $wwn;
				} elsif (my($sz) = /Size\s+:\s+(.+)/) {
					$pd[$ch][$pd]{size} = $sz;
				} elsif (my($wc) = /Write Cache\s+:\s+(.+)/) {
					$pd[$ch][$pd]{write_cache} = $wc;
				} elsif (my($ssd) = /SSD\s+:\s+(.+)/) {
					$pd[$ch][$pd]{ssd} = $ssd;
				} elsif (my($fru) = /FRU\s+:\s+(.+)/) {
					$pd[$ch][$pd]{fru} = $fru;
				} elsif (my($esd) = /Reported ESD(?:\(.+\))?\s+:\s+(.+)/) {
					$pd[$ch][$pd]{esd} = $esd;
				} elsif (my($ncq) = /NCQ status\s+:\s+(.+)/) {
					$pd[$ch][$pd]{ncq} = $ncq;
				} elsif (my($pfa) = /PFA\s+:\s+(.+)/) {
					$pd[$ch][$pd]{pfa} = $pfa;
				} elsif (my($eid) = /Enclosure ID\s+:\s+(.+)/) {
					$pd[$ch][$pd]{enclosure} = $eid;
				} elsif (my($t) = /Type\s+:\s+(.+)/) {
					$pd[$ch][$pd]{type} = $t;
				} elsif (my($smart) = /S\.M\.A\.R\.T\.(?:\s+warnings)?\s+:\s+(.+)/) {
					$pd[$ch][$pd]{smart} = $smart;
				} elsif (my($speed) = /Transfer Speed\s+:\s+(.+)/) {
					$pd[$ch][$pd]{speed} = $speed;
				} elsif (my($e, $s) = /Reported Location\s+:\s+(?:Enclosure|Connector) (\d+), (?:Slot|Device) (\d+)/) {
					$pd[$ch][$pd]{location} = "$e:$s";
				} elsif (my($sps) = /Supported Power States\s+:\s+(.+)/) {
					$pd[$ch][$pd]{power_states} = $sps;
				} elsif (my($cd) = /Reported Channel,Device(?:\(.+\))?\s+:\s+(.+)/) {
					$pd[$ch][$pd]{cd} = $cd;
				} elsif (my($type) = /Device is an?\s+(.+)/) {
					$pd[$ch][$pd]{devtype} = $type;
				} elsif (/Status of Enclosure/) {
					# ignored
				} elsif (my($temp) = /Temperature.*:\s+(.+)/) {
					$pd[$ch][$pd]{temperature} = $temp;
				} elsif (/(Fan \d+|Speaker) status/) {
					# not parsed yet
				} elsif (/Expander ID\s+:/) {
					# not parsed yet
				} elsif (/Enclosure Logical Identifier\s+:/) {
					# not parsed yet
				} elsif (/Expander SAS Address\s+:/) {
					# not parsed yet
				} elsif (/MaxCache (Capable|Assigned)\s+:\s+(.+)/) {
					# not parsed yet
				} elsif (/Power supply \d+ status/) {
					# not parsed yet
				} else {
					warn "Unparsed Physical Device data: [$_]";
				}
			}

		} elsif ($section =~ /Logical (device|drive) information/) {
			if (my($n) = /Logical (?:device|drive) number (\d+)/) {
				$ld = int($n);
				$ld[$ld]{id} = $n;

			} elsif (my($s) = /Status of logical (?:device|drive)\s+:\s+(.+)/) {
				$ld[$ld]{status} = $s;

			} elsif (my($ln) = /Logical (?:device|drive) name\s+:\s+(.+)/) {
				$ld[$ld]{name} = $ln;

			} elsif (my($rl) = /RAID level\s+:\s+(.+)/) {
				$ld[$ld]{raid} = $rl;

			} elsif (my($sz) = /Size\s+:\s+(.+)/) {
				$ld[$ld]{size} = $sz;

			} elsif (my($fs) = /Failed stripes\s+:\s+(.+)/) {
				$ld[$ld]{failed_stripes} = $fs;

			} elsif (my($ds) = /Defunct segments\s+:\s+(.+)/) {
				$ld[$ld]{defunct_segments} = $ds;

			} else {
				#   Write-cache mode                         : Not supported]
				#   Partitioned                              : Yes]
				#   Number of segments                       : 2]
				#   Drive(s) (Channel,Device)                : 0,0 0,1]
				#   Defunct segments                         : No]
			}
		} elsif ($section =~ /MaxCache 3\.0 information/) {
			# not parsed yet
		} else {
			warn "NOT PARSED: [$section] [$_]";
		}
	}
	close $fh;

	$this->unknown->message("Command did not succeed") unless defined $ok;

	return { controller => \%c, logical => \@ld, physical => \@pd };
}

# NB: side effect: ARCCONF changes current directory to /var/log
sub parse {
	my ($this) = @_;

	# we chdir to /var/log, as tool is creating 'UcliEvt.log'
	chdir('/var/log') || chdir('/');

	my ($status, $config);
	$status = $this->parse_status or return;
	$config = $this->parse_config($status) or return;

	return { %$status, %$config };
}

sub check {
	my $this = shift;

	my $data = $this->parse;
	$this->unknown,return unless $data;

	# status messages pushed here
	my @status;

	# check for controller status
	for my $c ($data->{controller}) {
		$this->critical if $c->{status} !~ /Optimal|Okay/;
		push(@status, "Controller:$c->{status}");

		if ($c->{defunct_count} > 0) {
			$this->critical;
			push(@status, "Defunct drives:$c->{defunct_count}");
		}

		if (defined $c->{logical_failed} && $c->{logical_failed} > 0) {
			$this->critical;
			push(@status, "Failed drives:$c->{logical_failed}");
		}

		if (defined $c->{logical_degraded} && $c->{logical_degraded} > 0) {
			$this->critical;
			push(@status, "Degraded drives:$c->{logical_degraded}");
		}

		if (defined $c->{logical_offline} && $c->{logical_offline} > 0) {
			$this->critical;
			push(@status, "Offline drives:$c->{logical_offline}");
		}

		if (defined $c->{logical_critical} && $c->{logical_critical} > 0) {
			$this->critical;
			push(@status, "Critical drives:$c->{logical_critical}");
		}

		if (defined $c->{logical_degraded} && $c->{logical_degraded} > 0) {
			$this->critical;
			push(@status, "Degraded drives:$c->{logical_degraded}");
		}

		# current (logical device) tasks
		if ($data->{tasks}->{operation} ne 'None') {
			# just print it. no status change
			my $task = $data->{tasks};
			push(@status, "$task->{type} #$task->{device}: $task->{operation}: $task->{status} $task->{percent}%");
		}

		# ZMM (Zero-Maintenance Module) status
		if (defined($c->{zmm_status})) {
			push(@status, "ZMM Status: $c->{zmm_status}");
		}

		# Battery status
		my @s = $this->battery_status($c);
		push(@status, @s) if @s;
	}

	# check for physical devices
	my %pd;
	my $pd_resync = 0;
	for my $ch (@{$data->{physical}}) {
		for my $pd (@{$ch}) {
			# skip not disks
			next if not defined $pd;
			next if $pd->{devtype} =~ m/Enclosure/;

			if ($pd->{status} eq 'Rebuilding') {
				$this->resync;
				$pd_resync++;

			} elsif ($pd->{status} eq 'Dedicated Hot-Spare') {
				$this->spare;
				$pd->{status} = "$pd->{status} for $pd->{spare}";

			} elsif ($pd->{status} !~ /^Online|Hot[- ]Spare|Ready/) {
				$this->critical;
			}

			my $id = $pd->{serial} || $pd->{wwn} || $pd->{location};
			push(@{$pd{$pd->{status}}}, $id);
		}
	}

	# check for logical devices
	for my $ld (@{$data->{logical}}) {
		next unless $ld; # FIXME: fix that script assumes controllers start from '0'

		if ($ld->{status} eq 'Degraded' && $pd_resync) {
			$this->warning;
		} elsif ($ld->{status} !~ /Optimal|Okay/) {
			$this->critical;
		}

		my $id = $ld->{id};
		if ($ld->{name}) {
			$id = "$id($ld->{name})";
		}
		push(@status, "Logical Device $id:$ld->{status}");

		if (defined $ld->{failed_stripes} && $ld->{failed_stripes} ne 'No') {
			push(@status, "Failed stripes: $ld->{failed_stripes}");
		}
		if (defined $ld->{defunct_segments} && $ld->{defunct_segments} ne 'No') {
			push(@status, "Defunct segments: $ld->{defunct_segments}");
		}
	}

	push(@status, "Drives: ".$this->join_status(\%pd)) if %pd;

	$this->ok->message(join(', ', @status));
}

# check battery status in $c
sub battery_status {
	my ($this, $c) = @_;

	my @status;

	if (!defined($c->{battery_status}) || $c->{battery_status} eq 'Not Installed') {
		return;
	}

	push(@status, "Battery Status: $c->{battery_status}");

	# if battery status is 'Failed', none of the details below are available. #105
	if ($c->{battery_status} eq 'Failed') {
		$this->critical;
		return @status;
	}

	# detailed battery checks
	if ($c->{battery_overtemp} ne 'No') {
		$this->critical;
		push(@status, "Battery Overtemp: $c->{battery_overtemp}");
	}

	push(@status, "Battery Capacity Remaining: $c->{battery_capacity}%");
	if ($c->{battery_capacity} < 50) {
		$this->critical;
	}
	if ($c->{battery_capacity} < 25) {
		$this->warning;
	}

	if ($c->{battery_time} < 1440) {
		$this->warning;
	}
	if ($c->{battery_time} < 720) {
		$this->critical;
	}

	if ($c->{battery_time} < 60) {
		push(@status, "Battery Time: $c->{battery_time}m");
	} else {
		push(@status, "Battery Time: $c->{battery_time_full}");
	}

	return @status;
}

package megarc;
# LSI MegaRaid or Dell Perc arrays
# Check the status of all arrays on all Lsi MegaRaid controllers on the local
# machine. Uses the megarc program written by Lsi to get the status of all
# arrays on all local Lsi MegaRaid controllers.
#
# check designed from check_lsi_megaraid:
# http://www.monitoringexchange.org/cgi-bin/page.cgi?g=Detailed/2416.html;d=1
# Perl port (check_raid) by Elan Ruusamäe.
use base 'plugin';

# register
push(@utils::plugins, __PACKAGE__);

sub program_names {
	__PACKAGE__;
}

sub commands {
	{
		'controller list' => ['-|', '@CMD', '-AllAdpInfo', '-nolog'],
		'controller config' => ['-|', '@CMD', '-dispCfg', '-a$controller', '-nolog'],
	}
}

sub sudo {
	my ($this, $deep) = @_;
	# quick check when running check
	return 1 unless $deep;

	my $cmd = $this->{program};
	(
		"CHECK_RAID ALL=(root) NOPASSWD: $cmd -AllAdpInfo -nolog",
		"CHECK_RAID ALL=(root) NOPASSWD: $cmd -dispCfg -a* -nolog",
	);
}

sub check {
	my $this = shift;

	# status messages pushed here
	my @status;

	# get controllers
	my $fh = $this->cmd('controller list');
	my @lines = <$fh>;
	close $fh;

	if ($lines[11] =~ /No Adapters Found/) {
		$this->warning;
		$this->message("No LSI adapters were found on this machine");
		return;
	}

	my @c;
	foreach (@lines[12..$#lines]) {
		if (my ($id) = /^\s*(\d+)/) {
			push(@c, int($id));
		}
	}
	unless (@c) {
		$this->warning;
		$this->message("No LSI adapters were found on this machine");
		return;
	}

	foreach my $c (@c) {
		my $fh = $this->cmd('controller config', { '$controller' => $c });
		my (%d, %s, $ld);
		while (<$fh>) {
			# Logical Drive : 0( Adapter: 0 ):  Status: OPTIMAL
			if (my($d, $s) = /Logical Drive\s+:\s+(\d+).+Status:\s+(\S+)/) {
				$ld = $d;
				$s{$ld} = $s;
				next;
			}
			# SpanDepth :01     RaidLevel: 5  RdAhead : Adaptive  Cache: DirectIo
			if (my($s) = /RaidLevel:\s+(\S+)/) {
				$d{$ld} = $s if defined $ld;
				next;
			}
		}
		close $fh;

		# now process the details
		unless (keys %d) {
			$this->message("No arrays found on controller $c");
			$this->warning;
			return;
		}

		while (my($d, $s) = each %s) {
			if ($s ne 'OPTIMAL') {
				# The Array number here is incremented by one because of the
				# inconsistent way that the LSI tools count arrays.
				# This brings it back in line with the view in the bios
				# and from megamgr.bin where the array counting starts at
				# 1 instead of 0
				push(@status, "Array ".(int($d) + 1)." status is ".$s{$d}." (Raid-$s on adapter $c)");
				$this->critical;
				next;
			}

			push(@status, "Logical Drive $d: $s");
		}
	}

	return unless @status;

	$this->ok->message(join(', ', @status));
}

package cmdtool2;
use base 'plugin';

# register
push(@utils::plugins, __PACKAGE__);

sub program_names {
	'CmdTool2';
}

sub commands {
	{
		'adapter list' => ['-|', '@CMD', , '-AdpAllInfo', '-aALL', '-nolog'],
		'adapter config' => ['-|', '@CMD', '-CfgDsply', '-a$adapter', '-nolog'],
	}
}

sub sudo {
	my ($this, $deep) = @_;
	# quick check when running check
	return 1 unless $deep;

	my $cmd = $this->{program};
	(
		"CHECK_RAID ALL=(root) NOPASSWD: $cmd -AdpAllInfo -aALL -nolog",
		"CHECK_RAID ALL=(root) NOPASSWD: $cmd -CfgDsply -a* -nolog",
	);
}

sub check {
	my $this = shift;

	# status messages pushed here
	my @status;

	# get adapters
	my $fh = $this->cmd('adapter list');
	my @c;
	while (<$fh>) {
		if (my($c) = /^Adapter #(\d+)/) {
			push(@c, $c);
		}
	}
	close $fh;

	unless (@c) {
		$this->warning;
		$this->message("No LSI adapters were found on this machine");
		return;
	}

	foreach my $c (@c) {
		my $fh = $this->cmd('adapter config', { '$adapter' => $c });
		my ($d);
		while (<$fh>) {
			# DISK GROUPS: 0
			if (my($s) = /^DISK GROUPS: (\d+)/) {
				$d = int($s);
				next;
			}

			# State: Optimal
			if (my($s) = /^State: (\S+)$/) {
				if ($s ne 'Optimal') {
					$this->critical;
				}
				push(@status, "Logical Drive $c,$d: $s");
			}
		}
	}

	return unless @status;

	# denote this plugin as ran ok
	$this->ok;

	$this->message(join(', ', @status));
}

package cciss;
use base 'plugin';

# register
push(@utils::plugins, __PACKAGE__);

sub program_names {
	'cciss_vol_status';
}

sub commands {
	{
		'controller status' => ['-|', '@CMD', '@devs'],
		'controller status verbose' => ['-|', '@CMD', '-V', '@devs'],
		'cciss_vol_status version' => ['>&2', '@CMD', '-v'],

		'detect hpsa' => ['<', '/sys/module/hpsa/refcnt'],
		'detect cciss' => ['<', '/proc/driver/cciss'],
		'cciss proc' => ['<', '/proc/driver/cciss/$controller'],

		# for lsscsi, issue #109
		'lsscsi list' => ['-|', '@CMD', '-g'],
	}
}

sub sudo {
	my ($this, $deep) = @_;

	# quick check when running check
	return 1 unless $deep;

	my $cmd = $this->{program};

	my $v1_10 = $this->cciss_vol_status_version >= 1.10;

	my @sudo;
	my @cciss_devs = $this->detect;
	if (@cciss_devs) {
		my $c = join(' ', @cciss_devs);
		if ($v1_10) {
			push(@sudo, "CHECK_RAID ALL=(root) NOPASSWD: $cmd -V $c");
		} else {
			push(@sudo, "CHECK_RAID ALL=(root) NOPASSWD: $cmd $c");
		}
	}

	my @cciss_disks = $this->detect_disks(@cciss_devs);
	if (!$v1_10 && @cciss_disks) {
		my $smartctl = smartctl->new();

		if ($smartctl->active) {
			my $cmd = $smartctl->{program};
			foreach my $ref (@cciss_disks) {
				my ($dev, $diskopt, $disk) = @$ref;
				# escape comma for sudo
				$diskopt =~ s/,/\\$&/g;
				push(@sudo, "CHECK_RAID ALL=(root) NOPASSWD: $cmd -H $dev $diskopt$disk");
			}
		}
	}

	return @sudo;
}

# detects if hpsa (formerly cciss) is present in system
sub detect {
	my $this = shift;

	my ($fh, @devs);

	# try lsscsi first if enabled and allowed
	my $lsscsi = lsscsi->new('commands' => $this->{commands});
	my $use_lsscsi = defined($this->{use_lsscsi}) ? $this->{use_lsscsi} : $lsscsi->active;
	if ($use_lsscsi) {
		# for cciss_vol_status < 1.10 we need /dev/sgX nodes, columns which are type storage
		@devs = $lsscsi->list_sg;

		# cciss_vol_status 1.10 can process disk nodes too even if sg is not present
		my $v1_10 = $this->cciss_vol_status_version >= 1.10;
		if (!@devs && $v1_10) {
			@devs = $lsscsi->list_dd;
		}

		return wantarray ? @devs : \@devs if @devs;
	}

	# check hpsa devs
	eval { $fh = $this->cmd('detect hpsa'); };
	if ($fh) {
		my $refcnt = <$fh>;
		close $fh;

		if ($refcnt) {
			# TODO: how to figure which sgX is actually in use?
			# for now we collect all, and expect cciss_vol_status to ignore unknowns
			# refcnt seems to match number of sg devs: /sys/class/scsi_generic/sg*
			for (my $i = 0; $i < $refcnt; $i++) {
				my $dev = "/dev/sg$i";
				# filter via valid() so could exclude devs
				push(@devs, $dev) if $this->valid($dev);
			}
		}
	}
	undef($fh);

	# check legacy cciss devs
	eval { $fh = $this->cmd('detect cciss'); };
	if ($fh) {
		my @c = grep { !/^\./ } readdir($fh);
		close($fh);

		# find controllers
		#	cciss0: HP Smart Array P400i Controller
		#	Board ID: 0x3235103c
		#	Firmware Version: 4.06
		#	IRQ: 98
		#	Logical drives: 1
		#	Current Q depth: 0
		#	Current # commands on controller: 0
		#	Max Q depth since init: 249
		#	Max # commands on controller since init: 275
		#	Max SG entries since init: 31
		#	Sequential access devices: 0
		#
		#	cciss/c0d0:      220.12GB       RAID 1(1+0)
		for my $c (@c) {
			my $fh = $this->cmd('cciss proc', { '$controller' => $c });
			while (<$fh>) {
				# check "c*d0" - iterate over each controller
				next unless (my($dev) = m{^(cciss/c\d+d0):});
				$dev = "/dev/$dev";
				# filter via valid() so could exclude devs
				push(@devs, $dev) if $this->valid($dev);
			}
			close $fh;
		}
	}
	undef($fh);

	return wantarray ? @devs : \@devs;
}

# build list of cciss disks
# used by smartctl check
# just return all disks (0..15) for each cciss dev found
sub detect_disks {
	my $this = shift;

	my @devs;
	# build devices list for smartctl
	foreach my $scsi_dev (@_) {
		foreach my $disk (0..15) {
			push(@devs, [ $scsi_dev, '-dcciss,', $disk ]);
		}
	}
	return wantarray ? @devs : \@devs;
}

# parse version out of "cciss_vol_status version 1.09"
# NOTE: it prints the output to stderr, but may print to stdout in the future
sub cciss_vol_status_version {
	my $this = shift;

	# cache inside single run
	return $this->{cciss_vol_status_version} if defined $this->{cciss_vol_status_version};

	my $version = sub {
		my $fh = $this->nosudo_cmd('cciss_vol_status version');
		my ($line) = <$fh>;
		close $fh;
		return 0 unless $line;

		if (my($v) = $line =~ /^cciss_vol_status version ([\d.]+)$/) {
			return 0 + $v;
		}
		return 0;
	};

	return $this->{cciss_vol_status_version} = &$version();
}

sub trim { my $s = shift; $s =~ s/^\s+|\s+$//g; return $s };

# we process until we find end of sentence (dot at the end of the line)
sub consume_diagnostic {
	my ($this, $fh) = @_;

	my $diagnostic = '';
	while (1) {
		my $s = <$fh>;
		last unless $s;
		chomp;
		$diagnostic .= ' '. trim($s);
		last if $s =~ /\.$/;
	}
	return trim($diagnostic);
}

# process to skip lines with physical location:
# "         connector 1I box 1 bay 4 ..."
sub consume_disk_map {
	my ($this, $fh) = @_;

	while (my $s = <$fh>) {
		chomp $s;
		# connector 1I box 1 bay 4
		last unless $s =~ /^\s+connector\s/;
	}
}

sub parse {
	my $this = shift;
	my @devs = @_;

	my (%c, $cdev);

	# cciss_vol_status 1.10 has -V option to print more info about controller and disks.
	my $v1_10 = $this->cciss_vol_status_version >= 1.10;

	# add all devs at once to commandline, cciss_vol_status can do that
	my $fh = $this->cmd($v1_10 ? 'controller status verbose' : 'controller status', { '@devs' => \@devs });
	while (<$fh>) {
		chomp;

		if (/Controller:/) {
			# this is first item when new controller is found
			# reset previous state
			undef $cdev;
			next;
		}

		# catch enclosures, print_bus_status()
		# /dev/cciss/c1d0: (Smart Array P800) Enclosure MSA70 (S/N: SGA651004J) on Bus 2, Physical Port 1E status: OK.
		# /dev/cciss/c0d0: (Smart Array 6i) Enclosure PROLIANT 6L2I (S/N: ) on Bus 0, Physical Port J1 status: OK.
		if (my($file, $board_name, $name, $sn, $bus, $port1, $port2, $status) = m{
			^(/dev/[^:]+):\s        # File
			\(([^)]+)\)\s           # Board Name
			Enclosure\s(.*?)\s      # Enclosure Name
			\(S/N:\s(\S*)\)\s       # Enclosure SN
			on\sBus\s(\d+),\s       # Bus Number
			Physical\sPort\s(.)     # physical_port1
			(.)\s                   # physical_port2
			status:\s(.*?)\.        # status (without a dot)
		}x) {
			$c{$file}{enclosures}{$bus} = {
				board_name => $board_name,
				name => $name,
				sn => $sn,
				bus => int($bus),
				phys1 => $port1,
				phys2 => $port2,
				status => $status,
			};
			next;
		}

		# volume status, print_volume_status()
		# /dev/cciss/c0d0: (Smart Array P400i) RAID 1 Volume 0 status: OK
		# /dev/sda: (Smart Array P410i) RAID 1 Volume 0 status: OK.
		# /dev/sda: (Smart Array P410i) RAID 5 Volume 0 status: OK.   At least one spare drive designated.  At least one spare drive has failed.
		if (my($file, $board_name, $raid_level, $volume_number, $certain, $status, $spare_drive_status) = m{
			^(/dev/[^:]+):\s        # File
			\(([^)]+)\)\s           # Board Name
			(RAID\s\d+|\([^)]+\))\s # RAID level
			Volume\s(\d+)           # Volume number
			(\(\?\))?\s             # certain?
			status:\s(.*?)\.        # status (without a dot)
			(.*)?                   # spare drive status messages
		}x) {
			$cdev = $file;
			$c{$file}{volumes}{$volume_number} = {
				board_name => $board_name,
				raid_level => $raid_level,
				volume_number => $volume_number,
				certain => int(not defined $certain),
				status => $status,
				spare_drive_status => trim($spare_drive_status),
			};

			$c{$file}{board_name} = $board_name;
			next;
		}

		next unless $cdev;

		if (my ($count) = /Physical drives: (\d+)/) {
			$c{$cdev}{'pd count'} = $count;
			next;
		}

		# check_physical_drives(file, fd);
		# NOTE: check for physical drives is enabled with -V or -s option (-V enables -s)
		# cciss_vol_status.c format_phys_drive_location()
		if (my ($phys1, $phys2, $box, $bay, $model, $serial_no, $fw_rev, $status) = m{
			\sconnector\s(.)(.)\s # Phys connector 1&2
			box\s(\d+)\s          # phys_box_on_bus
			bay\s(\d+)\s          # phys_bay_in_box
			(.{40})\s             # model
			(.{40})\s             # serial no
			(.{8})\s              # fw rev
			(.+)                  # status
		$}x) {
			my $slot = "$phys1$phys2-$box-$bay";
			$c{$cdev}{drives}{$slot} = {
				'slot' => $slot,
				'phys1' => $phys1,
				'phys2' => $phys2,
				'box' => int($box),
				'bay' => int($bay),

				'model' => trim($model),
				'serial' => trim($serial_no),
				'fw' => trim($fw_rev),
				'status' => $status,
			};
			next;
		}

		# TODO
		# check_fan_power_temp(file, ctlrtype, fd, num_controllers);

		# check_nonvolatile_cache_status(file, ctlrtype, fd, num_controllers);
		# /dev/cciss/c0d0(Smart Array P400i:0): Non-Volatile Cache status:
		if (my($file, $board_name, $instance) = m{^(/dev/[^(]+)\((.+):(\d+)\): Non-Volatile Cache status}) {
			# $file and $dev may differ, so store it
			$c{$cdev}{cache} = {
				'file' => $file,
				'board' => $board_name,
				'instance' => int($instance),
			};
			next;
		}

		if (defined($c{$cdev}{cache})) {
			my $cache = $c{$cdev}{cache};
			my %map = (
				configured => qr/Cache configured: (.+)/,
				read_cache_memory => qr/Read cache memory: (.+)/,
				write_cache_memory => qr/Write cache memory: (.+)/,
				write_cache_enabled => qr/Write cache enabled: (.+)/,
				flash_cache => qr/Flash backed cache present/,
				disabled_temporarily => qr/Write cache temporarily disabled/,
				disabled_permanently => qr/Write Cache permanently disabled/,
			);
			my $got;
			while (my($k, $r) = each %map) {
				next unless (my($v) = $_ =~ $r);
				$cache->{$k} = $v;
				$got = 1;

				# consume extended diagnostic
				if ($k =~ /disabled_(temporari|permanentl)ly/) {
					$cache->{"$k diagnostic"} = $this->consume_diagnostic($fh);
				}
			}

			next if $got;
		}

		# show_disk_map("  Failed drives:", file, fd, id, controller_lun, ctlrtype,
		# show_disk_map("  'Replacement' drives:", file, fd, id, controller_lun, ctlrtype,
		# show_disk_map("  Drives currently substituted for by spares:", file, fd, id, controller_lun, ctlrtype,
		if (/^  Failed drives:/ ||
			/^  'Replacement' drives:/ ||
			/^  Drives currently substituted for by spares:/
		) {
			# could store this somewhere, ignore for now
			$this->consume_disk_map($fh);
			next;
		}

		if (my($total_failed) = /Total of (\d+) failed physical drives detected on this logical drive\./) {
			$c{$cdev}{phys_failed} = $total_failed;
			next;
		}

		warn "Unparsed[$_]";
	}
	close($fh);

	return \%c;
}

sub check {
	my $this = shift;
	my @devs = $this->detect;

	unless (@devs) {
		$this->warning;
		$this->message("No Smart Array Adapters were found on this machine");
		return;
	}

	# status messages pushed here
	my @status;

	my $res = $this->parse(@devs);
	for my $dev (sort {$a cmp $b} keys %$res) {
		my $c = $res->{$dev};
		my @bstatus;

		# check volumes
		my @vstatus;
		for my $vn (sort {$a cmp $b} keys %{$c->{volumes}}) {
			my $v = $c->{volumes}->{$vn};
			if ($v->{status} !~ '^OK') {
				$this->critical;
			}
			push(@vstatus, "Volume $v->{volume_number} ($v->{raid_level}): $v->{status}");
		}

		push(@bstatus, @vstatus) if @vstatus;

		# check physical devices
		if ($c->{'pd count'}) {
			my %pd;
			for my $ps (sort {$a cmp $b} keys %{$c->{drives}}) {
				my $pd = $c->{drives}{$ps};
				if ($pd->{status} !~ '^OK') {
					$this->critical;
					$ps .= "($pd->{serial})";
				}
				push(@{$pd{$pd->{status}}}, $ps);
			}
			push(@bstatus, "Drives($c->{'pd count'}): ". $this->join_status(\%pd));
		}

		# check enclosures
		if ($c->{enclosures}) {
			my @e;
			for my $i (sort {$a cmp $b} keys %{$c->{enclosures}}) {
				my $e = $c->{enclosures}{$i};

				# enclosure name may be missing, identify by connection
				my $s = $e->{name} || "$e->{bus}-$e->{phys1}$e->{phys2}";
				# enclosure S/N may be missing
				$s .= "($e->{sn})" if $e->{sn};
				$s .= ": $e->{status}";
				if ($e->{status} !~ '^OK') {
					$this->critical;
				}
				push(@e, $s);
			}
			push(@bstatus, "Enclosures: ". join(', ', @e));
		}

		# check cache
		if ($c->{cache} && $c->{cache}->{configured} eq 'Yes') {
			my $cache = $c->{cache};
			my @cstatus = 'Cache:';

			if ($cache->{write_cache_enabled} eq 'Yes') {
				push(@cstatus, "WriteCache");

			} elsif ($cache->{disabled_temporarily} || $cache->{disabled_permanently}) {
				# disabled diagnostic is available, but it's too long to print here
				push(@cstatus, "WriteCache:DISABLED");
				$this->cache_fail;
			}

			push(@cstatus, "FlashCache") if $cache->{flash_cache};
			push(@cstatus, "ReadMem:$cache->{read_cache_memory}") if $cache->{read_cache_memory};
			push(@cstatus, "WriteMem:$cache->{write_cache_memory}") if $cache->{write_cache_memory};

			push(@bstatus, join(' ', @cstatus));
		}

		push(@status, "$dev($c->{board_name}): ". join(', ', @bstatus));
	}

	unless (@status) {
		return;
	}

	# denote this plugin as ran ok
	$this->ok;

	$this->message(join(', ', @status));

	# cciss_vol_status 1.10 with -V (or -s) checks individual disk health anyway
	my $v1_10 = $this->cciss_vol_status_version >= 1.10;

	# no_smartctl: allow skip from tests
	if (!$v1_10 && !$this->{no_smartctl}) {
		# check also individual disk health
		my @disks = $this->detect_disks(@devs);
		if (@disks) {
			# inherit smartctl command from our commands (testing)
			my %params = ();
			$params{commands}{smartctl} = $this->{commands}{smartctl} if $this->{commands}{smartctl};

			my $smartctl = smartctl->new(%params);
			# do not perform check if smartctl is missing
			if ($smartctl->active) {
				$smartctl->check(@disks);

				# XXX this is hack, as we have no proper subcommand check support
				$this->message($this->message . " " .$smartctl->message);
				if ($smartctl->status > 0) {
					$this->critical;
				}
			}
		}
	}
}

package hp_msa;
use base 'plugin';

# do not register, better use hpacucli
push(@utils::plugins, __PACKAGE__);

sub active {
	my $this = shift;
	return $this->detect;
}

# check from /sys if there are any MSA VOLUME's present.
sub detect {
	my $this = shift;

	# allow --plugin-option=hp_msa-enabled to force this plugin to be enabled
	return 1 if exists $this->{options}{'hp_msa-enabled'};

	for my $file (</sys/block/*/device/model>) {
		open my $fh, '<', $file or next;
		my $model = <$fh>;
		close($fh);
		return 1 if ($model =~ /^MSA.+VOLUME/);
	}
	return 0;
}

sub check {
	my $this = shift;

	#  allow --plugin-option=hp_msa-serial=/dev/ttyS2 to specify serial line
	my $ctldevice = $this->{options}{'hp_msa-serial'} || '/dev/ttyS0';

	# status messages pushed here
	my @status;

	my %opts = ();
	$opts{lockdir} = $this->{lockdir} if $this->{lockdir};

	my $modem = SerialLine->new($ctldevice, %opts);
	my $fh = $modem->open();
	unless ($fh) {
		$this->warning;
		$this->message("Can't open $ctldevice");
		return;
	}

	# check first controller
	print $fh "\r";
	print $fh "show globals\r";
	print $fh "show this_controller\r";
	print $fh "show other_controller\r";
	# this will issue termination match, ie. invalid command
	print $fh "exit\r";

	my ($c, %c, %t);
	while (<$fh>) {
		chomp;
		s/[\n\r]$//;
		last if /Invalid CLI command/;

		# Temperature:
		# EMU: 23 Celsius,  73 Fahrenheit
		# PS1: 22 Celsius,  71 Fahrenheit
		# PS2: 22 Celsius,  71 Fahrenheit
		if (my($s, $c) = /(\S+): (\d+) Celsius,\s+\d+ Fahrenheit/) {
			$t{$s} = int($c);
			next;
		}

		# Controller 1 (right controller):
		if (my($s) = /^(Controller \d+)/) {
			$c = $s;
			$c{$c} = [];
			next;
		}
		# Surface Scan: Running, LUN 10 (68% Complete)
		if (my($s, $m) = /Surface Scan:\s+(\S+)[,.]\s*(.*)/) {
			if ($s eq 'Running') {
				my ($l, $p) = $m =~ m{(LUN \d+) \((\d+)% Complete\)};
				push(@{$c{$c}}, "Surface: $l ($p%)");
				$this->warning;
			} elsif ($s ne 'Complete') {
				push(@{$c{$c}}, "Surface: $s, $m");
				$this->warning;
			}
			next;
		}
		# Rebuild Status: Running, LUN 0 (67% Complete)
		if (my($s, $m) = /Rebuild Status:\s+(\S+)[,.]\s*(.*)/) {
			if ($s eq 'Running') {
				my ($l, $p) = $m =~ m{(LUN \d+) \((\d+)% Complete\)};
				push(@{$c{$c}}, "Rebuild: $l ($p%)");
				$this->warning;
			} elsif ($s ne 'Complete') {
				push(@{$c{$c}}, "Rebuild: $s, $m");
				$this->warning;
			}
			next;
		}
		# Expansion: Complete.
		if (my($s, $m) = /Expansion:\s+(\S+)[.,]\s*(.*)/) {
			if ($s eq 'Running') {
				my ($l, $p) = $m =~ m{(LUN \d+) \((\d+)% Complete\)};
				push(@{$c{$c}}, "Expansion: $l ($p%)");
				$this->warning;
			} elsif ($s ne 'Complete') {
				push(@{$c{$c}}, "Expansion: $s, $m");
				$this->warning;
			}
			next;
		}
	}
	$modem->close();

	foreach $c (sort { $a cmp $b } keys %c) {
		my $s = $c{$c};
		$s = join(', ', @$s);
		$s = 'OK' unless $s;
		push(@status, "$c: $s");
	}

	# check that no temp is over the treshold
	my $warn = 28;
	my $crit = 33;
	while (my($t, $c) = each %t) {
		if ($c > $crit) {
			push(@status, "$t: ${c}C");
			$this->critical;
		} elsif ($c > $warn) {
			push(@status, "$t: ${c}C");
			$this->warning;
		}
	}

	return unless @status;

	$this->message(join(', ', @status));
}

package sas2ircu;
# LSI SAS-2 controllers using the SAS-2 Integrated RAID Configuration Utility (SAS2IRCU)
# Based on the SAS-2 Integrated RAID Configuration Utility (SAS2IRCU) User Guide
# http://www.lsi.com/downloads/Public/Host%20Bus%20Adapters/Host%20Bus%20Adapters%20Common%20Files/SAS_SATA_6G_P12/SAS2IRCU_User_Guide.pdf
use base 'plugin';

# register
push(@utils::plugins, __PACKAGE__);

sub program_names {
	__PACKAGE__;
}

sub commands {
	{
		'controller list' => ['-|', '@CMD', 'LIST'],
		'controller status' => ['-|', '@CMD', '$controller', 'STATUS'],
		'device status' => ['-|', '@CMD', '$controller', 'DISPLAY'],
	}
}

sub sudo {
	my ($this, $deep) = @_;
	# quick check when running check
	return 1 unless $deep;

	my $cmd = $this->{program};
	(
		"CHECK_RAID ALL=(root) NOPASSWD: $cmd LIST",
		"CHECK_RAID ALL=(root) NOPASSWD: $cmd * STATUS",
		"CHECK_RAID ALL=(root) NOPASSWD: $cmd * DISPLAY",
	);
}

# detect controllers for sas2ircu
sub detect {
	my $this = shift;

	my @ctrls;
	my $fh = $this->cmd('controller list');

	my $success = 0;
	my $state="";
	my $noctrlstate="No Controllers";
	while (<$fh>) {
		chomp;

		#         Adapter     Vendor  Device                        SubSys  SubSys
		# Index    Type          ID      ID    Pci Address          Ven ID  Dev ID
		# -----  ------------  ------  ------  -----------------    ------  ------
		#   0     SAS2008     1000h    72h     00h:03h:00h:00h      1028h   1f1eh
		if (my($c) = /^\s*(\d+)\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s*$/) {
			push(@ctrls, $c);
		}
		$success = 1 if /SAS2IRCU: Utility Completed Successfully/;

		# handle the case where there's no hardware present.
		# when there is no controller, we get
		# root@i41:/tmp$ /usr/sbin/sas2ircudsr LIST
		# LSI Corporation SAS2 IR Configuration Utility.
		# Version 18.00.00.00 (2013.11.18)
		# Copyright (c) 2009-2013 LSI Corporation. All rights reserved.

		# SAS2IRCU: MPTLib2 Error 1
		# root@i41:/tmp$ echo $?
		# 1

		if (/SAS2IRCU: MPTLib2 Error 1/) {
			$state = $noctrlstate;
			$success = 1 ;
		}

	}

	unless (close $fh) {
		#sas2ircu exits 1 (but close exits 256) when we close fh if we have no controller, so handle that, too
		if ($? != 256 && $state eq $noctrlstate) {
			$this->critical;
		}
	}
	unless ($success) {
		$this->critical;
	}

	return wantarray ? @ctrls : \@ctrls;
}

sub  trim { my $s = shift; $s =~ s/^\s+|\s+$//g; return $s };
sub ltrim { my $s = shift; $s =~ s/^\s+//;       return $s };
sub rtrim { my $s = shift; $s =~ s/\s+$//;       return $s };

sub check {
	my $this = shift;

	my @ctrls = $this->detect;

	my @status;
	my $numvols=0;
	# determine the RAID states of each controller
	foreach my $c (@ctrls) {
		my $fh = $this->cmd('controller status', { '$controller' => $c });

		my $novolsstate="No Volumes";
		my $state;
		my $success = 0;
		while (<$fh>) {
			chomp;

			# match adapter lines
			if (my($s) = /^\s*Volume state\s*:\s*(\w+)\s*$/) {
				$state = $s;
				$numvols++;
				if ($state ne "Optimal") {
					$this->critical;
				}
			}
			$success = 1 if /SAS2IRCU: Utility Completed Successfully/;

			##handle the case where there are no volumes configured
			#
			# SAS2IRCU: there are no IR volumes on the controller!
			# SAS2IRCU: Error executing command STATUS.

			if (/SAS2IRCU: there are no IR volumes on the controller/
				or /The STATUS command is not supported by the firmware currently loaded on controller/
			) {
				# even though this isn't the last line, go ahead and set success.
				$success = 1;
				$state = $novolsstate;
			}

		}

		unless (close $fh) {
			#sas2ircu exits 256 when we close fh if we have no volumes, so handle that, too
			if ($? != 256 && $state eq $novolsstate) {
				$this->critical;
				$state = $!;
			}
		}

		unless ($success) {
			$this->critical;
			$state = "SAS2IRCU Unknown exit";
		}

		unless ($state) {
			$state = "Unknown Error";
		}

		my $finalvolstate=$state;
		#push(@status, "ctrl #$c: $numvols Vols: $state");


		#####  now look at the devices.
		# Device is a Hard disk
		#   Enclosure #                             : 2
		#   Slot #                                  : 0
		#   SAS Address                             : 500065b-3-6789-abe0
		#   State                                   : Ready (RDY)
		#   Size (in MB)/(in sectors)               : 3815447/7814037167
		#   Manufacturer                            : ATA
		#   Model Number                            : ST4000DM000-1F21
		#   Firmware Revision                       : CC52
		#   Serial No                               : S30086G4
		#   GUID                                    : 5000c5006d27b344
		#   Protocol                                : SATA
		#   Drive Type                              : SATA_HDD

		$fh = $this->cmd('device status', { '$controller' => $c });
		$state="";
		$success = 0;
		my $enc="";
		my $slot="";
		my @data;
		my $device="";
		my $numslots=0;
		my $finalstate;
		my $finalerrors="";

		while (my $line = <$fh>) {
			chomp $line;
			# Device is a Hard disk
			# Device is a Hard disk
			# Device is a Enclosure services device
			#
			#lets make sure we're only checking disks.  we dont support other devices right now
			if ("$line" eq 'Device is a Hard disk') {
				$device='disk';
			} elsif ($line =~ /^Device/) {
				$device='other';
			}

			if ("$device" eq 'disk') {
				if ($line =~ /Enclosure #|Slot #|State /) {
					#find our enclosure #
					if ($line =~ /^  Enclosure # /) {
						@data = split /:/, $line;
						$enc=trim($data[1]);
						#every time we hit a new enclosure line, reset our state and slot
						undef $state;
						undef $slot;
					}
					#find our slot #
					if ($line =~ /^  Slot # /) {
						@data = split /:/, $line;
						$slot=trim($data[1]);
						$numslots++
					}
					#find our state
					if ($line =~ /^  State /) {
						@data = split /:/, $line;
						$state=ltrim($data[1]);

						#for test
						#if ($numslots == 10 ) { $state='FREDFISH';}

						#when we get a state, test on it and report it..
						if ($state =~ /Optimal|Ready/) {
							#do nothing at the moment.
						} else {
							$this->critical;
							$finalstate=$state;
							$finalerrors="$finalerrors ERROR:Ctrl$c:Enc$enc:Slot$slot:$state";
						}
					}
				}
			}

			if ($line =~ /SAS2IRCU: Utility Completed Successfully/) {
				$success = 1;
			}

		} #end while


		unless (close $fh) {
			$this->critical;
			$state = $!;
		}

		unless ($success) {
			$this->critical;
			$state = "SAS2IRCU Unknown exit";
		}

		unless ($state) {
			$state = "Unknown Error";
		}

		unless($finalstate) {
			$finalstate=$state;
		}

		#per controller overall report
		#push(@status, ":$numslots Drives:$finalstate:$finalerrors");
		push(@status, "ctrl #$c: $numvols Vols: $finalvolstate: $numslots Drives: $finalstate:$finalerrors:");

	}

	##if we didn't get a status out of the controllers and an empty ctrls array, we must not have any.
	unless (@status && @ctrls) {
		push(@status, "No Controllers");
	}

	return unless @status;

	$this->ok->message(join(', ', @status));
}

package smartctl;
use base 'plugin';

# no registering as standalone plugin
#push(@utils::plugins, __PACKAGE__);

sub program_names {
	__PACKAGE__;
}

sub commands {
	{
		'smartctl' => ['-|', '@CMD', '-H', '$dev', '$diskopt$disk'],
	}
}


sub sudo {
	my ($this, $deep) = @_;
	# quick check when running check
	return 1 unless $deep;

	# nothing, as not standalone plugin yet
}

# check for -H parameter for physical disks
# this is currently called out from cciss plugin
# @param device list
# device list being an array of:
# - device to check (/dev/cciss/c0d0)
# - disk options (-dcciss)
# - disk number (0..15)
sub check {
	my $this = shift;
	my @devs = @_;

	unless (@devs) {
		$this->warning;
		$this->message("No devices to check");
		return;
	}

	# status message for devs, latter just joined for shorter messages
	my %status;

	foreach my $ref (@devs) {
		my ($dev, $diskopt, $disk) = @$ref;

		my $fh = $this->cmd('smartctl', { '$dev' => $dev, '$diskopt' => $diskopt => '$disk' => $disk });
		while (<$fh>) {
			chomp;

			# SMART Health Status: HARDWARE IMPENDING FAILURE GENERAL HARD DRIVE FAILURE [asc=5d, ascq=10]
			if (my($s, $sc) = /SMART Health Status: (.*?)(\s*\[asc=\w+, ascq=\w+\])?$/) {
				# use shorter output, message that hpacucli would use
				if ($s eq 'HARDWARE IMPENDING FAILURE GENERAL HARD DRIVE FAILURE') {
					$s = 'Predictive Failure';
				}

				if ($s eq 'Predictive Failure') {
					$this->warning;
				} elsif ($s !~ '^OK') {
					$this->critical;
				}
				push(@{$status{$s}}, $dev.'#'.$disk);
			}
		}
		close($fh);
	}

	return unless %status;

	$this->ok->message($this->join_status(\%status));
}

package hpacucli;
use base 'plugin';

# register
push(@utils::plugins, __PACKAGE__);

sub program_names {
	qw(hpacucli hpssacli);
}

sub commands {
	{
		'controller status' => ['-|', '@CMD', 'controller', 'all', 'show', 'status'],
		'logicaldrive status' => ['-|', '@CMD', 'controller', '$target', 'logicaldrive', 'all', 'show'],
	}
}

sub sudo {
	my ($this, $deep) = @_;
	# quick check when running check
	return 1 unless $deep;

	my $cmd = $this->{program};
	(
		"CHECK_RAID ALL=(root) NOPASSWD: $cmd controller all show status",
		"CHECK_RAID ALL=(root) NOPASSWD: $cmd controller * logicaldrive all show",
	);
}

sub scan_targets {
	my $this = shift;

	# TODO: allow target customize:
	# hpacucli <target> is of format:
	#  [controller all|slot=#|wwn=#|chassisname="AAA"|serialnumber=#|chassisserialnumber=#|ctrlpath=#:# ]
	#  [array all|<id>]
	#  [physicaldrive all|allunassigned|[#:]#:#|[#:]#:#-[#:]#:#]
	#  [logicaldrive all|#]
	#  [enclosure all|#:#|serialnumber=#|chassisname=#]
	#  [licensekey all|<key>]

	# Scan controllers
	my (%targets);
	my $fh = $this->cmd('controller status');
	while (<$fh>) {
		# Numeric slot
		if (my($model, $slot) = /^(\S.+) in Slot (.+)/) {
			$slot =~ s/ \(RAID Mode\)//;
			$slot =~ s/ \(Embedded\)//;
			$targets{"slot=$slot"} = $model;
			$this->unknown if $slot !~ /^\d+$/;
			next;
		}
		# Named Entry
		if (my($model, $cn) = /^(\S.+) in (.+)/) {
			$targets{"chassisname=$cn"} = $cn;
			next;
		}
	}
	close $fh;

	return \%targets;
}

# Scan logical drives
sub scan_luns {
	my ($this, $targets) = @_;

	my %luns;
	while (my($target, $model) = each %$targets) {
		# check each controller
		my $fh = $this->cmd('logicaldrive status', { '$target' => $target });

		my ($array, %array);
		while (<$fh>) {
			# "array A"
			# "array A (Failed)"
			# "array B (Failed)"
			if (my($a, $s) = /^\s+array (\S+)(?:\s*\((\S+)\))?$/) {
				$array = $a;
				# Offset 0 is Array own status
				# XXX: I don't like this one: undef could be false positive
				$array{$array}[0] = $s || 'OK';
			}

			# skip if no active array yet
			next unless $array;

			# logicaldrive 1 (68.3 GB, RAID 1, OK)
			# capture only status
			if (my($drive, $s) = /^\s+logicaldrive (\d+) \([\d.]+ .B, [^,]+, ([^\)]+)\)$/) {
				# Offset 1 is each logical drive status
				$array{$array}[1]{$drive} = $s;
				next;
			}

			# Error: The controller identified by "slot=attr_value_slot_unknown" was not detected.
			if (/Error:/) {
				$this->unknown;
			}
		}
		$this->unknown unless close $fh;

		$luns{$target} = { %array };
	}

	return \%luns;
}

# parse hpacucli output into logical structure
sub parse {
	my $this = shift;

	my $targets = $this->scan_targets;
	if (!$targets) {
		return $targets;
	}
	my $luns = $this->scan_luns($targets);
	return { 'targets' => $targets, 'luns' => $luns };
}

sub check {
	my $this = shift;

	my $ctrl = $this->parse;
	unless ($ctrl) {
		$this->warning->message("No Controllers were found on this machine");
		return;
	}

	# status messages pushed here
	my @status;

	for my $target (sort {$a cmp $b} keys %{$ctrl->{targets}}) {
		my $model = $ctrl->{targets}->{$target};

		my @cstatus;
		foreach my $array (sort { $a cmp $b } keys %{$ctrl->{luns}->{$target}}) {
			my ($astatus, $ld) = @{$ctrl->{luns}->{$target}{$array}};

			# check array status
			if ($astatus ne 'OK') {
				$this->critical;
			}

			my @astatus;
			# extra details for non-normal arrays
			foreach my $lun (sort { $a cmp $b } keys %$ld) {
				my $s = $ld->{$lun};
				push(@astatus, "LUN$lun:$s");

				if ($s eq 'OK' or $s eq 'Disabled') {
				} elsif ($s eq 'Failed' or $s eq 'Interim Recovery Mode') {
					$this->critical;
				} elsif ($s eq 'Rebuild' or $s eq 'Recover') {
					$this->warning;
				}
			}
			push(@cstatus, "Array $array($astatus)[". join(',', @astatus). "]");
		}

		push(@status, "$model: ".join(', ', @cstatus));
	}

	return unless @status;

	$this->ok->message(join(', ', @status));
}

package areca;
## Areca SATA RAID Support
## requires cli64 or cli32 binaries
## For links to manuals and binaries, see this issue:
## https://github.com/glensc/nagios-plugin-check_raid/issues/10
use base 'plugin';

# register
push(@utils::plugins, __PACKAGE__);

sub program_names {
	qw(areca-cli areca_cli64 areca_cli32 cli64 cli32);
}

sub commands {
	{
		'rsf info' => ['-|', '@CMD', 'rsf', 'info'],
		'disk info' => ['-|', '@CMD', 'disk', 'info'],
	}
}

sub sudo {
	my ($this, $deep) = @_;
	# quick check when running check
	return 1 unless $deep;

	my $cmd = $this->{program};
	(
		"CHECK_RAID ALL=(root) NOPASSWD: $cmd rsf info",
		"CHECK_RAID ALL=(root) NOPASSWD: $cmd disk info",
	);
}

# plugin check
# can store its exit code in $this->status
# can output its message in $this->message
sub check {
	my $this = shift;

	## Check Array Status
	my (@status, %arrays);
	my $fh = $this->cmd('rsf info');
	while (<$fh>) {
=cut
 #  Name             Disks TotalCap  FreeCap MinDiskCap         State
 #  Name             Disks TotalCap  FreeCap DiskChannels       State
===============================================================================
 1  Raid Set # 000      23 34500.0GB    0.0GB   1500.0GB         Normal
 1  Raid Set # 00       15 15000.0GB    0.0GB 123G567C9AB48EF    Normal
 1  data                15 11250.0GB    0.0GB 123456789ABCDEF    Normal
 1  data                15 11250.0GB    0.0GB 123456789ABCDEF    Initializing
===============================================================================
=cut
		next unless (my($id, $n, $s) = m{^
			\s*(\d+)    # Id
			\s+(.+)     # Name
			\s+\d+      # Disks
			\s+\S+      # TotalCap
			\s+\S+      # FreeCap
			\s+\S+      # MinDiskCap/DiskChannels
			\s+(\S+)\s* # State
		$}x);

		# trim trailing spaces from name
		$n =~ s/\s+$//;

		if ($s =~ /[Rr]e[Bb]uild/) {
			$this->warning;
		} elsif ($s !~ /[Nn]ormal|[Rr]e[Bb]uild|Checking|Initializing/) {
			$this->critical;
		}

		push(@status, "Array#$id($n): $s");

		$arrays{$n} = [ $id, $s ];
	}
	close $fh;

	## Check Drive Status
	$fh = $this->cmd('disk info');
	my %drivestatus;
	while (<$fh>) {
		chomp;
=cut
  # Enc# Slot#   ModelName                        Capacity  Usage
===============================================================================
  1  01  Slot#1  N.A.                                0.0GB  N.A.
  8  01  Slot#8  N.A.                                0.0GB  N.A.
  9  02  SLOT 01 ST31500341AS                     1500.3GB  Raid Set # 000
 11  02  SLOT 03 ST31500341AS                     1500.3GB  Raid Set # 000

  # Ch# ModelName                       Capacity  Usage
===============================================================================
  1  1  ST31000340NS                    1000.2GB  Raid Set # 00
  6  6  ST31000340NS                    1000.2GB  Raid Set # 00
  3  3  WDC WD7500AYYS-01RCA0            750.2GB  data
  4  4  WDC WD7500AYYS-01RCA0            750.2GB  data
 16 16  WDC WD7500AYYS-01RCA0            750.2GB  HotSpare[Global]
=cut
		next unless my($id, $model, $usage) = m{^
			\s*(\d+)      # Id
			\s+\d+        # Channel/Enclosure (not reliable, tests 1,2,12 differ)
			\s+(.+)       # ModelName
			\s+\d+.\d\S+  # Capacity
			\s+(.+)       # Usage (Raid Name)
		}x;

		# trim trailing spaces from name
		$usage =~ s/\s+$//;

		# Asssume model N.A. means the slot not in use
		# we could also check for Capacity being zero, but this seems more
		# reliable.
		next if $usage eq 'N.A.';

		# use array id in output: shorter
		my $array_id = defined($arrays{$usage}) ? ($arrays{$usage})->[0] : undef;
		my $array_name = defined $array_id ? "Array#$array_id" : $usage;

		# assume critical if Usage is not one of:
		# - existing Array name
		# - HotSpare
		# - Rebuild
		if (defined($arrays{$usage})) {
			# Disk in Array named $usage
			push(@{$drivestatus{$array_name}}, $id);
		} elsif ($usage =~ /[Rr]e[Bb]uild/) {
			# rebuild marks warning
			push(@{$drivestatus{$array_name}}, $id);
			$this->warning;
		} elsif ($usage =~ /HotSpare/) {
			# hotspare is OK
			push(@{$drivestatus{$array_name}}, $id);
		} elsif ($usage =~ /Pass Through/) {
			# Pass Through is OK
			push(@{$drivestatus{$array_name}}, $id);
		} else {
			push(@{$drivestatus{$array_name}}, $id);
			$this->critical;
		}
	}
	close $fh;

	push(@status, "Drive Assignment: ".$this->join_status(\%drivestatus)) if %drivestatus;

	$this->ok->message(join(', ', @status));
}

package dmraid;
use base 'plugin';

# register
push(@utils::plugins, __PACKAGE__);

sub program_names {
	__PACKAGE__;
}

sub commands {
	{
		'dmraid' => ['-|', '@CMD', '-r'],
	}
}

sub active ($) {
	my ($this) = @_;

	# easy way out. no executable
	return 0 unless -e $this->{commands}{dmraid}[1];

	# check if dmraid is empty
	return keys %{$this->parse} > 0;
}

sub sudo {
	my ($this, $deep) = @_;
	# quick check when running check
	return 1 unless $deep;

	my $cmd = $this->{program};
	"CHECK_RAID ALL=(root) NOPASSWD: $cmd -r";
}

# parse arrays, return data indexed by array name
sub parse {
	my $this = shift;

	my (%arrays);
	my $fh = $this->cmd('dmraid');
	while (<$fh>) {
		chomp;
		next unless (my($device, $format, $name, $type, $status, $sectors) = m{^
			# /dev/sda: jmicron, "jmicron_JRAID", mirror, ok, 781385728 sectors, data@ 0
			(/dev/\S+):\s # device
			(\S+),\s # format
			"([^"]+)",\s # name
			(mirror|stripe[d]?),\s # type
			(\w+),\s # status
			(\d+)\ssectors,.* # sectors
		$}x);
		next unless $this->valid($device);

		# trim trailing spaces from name
		$name =~ s/\s+$//;

		my $member = {
			'device' => $device,
			'format' => $format,
			'type' => $type,
			'status' => $status,
			'size' => $sectors,
		};

		push(@{$arrays{$name}}, $member);
	}
	close $fh;

	return \%arrays;
}


# plugin check
# can store its exit code in $this->status
# can output its message in $this->message
sub check {
	my $this = shift;
	my (@status);

	## Check Array and Drive Status
	my $arrays = $this->parse;
	while (my($name, $array) = each(%$arrays)) {
		my @s;
		foreach my $dev (@$array) {
			if ($dev->{status} =~ m/sync|rebuild/i) {
				$this->warning;
			} elsif ($dev->{status} !~ m/ok/i) {
				$this->critical;
			}
			my $size = $this->format_bytes($dev->{size});
			push(@s, "$dev->{device}($dev->{type}, $size): $dev->{status}");
		}
		push(@status, "$name: " . join(', ', @s));
	}

	return unless @status;

	# denote that this plugin as ran ok, not died unexpectedly
	$this->ok->message(join(' ', @status));
}

{
package main;

# do nothing in library mode
return 1 if caller;

use strict;
use warnings;
use Getopt::Long;

my ($opt_V, $opt_d, $opt_h, $opt_W, $opt_S, $opt_p, $opt_l);
my (%ERRORS) = (OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3);
my ($VERSION) = "3.2.3";
my ($message, $status, $perfdata, $longoutput);
my ($noraid_state) = $ERRORS{UNKNOWN};

#####################################################################
$ENV{'BASH_ENV'} = '';
$ENV{'ENV'} = '';

# find first existing file from list of file paths
sub find_file {
	for my $file (@_) {
		return $file if -f $file;
	}
	return undef;
}

sub print_usage() {
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

sub print_help() {
	print "check_raid, v$VERSION\n";
	print "Copyright (c) 2004-2006 Steve Shipway,
Copyright (c) 2009-2015, Elan Ruusamäe <glen\@pld-linux.org>

This plugin reports the current server's RAID status
https://github.com/glensc/nagios-plugin-check_raid

";
	print_usage();
}

# return first "#includedir" directive from $sudoers file
sub parse_sudoers_includedir {
	my ($sudoers) = @_;

	open my $fh, '<', $sudoers or die "Can't open: $sudoers: $!";
	while (<$fh>) {
		if (my ($dir) = /^#includedir\s+(.+)$/) {
			return $dir;
		}
	}
	close $fh or die $!;

	return undef;
}

# return size of file
# does not check for errors
sub filesize {
	my ($file) = @_;
	return (stat($file))[7];
}

# get contents of a file
sub cat {
	my ($file) = @_;
	open(my $fh, '<', $file) or die "Can't open $file: $!";
	local $/ = undef;
	local $_ = <$fh>;
	close($fh) or die $!;

	return $_;
}

# return FALSE if files are identical
# return TRUE if files are different
# return TRUE if any of the files is missing
sub filediff {
	my ($file1, $file2) = @_;

	# return TRUE if neither of them exist
	return 1 unless -f $file1;
	return 1 unless -f $file2;

	my $f1 = cat($file1);
	my $f2 = cat($file2);

	# wipe comments
	$f1 =~ s/^#.+$//m;
	$f2 =~ s/^#.+$//m;

	# return TRUE if they differ
	return $f1 ne $f2;
}

# update sudoers file
#
# if sudoers config has "#includedir" directive, add file to that dir
# otherwise update main sudoers file
sub sudoers {
	my ($dry_run) = @_;

	# build values to be added
	# go over all registered plugins
	my @sudo;
	foreach my $pn (@utils::plugins) {
		my $plugin = $pn->new;

		# skip inactive plugins (disabled or no tools available)
		next unless $plugin->active;

		# collect sudo rules
		my @rules = $plugin->sudo(1) or next;

		push(@sudo, @rules);
	}

	unless (@sudo) {
		warn "Your configuration does not need to use sudo, sudoers not updated\n";
		return;
	}

	my @rules = join "\n", (
		"",
		# setup alias, so we could easily remove these later by matching lines with 'CHECK_RAID'
		# also this avoids installing ourselves twice.
		"# Lines matching CHECK_RAID added by $0 -S on ". scalar localtime,
		"User_Alias CHECK_RAID=nagios",
		"Defaults:CHECK_RAID !requiretty",

		# actual rules from plugins
		join("\n", @sudo),
		"",
	);

	if ($dry_run) {
		warn "Content to be inserted to sudo rules:\n";
		warn "--- sudoers ---\n";
		print @rules;
		warn "--- sudoers ---\n";
		return;
	}

	my $sudoers = find_file('/usr/local/etc/sudoers', '/etc/sudoers');
	my $visudo = utils::which('visudo');

	die "Unable to find sudoers file.\n" unless -f $sudoers;
	die "Unable to write to sudoers file '$sudoers'.\n" unless -w $sudoers;
	die "visudo program not found\n" unless -x $visudo;

	# parse sudoers file for "#includedir" directive
	my $sudodir = parse_sudoers_includedir($sudoers);
	if ($sudodir) {
		# sudo will read each file in /etc/sudoers.d, skipping file names that
		# end in ~ or contain a . character to avoid causing problems with
		# package manager or editor temporary/backup files
		$sudoers = "$sudodir/check_raid";
	}

	warn "Updating file $sudoers\n";

	# NOTE: secure as visudo itself: /etc is root owned
	my $new = $sudoers.".new.".$$;

	# setup to have sane perm for new sudoers file
	umask(0227);

	open my $fh, '>', $new or die $!;

	# insert old sudoers
	if (!$sudodir) {
		open my $old, '<', $sudoers or die $!;
		while (<$old>) {
			print $fh $_;
		}
		close $old or die $!;
	}

	# insert the rules
	print $fh @rules;
	close $fh;

	# validate sudoers
	system($visudo, '-c', '-f', $new) == 0 or unlink($new),exit $? >> 8;

	# check if they differ
	if (filediff($sudoers, $new)) {
		# use the new file
		rename($new, $sudoers) or die $!;
		warn "$sudoers file updated.\n";
	} else {
		warn "$sudoers file not changed.\n";
		unlink($new);
	}
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
sub git_hash_object() {
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
	'resync=s' => sub { setstate(\$plugin::resync_status, @_); },
	'check=s' => sub { setstate(\$plugin::check_status, @_); },
	'noraid=s' => sub { setstate(\$noraid_state, @_); },
	'bbulearn=s' => sub { setstate(\$plugin::bbulearn_status, @_); },
	'cache-fail=s' => sub { setstate(\$plugin::cache_fail_status, @_); },
	'plugin-option=s' => sub { my($k, $v) = split(/=/, $_[1], 2); $plugin_options{$k} = $v; },
	'bbu-monitoring' => \$plugin::bbu_monitoring,
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
	if ($plugin->message or $noraid_state == $ERRORS{UNKNOWN}) {
		$status = $plugin->status if $plugin->status > $status;
	} else {
		$status = $noraid_state if $noraid_state > $status;
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
} elsif ($noraid_state != $ERRORS{UNKNOWN}) {
	$status = $noraid_state;
	print "No RAID configuration found\n";
} else {
	$status = $ERRORS{UNKNOWN};
	print "No RAID configuration found (tried: ", join(', ', @plugins), ")\n";
}
exit $status;

} # package main

package SerialLine;
# Package dealing with connecting to serial line and handling UUCP style locks.

use Carp;

sub new {
	my $self = shift;
	my $class = ref($self) || $self;
	my $device = shift;

	my $this = {
		lockdir => "/var/lock",

		@_,

		lockfile => undef,
		device => $device,
		fh => undef,
	};

	bless($this, $class);
}

sub lock {
	my $self = shift;
	# create lock in style: /var/lock/LCK..ttyS0
	my $device = shift;
	my ($lockfile) = $self->{device} =~ m#/dev/(.+)#;
	$lockfile = "$self->{lockdir}/LCK..$lockfile";
	if (-e $lockfile) {
		return 0;
	}
	open(my $fh, '>', $lockfile) || croak "Can't create lock: $lockfile\n";
	print $fh $$;
	close($fh);

	$self->{lockfile} = $lockfile;
}

sub open {
	my $self = shift;

	$self->lock or return;

	# open the device
	open(my $fh, '+>', $self->{device}) || croak "Couldn't open $self->{device}, $!\n";

	$self->{fh} = $fh;
}

sub close {
	my $self = shift;
	if ($self->{fh}) {
		close($self->{fh});
		undef($self->{fh});
		unlink $self->{lockfile} or carp $!;
	}
}

sub DESTROY {
	my $self = shift;
	$self->close();
}
