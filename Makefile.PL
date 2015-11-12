use ExtUtils::MakeMaker;
use ExtUtils::MakeMaker::CPANfile;

WriteMakefile(
	NAME => 'App::Monitoring::Plugin::CheckRaid',
	AUTHOR => 'Elan Ruusamäe <glen@pld-linux.org>',
	EXE_FILES => ['bin/check_raid.pl'],
);
