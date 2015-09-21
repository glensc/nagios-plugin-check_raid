
# This gets exported to Perl calls in fatpacker
export PERL5LIB := lib

pack: check_raid.pl

check_raid.pl: bin/check_raid.pl
	# need 0.10.0 of fatpacker for Module::Pluggable to work
	perl -e 'use App::FatPacker 0.10.0'

	# fatpack includes all in "lib" and "fatpacked", so export git tree and run there
	rm -rf fatpack
	install -d fatpack
	git archive HEAD | tar -x -C fatpack
	set -e; cd fatpack; \
	fatpack trace $<; \
	fatpack packlists-for `cat fatpacker.trace` > packlists; \
	fatpack tree `cat packlists`; \
	fatpack file $< > $@; \
	chmod a+rx $@; \
	mv $@ ..
	rm -rf fatpack

.PHONY: check_raid.pl
