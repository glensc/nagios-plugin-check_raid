use strict;
use warnings;
use Data::Dumper;
use Exporter 'import';

use constant TESTDIR => ($0 =~ m{(.+)/[^/]+$});

BEGIN {
	(our $srcdir = $0) =~ s,/[^/]+$,/,;
	unshift(@INC, $srcdir . '/../lib');
}

# alias all modules to simplify import in tests
use aliased 'App::Monitoring::Plugin::CheckRaid::Plugins::aaccli';
use aliased 'App::Monitoring::Plugin::CheckRaid::Plugins::afacli';
use aliased 'App::Monitoring::Plugin::CheckRaid::Plugins::arcconf';
use aliased 'App::Monitoring::Plugin::CheckRaid::Plugins::areca';
use aliased 'App::Monitoring::Plugin::CheckRaid::Plugins::cciss';
use aliased 'App::Monitoring::Plugin::CheckRaid::Plugins::cmdtool2';
use aliased 'App::Monitoring::Plugin::CheckRaid::Plugins::dmraid';
use aliased 'App::Monitoring::Plugin::CheckRaid::Plugins::dpt_i2o';
use aliased 'App::Monitoring::Plugin::CheckRaid::Plugins::gdth';
use aliased 'App::Monitoring::Plugin::CheckRaid::Plugins::hp_msa';
use aliased 'App::Monitoring::Plugin::CheckRaid::Plugins::hpacucli';
use aliased 'App::Monitoring::Plugin::CheckRaid::Plugins::hpssacli';
use aliased 'App::Monitoring::Plugin::CheckRaid::Plugins::ssacli';
use aliased 'App::Monitoring::Plugin::CheckRaid::Plugins::ips';
use aliased 'App::Monitoring::Plugin::CheckRaid::Plugins::lsraid';
use aliased 'App::Monitoring::Plugin::CheckRaid::Plugins::lsscsi';
use aliased 'App::Monitoring::Plugin::CheckRaid::Plugins::lsvg';
use aliased 'App::Monitoring::Plugin::CheckRaid::Plugins::mdstat';
use aliased 'App::Monitoring::Plugin::CheckRaid::Plugins::megacli';
use aliased 'App::Monitoring::Plugin::CheckRaid::Plugins::megarc';
use aliased 'App::Monitoring::Plugin::CheckRaid::Plugins::metastat';
use aliased 'App::Monitoring::Plugin::CheckRaid::Plugins::mpt';
use aliased 'App::Monitoring::Plugin::CheckRaid::Plugins::mvcli';
use aliased 'App::Monitoring::Plugin::CheckRaid::Plugins::sas2ircu';
use aliased 'App::Monitoring::Plugin::CheckRaid::Plugins::smartctl';
use aliased 'App::Monitoring::Plugin::CheckRaid::Plugins::tw_cli';
use aliased 'App::Monitoring::Plugin::CheckRaid::Plugins::dm';

use constant OK => 0;
use constant WARNING => 1;
use constant CRITICAL => 2;
use constant UNKNOWN => 3;
# default is WARNING
use constant RESYNC => WARNING;

our @EXPORT = qw(OK WARNING CRITICAL UNKNOWN TESTDIR);

sub read_dump {
	my ($file) = @_;
	our $VAR1;

	do $file;

	return $VAR1;
}

sub store_dump {
	my ($file, $c) = @_;

	open my $fh, '>', $file or die "Can't create: $file: $!";
	{
		local $Data::Dumper::Sortkeys = 1;
		print $fh Dumper $c;
	}
	close $fh or die $!;
}

1;
