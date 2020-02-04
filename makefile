KNOCONFIG       ::= knoconfig
prefix		::= $(shell ${KNOCONFIG} prefix)
libsuffix	::= $(shell ${KNOCONFIG} libsuffix)
KNO_CFLAGS	::= -I. -fPIC $(shell ${KNOCONFIG} cflags)
KNO_LDFLAGS	::= -fPIC $(shell ${KNOCONFIG} ldflags)
CFLAGS		::= -I./sundown/ ${CFLAGS} ${KNO_CFLAGS}
LDFLAGS		::= ${LDFLAGS} ${KNO_LDFLAGS}
CMODULES	::= $(DESTDIR)$(shell ${KNOCONFIG} cmodules)
LIBS		::= $(shell ${KNOCONFIG} libs)
LIB		::= $(shell ${KNOCONFIG} lib)
INCLUDE		::= $(shell ${KNOCONFIG} include)
KNO_VERSION	::= $(shell ${KNOCONFIG} version)
KNO_MAJOR	::= $(shell ${KNOCONFIG} major)
KNO_MINOR	::= $(shell ${KNOCONFIG} minor)
PKG_RELEASE	::= $(cat ./etc/release)
DPKG_NAME	::= $(shell ./etc/dpkgname)
MKSO		::= $(CC) -shared $(LDFLAGS) $(LIBS)
MSG		::= echo
SYSINSTALL      ::= /usr/bin/install -c
DIRINSTALL      ::= /usr/bin/install -d
PKG_NAME	::= sundown
PKG_RELEASE     ::= $(shell cat etc/release)
PKG_VERSION	::= ${KNO_MAJOR}.${KNO_MINOR}.${PKG_RELEASE}
APKREPO         ::= $(shell ${KNOCONFIG} apkrepo)
CODENAME	::= $(shell ${KNOCONFIG} codename)
RELSTATUS	::= $(shell ${KNOCONFIG} status)

GPGID = FE1BC737F9F323D732AA26330620266BE5AFF294
SUDO  = $(shell which sudo)

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

default build: ${PKG_NAME}.${libsuffix}

sundown.so: sundown.c $(SUNDOWN_OBJECTS)
	@$(MKSO) $(CFLAGS) -o $@ sundown.c $(SUNDOWN_OBJECTS)
	@if test ! -z "${COPY_CMODS}"; then cp $@ ${COPY_CMODS}; fi;
	@$(MSG) MKSO  $@ $<
	@ln -sf $(@F) $(@D)/$(@F).${KNO_MAJOR}
sundown.dylib: sundown.c $(SUNDOWN_OBJECTS)
	@$(MACLIBTOOL) -install_name \
		`basename $(@F) .dylib`.${KNO_MAJOR}.dylib \
		${CFLAGS} -o $@ $(DYLIB_FLAGS) \
		sundown.c $(SUNDOWN_OBJECTS)
	@if test ! -z "${COPY_CMODS}"; then cp $@ ${COPY_CMODS}; fi;
	@$(MSG) MACLIBTOOL  $@ $<

TAGS: sundown.c sundown/*.c sundown/*.h
	etags -o TAGS sundown.c sundown/*.c sundown/*.h

${CMODULES}:
	@${DIRINSTALL} $@

install: build ${CMODULES}
	@${SUDO} ${SYSINSTALL} ${PKG_NAME}.${libsuffix} \
			${CMODULES}/${PKG_NAME}.so.${PKG_VERSION}
	@echo === Installed ${CMODULES}/${PKG_NAME}.so.${PKG_VERSION}
	@${SUDO} ln -sf ${PKG_NAME}.so.${PKG_VERSION} \
			${CMODULES}/${PKG_NAME}.so.${KNO_MAJOR}.${KNO_MINOR}
	@echo === Linked ${CMODULES}/${PKG_NAME}.so.${KNO_MAJOR}.${KNO_MINOR} \
		to ${PKG_NAME}.so.${PKG_VERSION}
	@${SUDO} ln -sf ${PKG_NAME}.so.${PKG_VERSION} \
			${CMODULES}/${PKG_NAME}.so.${KNO_MAJOR}
	@echo === Linked ${CMODULES}/${PKG_NAME}.so.${KNO_MAJOR} \
		to ${PKG_NAME}.so.${PKG_VERSION}
	@${SUDO} ln -sf ${PKG_NAME}.so.${PKG_VERSION} ${CMODULES}/${PKG_NAME}.so
	@echo === Linked ${CMODULES}/${PKG_NAME}.so to ${PKG_NAME}.so.${PKG_VERSION}

clean:
	rm -f *.o ${PKG_NAME}/*.o *.${libsuffix}
fresh:
	make clean
	make default

debian: sundown.c sundown/*.c sundown/*.h makefile \
	dist/debian/rules dist/debian/control \
	dist/debian/changelog.base
	rm -rf debian
	cp -r dist/debian debian

debian/changelog: debian sundown.c sundown/*.c sundown/*.h makefile
	cat debian/changelog.base | \
		knomod debchangelog kno-${PKG_NAME} ${CODENAME} ${RELSTATUS} > $@.tmp
	if test ! -f debian/changelog; then \
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
	sudo dpkg -i ../kno-sundown_${PKG_VERSION}*.deb

dist/debian.updated: dist/debian.signed
	dupload -c ./dist/dupload.conf --nomail --to bionic ../kno-sundown_*.changes && touch $@

update-apt: dist/debian.updated

debclean: clean
	rm -rf ../kno-sundown_* ../kno-sundown-* debian dist/debian.*

debfresh:
	make debclean
	make dist/debian.signed

# Alpine packaging

${APKREPO}/dist/x86_64:
	@install -d $@

staging/alpine:
	@install -d $@

staging/alpine/APKBUILD: dist/alpine/APKBUILD staging/alpine
	cp dist/alpine/APKBUILD staging/alpine

staging/alpine/kno-${PKG_NAME}.tar: staging/alpine
	git archive --prefix=kno-${PKG_NAME}/ -o staging/alpine/kno-${PKG_NAME}.tar HEAD

dist/alpine.done: staging/alpine/APKBUILD makefile \
	staging/alpine/kno-${PKG_NAME}.tar ${APKREPO}/dist/x86_64
	cd staging/alpine; \
		abuild -P ${APKREPO} clean cleancache cleanpkg && \
		abuild checksum && \
		abuild -P ${APKREPO} && \
		touch ../../$@

alpine: dist/alpine.done

.PHONY: alpine

