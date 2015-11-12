# vim:ft=perl
#
# Minimum Perl required is 5.8
requires perl => '5.008';

requires 'Module::Pluggable', 5.1;
requires 'Monitoring::Plugin' => '0.37';

on 'test' => sub {
	requires 'ExtUtils::MakeMaker::CPANfile';
};

# don't want these to be installed to 'local'
# but these should be installed to system when building fatpack
on 'never' => sub {
	requires 'App::FatPacker' => '0.10.0';
	requires 'App::FatPacker::Simple' => '0.04';
};
