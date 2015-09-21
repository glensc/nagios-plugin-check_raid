
# This gets exported to Perl calls in fatpacker
export PERL5LIB := lib

pack: check_raid.pl

check_raid.pl: bin/check_raid.pl
	fatpack trace $<
	fatpack packlists-for `cat fatpacker.trace` > packlists
	fatpack tree `cat packlists`
	fatpack file $< > $@
	chmod a+rx $@

.PHONY: check_raid.pl
