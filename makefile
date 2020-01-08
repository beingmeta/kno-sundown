prefix		::= $(shell knoconfig prefix)
libsuffix	::= $(shell knoconfig libsuffix)
KNO_CFLAGS	::= -I. -fPIC $(shell knoconfig cflags)
KNO_LDFLAGS	::= -fPIC $(shell knoconfig ldflags)
CFLAGS		::= -I./sundown/ ${CFLAGS} ${KNO_CFLAGS}
LDFLAGS		::= ${LDFLAGS} ${KNO_LDFLAGS}
CMODULES	::= $(DESTDIR)$(shell knoconfig cmodules)
LIBS		::= $(shell knoconfig libs)
LIB		::= $(shell knoconfig lib)
INCLUDE		::= $(shell knoconfig include)
KNO_VERSION	::= $(shell knoconfig version)
KNO_MAJOR	::= $(shell knoconfig major)
KNO_MINOR	::= $(shell knoconfig minor)
PKG_RELEASE	::= $(cat ./etc/release)
DPKG_NAME	::= $(shell ./etc/dpkgname)
MKSO		::= $(CC) -shared $(LDFLAGS) $(LIBS)
MSG		::= echo
SYSINSTALL      ::= /usr/bin/install -c
MOD_NAME	::= sundown
MOD_RELEASE     ::= $(shell cat etc/release)
MOD_VERSION	::= ${KNO_MAJOR}.${KNO_MINOR}.${MOD_RELEASE}

GPGID           ::= FE1BC737F9F323D732AA26330620266BE5AFF294
SUDO            ::= $(shell which sudo)

SUNDOWN_OBJECTS=\
	sundown/autolink.o sundown/buffer.o \
	sundown/markdown.o sundown/stack.o \
	sundown/html.o \
	sundown/html_smartypants.o \
	sundown/houdini_href_e.o \
	sundown/houdini_html_e.o
SUNDOWN_H_FILES=sundown/autolink.h \
	sundown/buffer.h \
	sundown/markdown.h sundown/stack.h \
	sundown/html_blocks.h sundown/html.h \
	sundown/houdini.h

default: ${MOD_NAME}.${libsuffix}

sundown.so: sundown.c $(SUNDOWN_OBJECTS)
	@$(MKSO) $(CFLAGS) -o $@ sundown.c $(SUNDOWN_OBJECTS)
	@$(MSG) MKSO  $@ $<
	@ln -sf $(@F) $(@D)/$(@F).${KNO_MAJOR}
sundown.dylib: sundown.c $(SUNDOWN_OBJECTS)
	@$(MACLIBTOOL) -install_name \
		`basename $(@F) .dylib`.${KNO_MAJOR}.dylib \
		${CFLAGS} -o $@ $(DYLIB_FLAGS) \
		sundown.c $(SUNDOWN_OBJECTS)
	@$(MSG) MACLIBTOOL  $@ $<

TAGS: sundown.c sundown/*.c sundown/*.h
	etags -o TAGS sundown.c sundown/*.c sundown/*.h

install:
	@${SUDO} ${SYSINSTALL} ${MOD_NAME}.${libsuffix} \
			${CMODULES}/${MOD_NAME}.so.${MOD_VERSION}
	@echo === Installed ${CMODULES}/${MOD_NAME}.so.${MOD_VERSION}
	@${SUDO} ln -sf ${MOD_NAME}.so.${MOD_VERSION} \
			${CMODULES}/${MOD_NAME}.so.${KNO_MAJOR}.${KNO_MINOR}
	@echo === Linked ${CMODULES}/${MOD_NAME}.so.${KNO_MAJOR}.${KNO_MINOR} \
		to ${MOD_NAME}.so.${MOD_VERSION}
	@${SUDO} ln -sf ${MOD_NAME}.so.${MOD_VERSION} \
			${CMODULES}/${MOD_NAME}.so.${KNO_MAJOR}
	@echo === Linked ${CMODULES}/${MOD_NAME}.so.${KNO_MAJOR} \
		to ${MOD_NAME}.so.${MOD_VERSION}
	@${SUDO} ln -sf ${MOD_NAME}.so.${MOD_VERSION} ${CMODULES}/${MOD_NAME}.so
	@echo === Linked ${CMODULES}/${MOD_NAME}.so to ${MOD_NAME}.so.${MOD_VERSION}

clean:
	rm -f *.o ${MOD_NAME}/*.o *.${libsuffix}
fresh:
	make clean
	make default

debian: sundown.c sundown/*.c sundown/*.h makefile \
	dist/debian/rules dist/debian/control \
	dist/debian/changelog.base
	rm -rf debian
	cp -r dist/debian debian

debian/changelog: debian sundown.c sundown/*.c sundown/*.h makefile
	cat debian/changelog.base | etc/gitchangelog kno-sundown > $@.tmp
	@if test ! -f debian/changelog; then \
	  mv debian/changelog.tmp debian/changelog; \
	 elif diff debian/changelog debian/changelog.tmp 2>&1 > /dev/null; then \
	  mv debian/changelog.tmp debian/changelog; \
	 else rm debian/changelog.tmp; fi

dist/debian.built: sundown.c makefile debian debian/changelog
	dpkg-buildpackage -sa -us -uc -b -rfakeroot && \
	touch $@

dist/debian.signed: dist/debian.built
	debsign --re-sign -k${GPGID} ../kno-sundown_*.changes && \
	touch $@

deb debs dpkg dpkgs: dist/debian.signed

debinstall: dist/debian.signed
	sudo dpkg -i ../kno-sundown_${MOD_VERSION}*.deb

dist/debian.updated: dist/debian.signed
	dupload -c ./debian/dupload.conf --nomail --to bionic ../kno-sundown_*.changes && touch $@

update-apt: dist/debian.updated

debclean:
	rm -rf ../kno-sundown_* ../kno-sundown-* debian

debfresh:
	make debclean
	make dist/debian.signed
