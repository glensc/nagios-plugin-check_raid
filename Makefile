# Makefile for check_raid plugin
PLUGIN          := check_raid
PLUGIN_SCRIPT   := $(PLUGIN).pl
PLUGIN_VERSION  := $(shell test -e .git && git describe --tags || awk -F"'" '/VERSION/&&/=/{print $$2}' bin/$(PLUGIN_SCRIPT))
PLUGINDIR       := /usr/lib/nagios/plugins
PLUGINCONF      := /etc/nagios/plugins
CACHE_DIR       := $(CURDIR)/cache
CPANM_CACHE     := $(CACHE_DIR)/cpanm
export PERL5LIB	:= $(CURDIR)/sysdeps/lib/perl5
PATH			:= $(CURDIR)/sysdeps/bin:$(PATH)

# rpm version related macros
RPM_NAME        := nagios-plugin-$(PLUGIN)
version_parts   := $(subst -, ,$(PLUGIN_VERSION))
space           := $(nil) $(nil)
RPM_VERSION     := $(firstword $(version_parts))
RPM_RELEASE     := $(subst $(space),.,$(wordlist 2, $(words $(version_parts)), $(version_parts)))
# if built from tag, release "1", otherwise "0.something"
ifneq ($(RPM_RELEASE),)
RPM_RELEASE     := 0.$(RPM_RELEASE)
else
RPM_RELEASE     := 1
endif
RPM_FILENAME    := $(RPM_NAME)-$(RPM_VERSION)-$(RPM_RELEASE).noarch.rpm

all:

test:
	perl -MTest::Harness -e 'runtests @ARGV' t/*.t

builddeps:
	cpanm -n -L sysdeps App::FatPacker
	cpanm -n -L sysdeps App::FatPacker::Simple

pack:
	rm -f $(PLUGIN_SCRIPT)
	$(MAKE) $(PLUGIN_SCRIPT)

installdeps:
	cpanm --installdeps -Llocal -n . \
		--cascade-search \
		--save-dists=$(CPANM_CACHE) \
		--mirror=$(CPANM_CACHE) \
		--mirror=http://search.cpan.org/CPAN

# Params::Validate adds some Module::Build dependency, but Monitoring-Plugin needs just:
# Configuring Monitoring-Plugin-0.39 ... OK
# ==> Found dependencies: Params::Validate, Class::Accessor, Config::Tiny, Math::Calc::Units
exclude_fatpack_modules := Module::Build,CPAN::Meta,Module::CPANfile,ExtUtils::MakeMaker::CPANfile

fatpack: installdeps builddeps
	fatpack-simple \
		--exclude-strip='^lib/*' \
		--exclude-strip='^bin/*' \
		--exclude=$(exclude_fatpack_modules) \
		bin/$(PLUGIN_SCRIPT) $(options)

$(PLUGIN_SCRIPT): bin/$(PLUGIN_SCRIPT)
	# ensure cpanm is present
	cpanm --version

	# need 0.10.0 of fatpacker for Module::Pluggable to work
	perl -e 'use App::FatPacker 0.10.0'
	perl -e 'use App::FatPacker::Simple 0.07'

	# ensure we run in clean tree. export git tree and run there.
	rm -rf fatpack
	install -d fatpack
	git archive HEAD | tar -x -C fatpack
	$(MAKE) -f $(CURDIR)/Makefile -C fatpack fatpack CACHE_DIR=$(CACHE_DIR) options="--output ../$@"
	rm -rf fatpack
	grep -o 'fatpacked{.*}' $@

perltidy:
	perltidy $(PLUGIN_SCRIPT)

release:
	@echo "Checking for tag"; \
	V=`./$(PLUGIN_SCRIPT) -V | cut -d' ' -f3`; \
	T=`git tag -l $$V`; \
	if [ -n "$$T" ]; then \
		echo >&2 "Tag $$T already exists"; \
		exit 1; \
	fi; \
	R=`git rev-parse HEAD`; \
	echo "RELEASE: create version $$V at $$R"; \
	git tag -a "$$V" $$R; \
	echo "Don't forget to push: git push origin refs/tags/$$V"

install: $(PLUGIN_SCRIPT)
	install -d $(DESTDIR)$(PLUGINDIR)
	install -p $(PLUGIN_SCRIPT) $(DESTDIR)$(PLUGINDIR)/$(PLUGIN)
	install -d $(DESTDIR)$(PLUGINCONF)
	cp -p $(PLUGIN).cfg $(DESTDIR)$(PLUGINCONF)

dist:
	rm -rf $(PLUGIN)-$(PLUGIN_VERSION)
	install -d $(PLUGIN)-$(PLUGIN_VERSION)
	install -p $(PLUGIN_SCRIPT) $(PLUGIN)-$(PLUGIN_VERSION)/$(PLUGIN)
	cp -a check_raid.cfg t $(PLUGIN)-$(PLUGIN_VERSION)
	tar --exclude-vcs -czf $(PLUGIN)-$(PLUGIN_VERSION).tar.gz $(PLUGIN)-$(PLUGIN_VERSION)
	rm -rf $(PLUGIN)-$(PLUGIN_VERSION)
	md5sum -b $(PLUGIN)-$(PLUGIN_VERSION).tar.gz > $(PLUGIN)-$(PLUGIN_VERSION).tar.gz.md5
	chmod 644 $(PLUGIN)-$(PLUGIN_VERSION).tar.gz $(PLUGIN)-$(PLUGIN_VERSION).tar.gz.md5

rpm: $(PLUGIN_SCRIPT)
	# needs to be ran in git checkout for version setup to work
	test -d .git
	# display build system info
	rpmbuild --version
	lsb_release -a || cat /etc/os-release || :
	rpmbuild -ba \
		--define '_topdir $(CURDIR)' \
		--define '_specdir %_topdir' \
		--define '_sourcedir %_topdir' \
		--define '_rpmdir %_topdir' \
		--define '_srcrpmdir %_topdir' \
		--define '_builddir %_topdir/BUILD' \
		--define 'version $(RPM_VERSION)' \
		--define 'release $(RPM_RELEASE)' \
		$(RPM_NAME).spec
	# display built rpm requires
	rpm -qp --requires $(CURDIR)/$(RPM_FILENAME)
