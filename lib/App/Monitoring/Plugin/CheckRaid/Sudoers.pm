package App::Monitoring::Plugin::CheckRaid::Sudoers;

use App::Monitoring::Plugin::CheckRaid::Utils;
use warnings;
use strict;

use Exporter 'import';

our @EXPORT = qw(sudoers);
our @EXPORT_OK = @EXPORT;

# update sudoers file
#
# if sudoers config has "#includedir" directive, add file to that dir
# otherwise update main sudoers file
sub sudoers {
	my $dry_run = shift;
	my @plugins = @_;

	# build values to be added
	# go over all active plugins
	my @sudo;
	foreach my $plugin (@plugins) {
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
	my $visudo = which('visudo');

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

# get contents of a file
sub cat {
	my ($file) = @_;
	open(my $fh, '<', $file) or die "Can't open $file: $!";
	local $/ = undef;
	local $_ = <$fh>;
	close($fh) or die $!;

	return $_;
}

# find first existing file from list of file paths
sub find_file {
	for my $file (@_) {
		return $file if -f $file;
	}
	return undef;
}
