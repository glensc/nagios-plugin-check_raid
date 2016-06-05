package App::Monitoring::Plugin::CheckRaid::Plugin;

use Carp qw(croak);
use App::Monitoring::Plugin::CheckRaid::Utils;
use strict;
use warnings;

# Nagios standard error codes
my (%ERRORS) = (OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3);

# default plugin options
our %options = (
	# status to set when RAID is in resync state
	resync_status => $ERRORS{WARNING},

	# Status code to use when no raid volumes were detected
	noraid_status => $ERRORS{UNKNOWN},

	# status to set when RAID is in check state
	check_status => $ERRORS{OK},

	# status to set when PD is spare
	spare_status => $ERRORS{OK},

	# status to set when BBU is in learning cycle.
	bbulearn_status => $ERRORS{WARNING},

	# status to set when Write Cache has failed.
	cache_fail_status => $ERRORS{WARNING},

	# check status of BBU
	bbu_monitoring => 0,
);

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
	croak 'Class is already a reference' if ref $class;

	# convert to hash
	my %args = @_;

	# merge 'options' from param and class defaults
	my %opts = %options;
	%opts = (%options, %{$args{options}}) if $args{options};
	delete $args{options};

	# merge commands
	my %commands = %{$class->commands};
	%commands = (%commands, %{$args{commands}}) if $args{commands};
	delete $args{commands};

	my $self = {
		commands => \%commands,
		sudo => $class->sudo ? find_sudo() : '',
		options => \%opts,
		%args,

		# name of the plugin, without package namespace
		name => ($class =~ /.*::([^:]+)$/),

		status => undef,
		message => undef,
		perfdata => undef,
		longoutput => undef,
	};

	my $this = bless $self, $class;

	# lookup program, if not defined by params
	if (!$self->{program}) {
		$self->{program} = which($this->program_names);
	}

	return $this;
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
	$this->status($this->{options}{resync_status});
	return $this;
}

# helper to set status for check
# returns $this to allow fluent api
sub check_status {
	my ($this) = @_;
	$this->status($this->{options}{check_status});
	return $this;
}

# helper to set status for no raid condition
# returns $this to allow fluent api
sub noraid {
	my ($this) = @_;
	$this->status($this->{options}{noraid_status});
	return $this;
}

# helper to set status for spare
# returns $this to allow fluent api
sub spare {
	my ($this) = @_;
	$this->status($this->{options}{spare_status});
	return $this;
}

# helper to set status for BBU learning cycle
# returns $this to allow fluent api
sub bbulearn {
	my ($this) = @_;
	$this->status($this->{options}{bbulearn_status});
	return $this;
}

# helper to set status when Write Cache fails
# returns $this to allow fluent api
sub cache_fail {
	my ($this) = @_;
	$this->status($this->{options}{cache_fail_status});
	return $this;
}

# helper to get/set bbu monitoring
sub bbu_monitoring {
	my ($this, $val) = @_;

	if (defined $val) {
		$this->{options}{bbu_monitoring} = $val;
	}
	$this->{options}{bbu_monitoring};
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
sub valid {
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

sub format_bytes {
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

	my $debug = $App::Monitoring::Plugin::CheckRaid::Utils::debug;

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
		warn "DEBUG EXEC: $op @cmd" if $debug;
		my $pid = open2($fh, $$cb, @cmd) or croak "open2 failed: @cmd: $!";
	} elsif ($op eq '>&2') {
		# Special: same as '|-' but reads both STDERR and STDOUT
		use IPC::Open3;
		warn "DEBUG EXEC: $op @cmd" if $debug;
		my $pid = open3(undef, $fh, $cb, @cmd);

	} else {
		warn "DEBUG EXEC: @cmd" if $debug;
		open($fh, $op, @cmd) or croak "open failed: @cmd: $!";
	}

	# for dir handles, reopen as opendir
	if (-d $fh) {
		undef($fh);
		warn "DEBUG OPENDIR: $cmd[0]" if $debug;
		opendir($fh, $cmd[0]) or croak "opendir failed: @cmd: $!";
	}

	return $fh;
}

1;
