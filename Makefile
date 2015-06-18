# Makefile for check_raid plugin
PLUGIN          := check_raid
PLUGIN_SCRIPT   := $(PLUGIN).pl
PLUGIN_VERSION  := $(shell test -e .git && git describe --tags || awk -F'"' '/VERSION/&&/=/{print $$2}' $(PLUGIN_SCRIPT))
RPM_VERSION     := $(shell test -e .git && git describe --tags | sed -e 's/-/./g')
PLUGINDIR       := /usr/lib/nagios/plugins
PLUGINCONF      := /etc/nagios/plugins

all:

test:
	perl -MTest::Harness -e 'runtests @ARGV' t/*.t

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

install:
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

rpm:
	if [ -e ~/rpmbuild/SOURCES/$(PLUGIN) ]; then \
		rm -rf ~/rpmbuild/SOURCES/$(PLUGIN); \
	fi;
	mkdir ~/rpmbuild/SOURCES/$(PLUGIN)
	cp -a $(shell pwd)/* ~/rpmbuild/SOURCES/$(PLUGIN)
	cp -a $(shell pwd)/.editorconfig ~/rpmbuild/SOURCES/$(PLUGIN)
	cp -a $(shell pwd)/.gitattributes ~/rpmbuild/SOURCES/$(PLUGIN)
	cp -a $(shell pwd)/.travis.yml ~/rpmbuild/SOURCES/$(PLUGIN)
	find ~/rpmbuild/SOURCES/$(PLUGIN)/ -type f -name '*~' -exec rm {} \;
	sed -e "s/###RPM_VERSION###/$(RPM_VERSION)/" nagios-plugin-$(PLUGIN).spec >~/rpmbuild/SPECS/nagios-plugin-$(PLUGIN).spec
	rpmbuild -ba ~/rpmbuild/SPECS/nagios-plugin-$(PLUGIN).spec
