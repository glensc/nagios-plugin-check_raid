
pack: check_raid.pl

installdeps:
	cpanm --installdeps -Llocal -n .

fatpack: installdeps
	fatpack-simple --no-perl-strip bin/check_raid.pl $(options)

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
