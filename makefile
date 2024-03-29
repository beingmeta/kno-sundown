KNOCONFIG         = knoconfig
KNOBUILD          = knobuild

prefix		::= $(shell ${KNOCONFIG} prefix)
libsuffix	::= $(shell ${KNOCONFIG} libsuffix)
CMODULES	::= $(DESTDIR)$(shell ${KNOCONFIG} cmodules)
LIBS		::= $(shell ${KNOCONFIG} libs)
LIB		::= $(shell ${KNOCONFIG} lib)
INCLUDE		::= $(shell ${KNOCONFIG} include)
KNO_VERSION	::= $(shell ${KNOCONFIG} version)
KNO_MAJOR	::= $(shell ${KNOCONFIG} major)
KNO_MINOR	::= $(shell ${KNOCONFIG} minor)
PKG_VERSION     ::= $(shell u8_gitversion ./etc/knomod_version)
PKG_MAJOR       ::= $(shell cat ./etc/knomod_version | cut -d. -f1)
FULL_VERSION    ::= ${KNO_MAJOR}.${KNO_MINOR}.${PKG_VERSION}
PATCHLEVEL      ::= $(shell u8_gitpatchcount ./etc/knomod_version)

PKG_NAME	::= sundown
DPKG_NAME	::= ${PKG_NAME}_${PATCH_VERSION}

SUDO            ::= $(shell which sudo)
INIT_CFLAGS	::= ${CFLAGS}
INIT_LDFLAGS	::= ${LDFLAGS}
KNO_CFLAGS	::= -I. -fPIC $(shell ${KNOCONFIG} cflags)
KNO_LDFLAGS	::= -fPIC $(shell ${KNOCONFIG} ldflags)
KNO_LIBS	::= $(shell ${KNOCONFIG} libs)
SUNDOWN_CFLAGS	::= -I./sundown/
SUNDOWN_LDFLAGS	::= 

CFLAGS		::= ${INIT_CFLAGS} ${KNO_CFLAGS} ${SUNDOWN_CFLAGS}
LDFLAGS		::= ${INIT_LDFLAGS} ${KNO_LDFLAGS} ${SUNDOWN_LDFLAGS}
MKSO		  = $(CC) -shared $(LDFLAGS) $(LIBS)
SYSINSTALL        = /usr/bin/install -c
DIRINSTALL        = /usr/bin/install -d
MSG		  = echo
MACLIBTOOL	  = $(CC) -dynamiclib -single_module -undefined dynamic_lookup \
			$(LDFLAGS)

GPGID           ::= ${OVERRIDE_GPGID:-FE1BC737F9F323D732AA26330620266BE5AFF294}
CODENAME	::= $(shell ${KNOCONFIG} codename)
REL_BRANCH	::= $(shell ${KNOBUILD} getbuildopt REL_BRANCH current)
REL_STATUS	::= $(shell ${KNOBUILD} getbuildopt REL_STATUS stable)
REL_PRIORITY	::= $(shell ${KNOBUILD} getbuildopt REL_PRIORITY medium)
ARCH            ::= $(shell ${KNOBUILD} getbuildopt BUILD_ARCH || uname -m)
APKREPO         ::= $(shell ${KNOBUILD} getbuildopt APKREPO /srv/repo/kno/apk)
APK_ARCH_DIR      = ${APKREPO}/staging/${ARCH}
RPMDIR		  = dist

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

%.o: %.c
	@$(CC) $(CFLAGS) -D_FILEINFO="\"$(shell u8_fileinfo ./$< $(dirname $(pwd))/)\"" -o $@ -c $<
	@$(MSG) CC $@ $<

default build: ${PKG_NAME}.${libsuffix}

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

${CMODULES}:
	@${DIRINSTALL} $@

install: build ${CMODULES}
	${SUDO} u8_install_shared ${PKG_NAME}.${libsuffix} ${CMODULES} ${FULL_VERSION} "${SYSINSTALL}"

clean:
	rm -f *.o ${PKG_NAME}/*.o *.${libsuffix}
fresh:
	make clean
	make default

gitup gitup-trunk:
	git checkout trunk && git pull

# RPM packaging

dist/kno-${PKG_NAME}.spec: dist/kno-${PKG_NAME}.spec.in makefile
	u8_xsubst dist/kno-${PKG_NAME}.spec dist/kno-${PKG_NAME}.spec.in \
		"VERSION" "${FULL_VERSION}" \
		"PKG_NAME" "${PKG_NAME}" && \
	touch $@
kno-${PKG_NAME}.tar: dist/kno-${PKG_NAME}.spec
	git archive -o $@ --prefix=kno-${PKG_NAME}-${FULL_VERSION}/ HEAD
	tar -f $@ -r dist/kno-${PKG_NAME}.spec

dist/rpms.ready: kno-${PKG_NAME}.tar
	rpmbuild $(RPMFLAGS)  			\
	   --define="_rpmdir $(RPMDIR)"			\
	   --define="_srcrpmdir $(RPMDIR)" 		\
	   --nodeps -ta 				\
	    kno-${PKG_NAME}.tar && 	\
	touch dist/rpms.ready
dist/rpms.done: dist/rpms.ready
	@if (test "$(GPGID)" = "none" || test "$(GPGID)" = "" ); then 			\
	    touch dist/rpms.done;				\
	else 						\
	     echo "Enter passphrase for '$(GPGID)':"; 		\
	     rpm --addsign --define="_gpg_name $(GPGID)" 	\
		--define="__gpg_sign_cmd $(RPMGPG)"		\
		$(RPMDIR)/kno-${PKG_NAME}-${FULL_VERSION}*.src.rpm 		\
		$(RPMDIR)/*/kno*-@KNO_VERSION@-*.rpm; 	\
	fi && touch dist/rpms.done;
	@ls -l $(RPMDIR)/kno-${PKG_NAME}-${FULL_VERSION}-*.src.rpm \
		$(RPMDIR)/*/kno*-${FULL_VERSION}-*.rpm;

rpms: dist/rpms.done

cleanrpms:
	rm -rf dist/rpms.done dist/rpms.ready kno-${PKG_NAME}.tar dist/kno-${PKG_NAME}.spec

rpmupdate update-rpms freshrpms: cleanrpms
	make cleanrpms
	make -s dist/rpms.done
dist/rpms.installed: dist/rpms.done
	sudo rpm -Uvh ${RPMDIR}/*.rpm && sudo rpm -Uvh ${RPMDIR}/${ARCH}/*.rpm && touch $@

installrpms install-rpms: dist/rpms.installed

# Alpine packaging

staging/alpine:
	@install -d $@

staging/alpine/APKBUILD: dist/alpine/APKBUILD staging/alpine
	cp dist/alpine/APKBUILD staging/alpine

staging/alpine/kno-${PKG_NAME}.tar: staging/alpine
	git archive --prefix=kno-${PKG_NAME}/ -o staging/alpine/kno-${PKG_NAME}.tar HEAD

dist/alpine.setup: staging/alpine/APKBUILD makefile ${STATICLIBS} \
	staging/alpine/kno-${PKG_NAME}.tar
	if [ ! -d ${APK_ARCH_DIR} ]; then mkdir -p ${APK_ARCH_DIR}; fi && \
	( cd staging/alpine; \
		abuild -P ${APKREPO} clean cleancache cleanpkg && \
		abuild checksum ) && \
	touch $@

dist/alpine.done: dist/alpine.setup
	( cd staging/alpine; abuild -P ${APKREPO} ) && touch $@
dist/alpine.installed: dist/alpine.setup
	( cd staging/alpine; abuild -i -P ${APKREPO} ) && touch dist/alpine.done && touch $@


alpine: dist/alpine.done
install-alpine: dist/alpine.done

.PHONY: alpine

