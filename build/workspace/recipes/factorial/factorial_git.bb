# Recipe created by recipetool
# This is the basis of a recipe and may need further editing in order to be fully functional.
# (Feel free to remove these comments when editing.)

# Unable to find any files that looked like license statements. Check the accompanying
# documentation and source headers and set LICENSE and LIC_FILES_CHKSUM accordingly.
#
# NOTE: LICENSE is being set to "CLOSED" to allow you to at least start building - if
# this is not accurate with respect to the licensing of the software being built (it
# will not be in most cases) you must specify the correct value before using this
# recipe for anything other than initial testing/development!
LICENSE = "CLOSED"
LIC_FILES_CHKSUM = ""

SRC_URI = "git://github.com/Munawar-git/factorial;protocol=https;branch=main"

# Modify these as desired
PV = "1.0+git"
SRCREV = "27134a05d6b5aa06a474bc0002f6541550ac51e0"

S = "${WORKDIR}/git"

EXTRA_OEMAKE = "PREFIX=${D}${bindir} CC='${CC}' CFLAGS='${CFLAGS}' LDFLAGS='${LDFLAGS}'"


# NOTE: this is a Makefile-only piece of software, so we cannot generate much of the
# recipe automatically - you will need to examine the Makefile yourself and ensure
# that the appropriate arguments are passed in.

do_compile () {
	# You will almost certainly need to add additional arguments here
	oe_runmake
}

do_install () {
	# This is a guess; additional arguments may be required
	install -d ${D}${bindir}
	#oe_runmake install
	install -m 0755 factorial ${D}${bindir}/
}


