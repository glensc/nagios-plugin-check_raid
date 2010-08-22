# $Id$ #
SPECFILE        := $(firstword $(wildcard *.spec))
PACKAGE_NAME    := $(patsubst %.spec,%,$(SPECFILE))
PACKAGE_VERSION := $(shell awk '/Version:/{print $$2}' $(SPECFILE))

all:

dist:
	rm -rf $(PACKAGE_NAME)-$(PACKAGE_VERSION)
	install -d $(PACKAGE_NAME)-$(PACKAGE_VERSION)
	cp -a check_raid check_raid.cfg t $(PACKAGE_NAME)-$(PACKAGE_VERSION)
	tar --exclude-vcs -czf $(PACKAGE_NAME)-$(PACKAGE_VERSION).tar.gz $(PACKAGE_NAME)-$(PACKAGE_VERSION)
	rm -rf $(PACKAGE_NAME)-$(PACKAGE_VERSION)
	md5sum -b $(PACKAGE_NAME)-$(PACKAGE_VERSION).tar.gz > $(PACKAGE_NAME)-$(PACKAGE_VERSION).tar.gz.md5
	chmod 644 $(PACKAGE_NAME)-$(PACKAGE_VERSION).tar.gz $(PACKAGE_NAME)-$(PACKAGE_VERSION).tar.gz.md5
