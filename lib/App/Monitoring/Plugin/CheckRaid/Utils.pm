package App::Monitoring::Plugin::CheckRaid::Utils;

use warnings;
use strict;
use Exporter 'import';

our @EXPORT = qw(which find_sudo);
our @EXPORT_OK = @EXPORT;

# registered plugins
our @plugins;

# devices to ignore
our @ignore;

# debug level
our $debug = 0;

# paths for which()
our @paths = split /:/, $ENV{'PATH'};
unshift(@paths, qw(/usr/local/nrpe /usr/local/bin /sbin /usr/sbin /bin /usr/sbin /opt/bin /opt/MegaRAID/MegaCli /usr/StorMan));

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
sub find_sudo {
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
	# prefer -n to skip password prompt
	push(@sudo, '-n') if /-n/;
	# ..if not supported, add -A as well
	push(@sudo, '-A') if /-A/;

	return \@sudo;
}

1;
