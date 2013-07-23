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
# 2009-2013 Elan Ruusamäe <glen@pld-linux.org>

# Requires: Perl 5.8 for the open(my $fh , '-|', @CMD) syntax.
# You can workaround for earlier Perl it as:
# open(my $fh , join(" ", @CMD, '|') or return;
# http://perldoc.perl.org/perl58delta.html#PerlIO-is-Now-The-Default
#
# License: GPL v2
# Homepage: https://github.com/glensc/nagios-plugin-check_raid
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
#
# Changes:
# Version 1.1: IPS; Solaris, AIX, Linux software RAID; megaide
# Version 2.0: Added megaraid, mpt (serveraid), aaccli (serveraid)
# Version 2.1:
# - Made script more generic and secure
# - Added gdth
# - Added dpt_i2o
# - Added 3ware SATA RAID
# - Added Adaptec AAC-RAID via arcconf
# - Added LSI MegaRaid via megarc
# - Added LSI MegaRaid via CmdTool2
# - Added HP/Compaq Smart Array via cciss_vol_status
# - Added HP MSA1500 check via serial line
# - Added checks via HP hpacucli utility.
# - Added hpsa module support for cciss_vol_status
# - Added smartctl checks for cciss disks
# Version 2.2:
# - Project moved to github: https://github.com/glensc/nagios-plugin-check_raid
# - SAS2IRCU support
# - Areca SATA RAID Support
# Version 3.0:
# - Rewritten to be more modular, this allows better code testing
# - Improvements to plugins: arcconf, tw_cli, gdth, cciss
# Version 3.0.1:
# - Fixes to cciss plugin, improvements in mpt, areca, mdstat plugins
# Version 3.0.x:
# - Detecting SCSI devices or hosts with lsscsi
# - Updated to handle ARCCONF 9.30 output
# - Fixed -W option handling (#29)

use warnings;
use strict;

{
package utils;

my @EXPORT = qw(which $sudo);
my @EXPORT_OK = @EXPORT;

# registered plugins
our @plugins;

# devices to ignore
our @ignore;

# debug level
our $debug = 0;

# paths for which()
our @paths = split /:/, $ENV{'PATH'};
unshift(@paths, qw(/usr/local/nrpe /usr/local/bin /sbin /usr/sbin /bin /usr/sbin));

# lookup program from list of possibele filenames
# search is performed from $PATH plus additional hardcoded @paths
sub which {
	for my $prog (@_) {
		for my $path (@paths) {
			return "$path/$prog" if -x "$path/$prog";
		}
	}
	return undef;
}

our $sudo = which('sudo');
} # package utils

{
package plugin;
use Carp qw(croak);

# Nagios standard error codes
my (%ERRORS) = (OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3);

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
		sudo => $class->sudo ? $utils::sudo : '',
		@_,
		name => $class,
		status => undef,
		message => undef,
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

	# program not found
	return 0 unless $this->{program};

	# program not executable
	-x $this->{program};
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

# setup status message text
sub message {
	my ($this, $message) = @_;
	if (defined $message) {
		# TODO: append if already something there
		$this->{message} = $message;
	}
	$this->{message};
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

# build up command for $command
# returns open filehandle to process output
# if command fails, program is exited (caller needs not to worry)
sub cmd {
	my ($this, $command, $cb) = @_;

	# build up command
	my @CMD = $this->{program};

	# add sudo if program needs
	unshift(@CMD, $this->{sudo}) if $> and $this->{sudo};

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

# scan lsscsi output
sub scan {
	my $this = shift;

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

	return wantarray ? @sdevs : \@sdevs;
}

package metastat;
# Solaris, software RAID
use base 'plugin';

# Status: BROKEN: no test data
#push(@utils::plugins, __PACKAGE__);

sub program_names {
	__PACKAGE__;
}

sub commands {
	{
		'status' => ['-|', '@CMD'],
	}
}

sub sudo {
	my $cmd = shift->{program};
	"CHECK_RAID ALL=(root) NOPASSWD: $cmd"
}

sub check {
	my $this = shift;

	my ($d, $sd);

	# status messages pushed here
	my @status;

	my $fh = $this->cmd('status');
	while (<$fh>) {
		if (/^(\S+):/) { $d = $1; $sd = ''; next; }
		if (/Submirror \d+:\s+(\S+)/) { $sd = $1; next; }
		if (my($s) = /State: (\S.+)/) {
			if ($sd and valid($sd) and valid($d)) {
				if ($s =~ /Okay/i) {
					# no worries...
				} elsif ($s =~ /Resync/i) {
					$this->warning;
				} else {
					$this->critical;
				}
				push(@status, "$d:$sd:$s");
			}
		}
	}
	close $fh;

	return unless @status;

	$this->message(join(' ', @status));
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
	while (<$fh>) {
		chomp;

		# md1 : active raid1 sdb2[0] sda2[1]
		if (my($d, $p) = /^(\S+)\s+:\s+(?:\S+)\s+(\S+)\s+/) {
			# first line resets %md
			%md = (dev => $d, personality => $p);
			@{$md{failed_disks}} = $_ =~ m/(\S+)\[\d+\]\(F\)/g;
			next;
		}

		# linux-2.6.33/drivers/md/dm-raid1.c, device_status_char
		# A => Alive - No failures
		# D => Dead - A write failure occurred leaving mirror out-of-sync
		# S => Sync - A sychronization failure occurred, mirror out-of-sync
		# R => Read - A read failure occurred, mirror data unaffected
		# U => for the rest

		#"      8008320 blocks [2/2] [UU]"
		#"      58291648 blocks 64k rounding" - linear
		if (my($b, $s) = /^\s+(\d+)\sblocks\s+.*?(?:\s+\[([ADSRU_]+)\])?$/) {
			$md{status} = $s;
			$md{blocks} = $b;
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
		}

		# we need empty line denoting end of one md
		next unless /^\s*$/;

		next unless $this->valid($md{dev});

		push(@md, { %md } ) if %md;
	}
	close $fh;

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
		my $s = "$md{dev}($size $md{personality}):";

		# raid0 is just there or its not. raid0 can't degrade.
		# same for linear, no $md_status available
		if ($md{personality} =~ /linear|raid0/) {
			$s .= "OK";
			
		} elsif ($md{resync_status}) {
			$this->warning;
			$s .= "$md{status} ($md{resync_status})";
			
		} elsif ($md{status} =~ /_/) {
			$this->critical;
			$s .= "F:". join(",", @{$md{failed_disks}}) .":$md{status}";

		} elsif (@{$md{failed_disks}} > 0) {
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
	);
}

sub check {
	my $this = shift;

	my $fh = $this->cmd('pdlist');
	my (@status, @devs, @vols, %cur, %cur_vol);
	while (<$fh>) {
		if (my($s) = /Device Id: (\S+)/) {
			push(@devs, { %cur }) if %cur;
			%cur = ( dev => $s, state => undef, name => undef );
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
			$cur{state} = $s;
			next;
		}

		if (my($s) = /Inquiry Data: (.+)/) {
			# trim some spaces
			$s =~ s/\s+/ /g; $s =~ s/^\s+|\s+$//g;
			$cur{name} = $s;
			next;
		}
	}
	close $fh;
	push(@devs, { %cur }) if %cur;

	$fh = $this->cmd('ldinfo');
	while (<$fh>) {
		if (my($s) = /Name\s*:\s*(\S+)/) {
			push(@vols, { %cur_vol }) if %cur_vol;
			%cur_vol = ( name => $s, state => undef );
			next;
		}
		if (my($s) = /State\s*:\s*(\S+)/) {
			$cur_vol{state} = $s;
			next;
		}
	}
	close $fh;
	push(@vols, { %cur_vol }) if %cur_vol;

	my @vstatus;
	foreach my $vol (@vols) {
		# It's possible to create volumes without a name
		if (!$vol->{name}) {
			$vol->{name} = 'NoName';
		}

		push(@vstatus, sprintf "%s:%s", $vol->{name}, $vol->{state});
		if ($vol->{state} ne 'Optimal') {
			$this->critical;
		}
	}

	my %dstatus;
	foreach my $dev (@devs) {
		if ($dev->{state} eq 'Online' || $dev->{state} eq 'Hotspare' || $dev->{state} eq 'Unconfigured(good)') {
			push(@{$dstatus{$dev->{state}}}, sprintf "%02d", $dev->{dev});

		} else {
			$this->critical;
			# TODO: process other statuses
			push(@{$dstatus{$dev->{state}}}, sprintf "%02d (%s)", $dev->{dev}, $dev->{name});
		}
	}

	push(@status,
		'Volumes(' . ($#vols + 1) . '): ' . join(',', @vstatus) .
		'; Devices('. ($#devs + 1) . '): ' . $this->join_status(\%dstatus));

	return unless @status;

	# denote this plugin as ran ok
	$this->ok;

	$this->message(join(' ', @status));
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

		if ($c =~ /SYN|RBL/i ) { # resynching
			$this->warning;
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
			$this->warning if ($stat eq "Verify");
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
			$this->warning if ($stat eq "Verify");
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
		'status' => ['-|', '@CMD'],
		'sync status' => ['-|', '@CMD', '-n'],
	}
}

sub sudo {
	my ($this, $deep) = @_;
	# quick check when running check
	return 1 unless $deep;

	my $cmd = $this->{program};
	(
	"CHECK_RAID ALL=(root) NOPASSWD: $cmd",
	"CHECK_RAID ALL=(root) NOPASSWD: $cmd -n",
	);
}

sub parse {
	my $this = shift;

	my (%ld, %pd);
	my $fh = $this->cmd('status');

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
			warn "mpt unparsed: [$_]\n";
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
			elsif (my($scsi_id, $percent) = /^scsi_id:(\d)+ (\d+)%/) {
				$pd{$scsi_id}{resync} = int($percent);
			} else {
				warn "mpt: [$_]\n";
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

	my $status = $this->parse;

	# process logical units
	while (my($d, $u) = each %{$status->{logical}}) {
		next unless $this->valid($d);
		my $s = $u->{status};
		if ($s =~ /INITIAL|INACTIVE|RESYNC/) {
			$this->warning;
		} elsif ($s =~ /DEGRADED|FAILED/) {
			$this->critical;
		} elsif ($s !~ /ONLINE|OPTIMAL/) {
			$this->unknown;
		}
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
					warn "[$section] [$_]\n";
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
					warn "[$section] [$_]\n";
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
					warn "[$section] [$_]\n";
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
# TODO: rename to 3ware?
# 3ware SATA RAID
# check designed from check_3ware.sh by:
# Sander Klein <sander [AT] pictura [dash] dp [DOT] nl>
# http://www.pictura-dp.nl/
# Version 20070706
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

sub check {
	my $this = shift;

	# status messages pushed here
	my @status;

	my (@c);
	# scan controllers
	my $fh = $this->cmd('info');
	while (<$fh>) {
		if (my($c, $model) = /^(c\d+)\s+(\S+)/) {
			push(@c, [$c, $model]);
		}
	}
	close $fh;

	unless (@c) {
		$this->warning;
		$this->message("No Adapters were found on this machine");
		return;
	}

	for my $i (@c) {
		my ($c, $model) = @$i;
		# check each unit on controllers
		$fh = $this->cmd('unitstatus', { '$controller' => $c });
		my @cstatus;
		while (<$fh>) {
			next unless (my($u, $s, $p, $p2) = /^(u\d+)\s+\S+\s+(\S+)\s+(\S+)\s+(\S+)/);

			if ($s eq 'OK') {
				push(@cstatus, "$u:$s");

			} elsif ($s =~ 'INITIALIZING|VERIFYING') {
				$this->warning;
				push(@cstatus, "$u:$s $p2");

			} elsif ($s eq 'MIGRATING') {
				$this->warning;
				push(@cstatus, "$u:$s $p2");

			} elsif ($s eq 'REBUILDING') {
				$this->warning;
				push(@cstatus, "$u:$s $p");

			} elsif ($s eq 'DEGRADED') {
				$this->critical;
				push(@cstatus, "$u:$s");
			} else {
				push(@cstatus, "$u:$_");
				$this->unknown;
			}
			push(@status, "$c($model): ". join(',', @cstatus));
		}
		close $fh;

		# check individual disk status
		$fh = $this->cmd('drivestatus', { '$controller' => $c });
		my (@p, @ds);
		while (<$fh>) {
			next unless (my($p, $s,) = /^(p\d+)\s+(\S+)\s+.+\s+.+\s+.+/);
			push(@ds, "$p:$s");
			foreach (@ds) {
				$this->critical unless (/p\d+:(OK|NOT-PRESENT)/);
			}
		}

		push(@status, "(disks: ".join(' ', @ds). ")");
		close $fh;
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
	$this->unknown->message("Parse Error: $message");
}

# NB: side effect: changes current directory to /var/log
sub parse {
	my $this = shift;

	# we chdir to /var/log, as tool is creating 'UcliEvt.log'
	chdir('/var/log') || chdir('/');

	# Controller information, Logical device info
	my (%c, @ld, $ld);

	my $count = 0;
	my $ok = 0;
	my $fh = $this->cmd('getstatus');
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
		} else {
			$this->unknown->message("Unknown line: [$_]");
		}
	}
	close($fh);
	$c{tasks} = { %task } if %task;

	if ($count > 1) {
		warn "> 1 controllers found, this is not yet supported";
	}

	if ($count == 0) {
		# if command completed, but no controllers,
		# assume no hardware present
		if (!$ok) {
			$this->unknown->message("No controllers found!");
		}
		return undef;
	}

	$fh = $this->cmd('getconfig');
	my @status;
	my $section;
	$ok = 0;
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
			if ($c != $count) {
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
				next;
				$ld = undef;
			}
			$this->parse_error($_);
		}

		next unless defined $section;

		if ($section eq 'Controller information') {
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
			} elsif (my($bs) = /Status\s*:\s*(.*)$/) {
				# This could be ZMM status as well
				if ($bs =~ /ZMM/) {
					$c{zmm_status} = $bs;
				} else {
					$c{battery_status} = $bs;
				}
			} elsif (my($bt) = /Over temperature\s*:\s*(.+)$/) {
				$c{battery_overtemp} = $bt;
			} elsif (my($bc) = /Capacity remaining\s*:\s*(\d+)\s*percent.*$/) {
				$c{battery_capacity} = int($bc);
			} elsif (my($d, $h, $m) = /Time remaining \(at current draw\)\s*:\s*(\d+) days, (\d+) hours, (\d+) minutes/) {
				$c{battery_time} = int($d) * 1440 + int($h) * 60 + int($m);
				$c{battery_time_full} = "${d}d${h}h${m}m";
			}

		} elsif ($section eq 'Physical Device information') {
			# nothing useful

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
		} else {
			warn "NOT PARSED: [$section] [$_]\n";
		}
	}

	close $fh;

	$this->unknown->message("Command did not succeed") unless $ok;

	return { controller => \%c, logical => \@ld };
}

sub check {
	my $this = shift;

	my $ctrl = $this->parse;
	$this->unknown,return unless $ctrl;

	# status messages pushed here
	my @status;

	# check for controller status
	for my $c ($ctrl->{controller}) {
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
		if ($c->{tasks}->{operation} ne 'None') {
			# just print it. no status change
			my $task = $c->{tasks};
			push(@status, "$task->{type} #$task->{device}: $task->{operation}: $task->{status} $task->{percent}%");
		}

		# ZMM (Zero-Maintenance Module) status
		if (defined($c->{zmm_status})) {
			push(@status, "ZMM Status: $c->{zmm_status}");
		}

		# Battery status
		if (defined($c->{battery_status}) and $c->{battery_status} ne "Not Installed") {
			push(@status, "Battery Status: $c->{battery_status}");

			if ($c->{battery_overtemp} ne "No") {
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
		}
	}

	# check for logical device
	for my $ld (@{$ctrl->{logical}}) {
		next unless $ld; # FIXME: fix that script assumes controllers start from '0'

		$this->critical if $ld->{status} !~ /Optimal|Okay/;

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

	$this->ok->message(join(', ', @status));
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
		'detect hpsa' => ['<', '/sys/module/hpsa/refcnt'],
		'controller status' => ['-|', '@CMD', '@devs'],

		'detect cciss' => ['<', '/proc/driver/cciss'],
		'cciss proc' => ['<', '/proc/driver/cciss/$controller'],
	}
}

sub sudo {
	my ($this, $deep) = @_;

	# quick check when running check
	return 1 unless $deep;

	my $cmd = $this->{program};

	my @sudo;
	my @cciss_devs = $this->detect;
	if (@cciss_devs) {
		my $c = join(' ', @cciss_devs);
		push(@sudo, "CHECK_RAID ALL=(root) NOPASSWD: $cmd $c");
	}

	my @cciss_disks = $this->detect_disks(@cciss_devs);
	if (@cciss_disks) {
		my $smartctl = smartctl->new();
		my $cmd = $smartctl->{program};
		foreach my $ref (@cciss_disks) {
			my ($dev, $diskopt, $disk) = @$ref;
			# escape comma for sudo
			$diskopt =~ s/,/\\$&/g;
			push(@sudo, "CHECK_RAID ALL=(root) NOPASSWD: $cmd -H $dev $diskopt$disk");
		}
	}

	return @sudo;
}

# detects if hpsa (formerly cciss) is present in system
sub detect {
	my $this = shift;

	my ($fh, @devs);

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

	# add all devs at once, cciss_vol_status can do that
	my $fh = $this->cmd('controller status', { '@devs' => \@devs });
	while (<$fh>) {
		chomp;
		# strip for better pattern matching
		s/\.\s*$//;

		# /dev/cciss/c0d0: (Smart Array P400i) RAID 1 Volume 0 status: OK
		# /dev/sda: (Smart Array P410i) RAID 1 Volume 0 status: OK.
		if (my($s) = /status: (.*?)$/) {
			if ($s !~ '^OK') {
				$this->critical;
			}
			push(@status, $_);
		}
	}
	close($fh);

	unless (@status) {
		return;
	}

	# denote this plugin as ran ok
	$this->ok;

	$this->message(join(', ', @status));

	# allow skip for testing
	unless ($this->{no_smartctl}) {
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
#push(@utils::plugins, __PACKAGE__);

sub new {
	my $self = shift;
	$self->SUPER::new(tty_device => "/dev/ttyS0", @_);
}

sub active {
	my $this = shift;
	return $this->detect;
}

# check from /sys if there are any MSA VOLUME's present.
sub detect {
	my $this = shift;

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

	my $ctldevice = $this->{tty_device};

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
		# Surface Scan:   Running, LUN 10 (68% Complete)
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
		# Expansion:      Complete.
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
	);
}

# detect controllers for sas2ircu
sub detect {
	my $this = shift;

	my @ctrls;
	my $fh = $this->cmd('controller list');

	my $success = 0;
	while (<$fh>) {
		chomp;
		#		  Adapter     Vendor  Device                        SubSys  SubSys
		# Index    Type          ID      ID    Pci Address          Ven ID  Dev ID
		# -----  ------------  ------  ------  -----------------    ------  ------
		#   0     SAS2008     1000h    72h     00h:03h:00h:00h      1028h   1f1eh
		if (my($c) = /^\s*(\d+)\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s*$/) {
			push(@ctrls, $c);
		}
		$success = 1 if /SAS2IRCU: Utility Completed Successfully/;
	}

	unless (close $fh) {
		$this->critical;
	}
	unless ($success) {
		$this->critical;
	}

	return wantarray ? @ctrls : \@ctrls;
}

sub check {
	my $this = shift;

	my @ctrls = $this->detect;

	my @status;
	# determine the RAID states of each controller
	foreach my $c (@ctrls) {
		my $fh = $this->cmd('controller status', {  '$controller' => $c });

		my $state;
		my $success = 0;
		while (<$fh>) {
			chomp;

			# match adapter lines
			if (my($s) = /^\s*Volume state\s*:\s*(\w+)\s*$/) {
				$state = $s;
				if ($state ne "Optimal") {
					$this->critical;
				}
			}
			$success = 1 if /SAS2IRCU: Utility Completed Successfully/;
		}

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

		push(@status, "ctrl #$c: $state")
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
	__PACKAGE__;
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

sub check {
	my $this = shift;

	# status messages pushed here
	my @status;

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
		if (my($model, $slot) = /^(\S.+) in Slot (\d+)/) {
			$targets{"slot=$slot"} = $model;
			next;
		}
		# Named Entry
		if (my($model, $cn) = /^(\S.+) in (.+)/) {
			$targets{"chassisname=$cn"} = $cn;
			next;
		}
	}
	close $fh;

	unless (%targets) {
		$this->warning;
		$this->message("No Controllers were found on this machine");
		return;
	}


	# Scan logical drives
	while (my($target, $model) = each %targets) {
		# check each controllers
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
			if (my($drive, $s) = /^\s+logicaldrive (\d+) \([\d.]+ .B, [^,]+, (\S+)\)$/) {
				# Offset 1 is each logical drive status
				$array{$array}[1]{$drive} = $s;
			}
		}
		close $fh;

		my @cstatus;
		while (my($array, $d) = each %array) {
			my ($astatus, $ld) = @$d;

			if ($astatus eq 'OK') {
				push(@cstatus, "Array $array($astatus)");
			} else {
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

		# Asssume model N.A. means the slot not in use
		# we could also check for Capacity being zero, but this seems more
		# reliable.
		next if $usage eq 'N.A.';

		# trim trailing spaces from name
		$usage =~ s/\s+$//;

		# use array id in output: shorter
		my $array_id = defined($arrays{$usage}) ?  ($arrays{$usage})->[0] : undef;
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
		} else {
			push(@{$drivestatus{$array_name}}, $id);
			$this->critical;
		}
	}
	close $fh;

	push(@status, "Drive Assignment: ".$this->join_status(\%drivestatus)) if %drivestatus;

	$this->ok->message(join(', ', @status));
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
my ($VERSION) = "3.0.1";
my ($message, $status);

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
	"";
}

sub print_help() {
	print "check_raid, v$VERSION\n";
	print "Copyright (c) 2004-2006 Steve Shipway, Copyright (c) 2009-2013, Elan Ruusamäe <glen\@pld-linux.org>

This plugin reports the current server's RAID status
https://github.com/glensc/nagios-plugin-check_raid

";
	print_usage();
}

sub sudoers {
	# build values to be added
	my @sudo;

	# go over all registered plugins
	foreach my $pn (@utils::plugins) {
		my $plugin = $pn->new;

		# skip inactive plugins (disabled or no tools available)
		next unless $plugin->active;

		# collect sudo rules
		my @rules = $plugin->sudo(1) or next;

		push(@sudo, @rules);
	}


	unless (@sudo) {
		print "Your configuration does not need to use sudo, sudoers not updated\n";
		return;
	}

	my $sudoers = find_file('/usr/local/etc/sudoers', '/etc/sudoers');
	my $visudo = utils::which('visudo');

	die "Unable to find sudoers file.\n" unless -f $sudoers;
	die "Unable to write to sudoers file '$sudoers'.\n" unless -w $sudoers;
	die "visudo program not found\n" unless -x $visudo;

	print "Updating file $sudoers\n";

	# NOTE: secure as visudo itself: /etc is root owned
	my $new = $sudoers.".new.".$$;

	# setup to have sane perm for new sudoers file
	umask(0227);

	# insert old sudoers
	open my $old, '<', $sudoers or die $!;
	open my $fh, '>', $new or die $!;
	while (<$old>) {
		print $fh $_;
	}
	close $old or die $!;

	# setup alias, so we could easily remove these later by matching lines with 'CHECK_RAID'
	# also this avoids installing ourselves twice.
	print $fh "\n";
	print $fh "# Lines matching CHECK_RAID added by $0 -S on ", scalar localtime, "\n";
	print $fh "User_Alias CHECK_RAID=nagios\n";
	print $fh join("\n", @sudo);
	print $fh "\n";

	close $fh;

	# validate sudoers
	system($visudo, '-c', '-f', $new) == 0 or unlink($new),exit $? >> 8;

	# use the new file
	rename($new, $sudoers) or die $!;

	print "$sudoers file updated.\n";
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

Getopt::Long::Configure('bundling');
GetOptions(
	'V' => \$opt_V, 'version' => \$opt_V,
	'd' => \$opt_d,
	'h' => \$opt_h, 'help' => \$opt_h,
	'S' => \$opt_S, 'sudoers' => \$opt_S,
	'W' => \$opt_W, 'warnonly' => \$opt_W,
	'p=s' => \$opt_p, 'plugin=s' => \$opt_p,
	'l' => \$opt_l, 'list-plugins' => \$opt_l,
) or exit($ERRORS{UNKNOWN});

if ($opt_S) {
	sudoers;
	exit 0;
}

@utils::ignore = @ARGV if @ARGV;

if ($opt_V) {
	print "check_raid Version $VERSION\n";
	exit $ERRORS{'OK'};
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
	my $plugin = $pn->new;

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
	$status = $plugin->status if $plugin->status > $status;
	$message .= '; ' if $message;
	$message .= "$pn:[".$plugin->message."]";
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
