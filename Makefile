
pack: check_raid.pl

installdeps:
	cpanm --installdeps -Llocal -n .

# Params::Validate adds some Module::Build dependency, but Monitoring-Plugin needs just:
# Configuring Monitoring-Plugin-0.39 ... OK
# ==> Found dependencies: Params::Validate, Class::Accessor, Config::Tiny, Math::Calc::Units
exclude_fatpack_modules := Module::Build,CPAN::Meta

fatpack: installdeps perlstrip
	fatpack-simple --no-perl-strip --exclude $(exclude_fatpack_modules) bin/check_raid.pl $(options)

perlstrip:
	find local/lib -name '*.pm' | xargs perlstrip -s

check_raid.pl: bin/check_raid.pl
	# ensure cpanm is present
	cpanm --version

	# need 0.10.0 of fatpacker for Module::Pluggable to work
	perl -e 'use App::FatPacker 0.10.0'
	perl -e 'use App::FatPacker::Simple'

	# ensure we run in clean tree. export git tree and run there.
	rm -rf fatpack
	install -d fatpack
	git archive HEAD | tar -x -C fatpack
	$(MAKE) -C fatpack fatpack options="--output ../$@"
	rm -rf fatpack
	grep -o 'fatpacked{.*}' $@

.PHONY: check_raid.pl
