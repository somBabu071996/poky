#
# Copyright OpenEmbedded Contributors
#
# SPDX-License-Identifier: MIT
#

# We want native packages to be relocatable
inherit relocatable

# Native packages are built indirectly via dependency,
# no need for them to be a direct target of 'world'
EXCLUDE_FROM_WORLD = "1"

PACKAGE_ARCH = "${BUILD_ARCH}"

# used by cmake class
OECMAKE_RPATH = "${libdir}"
OECMAKE_RPATH:class-native = "${libdir}"

TARGET_ARCH = "${BUILD_ARCH}"
TARGET_OS = "${BUILD_OS}"
TARGET_VENDOR = "${BUILD_VENDOR}"
TARGET_PREFIX = "${BUILD_PREFIX}"
TARGET_CC_ARCH = "${BUILD_CC_ARCH}"
TARGET_LD_ARCH = "${BUILD_LD_ARCH}"
TARGET_AS_ARCH = "${BUILD_AS_ARCH}"
TARGET_CPPFLAGS = "${BUILD_CPPFLAGS}"
TARGET_CFLAGS = "${BUILD_CFLAGS}"
TARGET_CXXFLAGS = "${BUILD_CXXFLAGS}"
TARGET_LDFLAGS = "${BUILD_LDFLAGS}"
TARGET_FPU = ""
TUNE_FEATURES = ""
ABIEXTENSION = ""

HOST_ARCH = "${BUILD_ARCH}"
HOST_OS = "${BUILD_OS}"
HOST_VENDOR = "${BUILD_VENDOR}"
HOST_PREFIX = "${BUILD_PREFIX}"
HOST_CC_ARCH = "${BUILD_CC_ARCH}"
HOST_LD_ARCH = "${BUILD_LD_ARCH}"
HOST_AS_ARCH = "${BUILD_AS_ARCH}"

STAGING_BINDIR = "${STAGING_BINDIR_NATIVE}"
STAGING_BINDIR_CROSS = "${STAGING_BINDIR_NATIVE}"

# native pkg doesn't need the TOOLCHAIN_OPTIONS.
TOOLCHAIN_OPTIONS = ""

# Don't build ptest natively
PTEST_ENABLED = "0"

# Don't use site files for native builds
export CONFIG_SITE = "${COREBASE}/meta/site/native"

# set the compiler as well. It could have been set to something else
CC = "${BUILD_CC}"
CXX = "${BUILD_CXX}"
FC = "${BUILD_FC}"
CPP = "${BUILD_CPP}"
LD = "${BUILD_LD}"
CCLD = "${BUILD_CCLD}"
AR = "${BUILD_AR}"
AS = "${BUILD_AS}"
RANLIB = "${BUILD_RANLIB}"
STRIP = "${BUILD_STRIP}"
NM = "${BUILD_NM}"
OBJCOPY = "${BUILD_OBJCOPY}"
OBJDUMP = "${BUILD_OBJDUMP}"
READELF = "${BUILD_READELF}"

# Path prefixes
base_prefix = "${STAGING_DIR_NATIVE}"
prefix = "${STAGING_DIR_NATIVE}${prefix_native}"
exec_prefix = "${STAGING_DIR_NATIVE}${prefix_native}"

bindir = "${STAGING_BINDIR_NATIVE}"
sbindir = "${STAGING_SBINDIR_NATIVE}"
base_libdir = "${STAGING_BASE_LIBDIR_NATIVE}"
libdir = "${STAGING_LIBDIR_NATIVE}"
includedir = "${STAGING_INCDIR_NATIVE}"
sysconfdir = "${STAGING_ETCDIR_NATIVE}"
datadir = "${STAGING_DATADIR_NATIVE}"

baselib = "lib"

export lt_cv_sys_lib_dlsearch_path_spec = "${libdir} ${base_libdir} /lib /lib64 /usr/lib /usr/lib64"

NATIVE_PACKAGE_PATH_SUFFIX ?= ""
bindir .= "${NATIVE_PACKAGE_PATH_SUFFIX}"
sbindir .= "${NATIVE_PACKAGE_PATH_SUFFIX}"
base_libdir .= "${NATIVE_PACKAGE_PATH_SUFFIX}"
libdir .= "${NATIVE_PACKAGE_PATH_SUFFIX}"
libexecdir .= "${NATIVE_PACKAGE_PATH_SUFFIX}"

do_populate_sysroot[sstate-inputdirs] = "${SYSROOT_DESTDIR}/${STAGING_DIR_NATIVE}/"
do_populate_sysroot[sstate-outputdirs] = "${COMPONENTS_DIR}/${PACKAGE_ARCH}/${PN}"

# Since we actually install these into situ there is no staging prefix
STAGING_DIR_HOST = ""
STAGING_DIR_TARGET = ""
PKG_CONFIG_DIR = "${libdir}/pkgconfig"

EXTRA_NATIVE_PKGCONFIG_PATH ?= ""
PKG_CONFIG_PATH .= "${EXTRA_NATIVE_PKGCONFIG_PATH}"
PKG_CONFIG_SYSROOT_DIR = ""
PKG_CONFIG_SYSTEM_LIBRARY_PATH[unexport] = "1"
PKG_CONFIG_SYSTEM_INCLUDE_PATH[unexport] = "1"

# we dont want libc-*libc to kick in for native recipes
LIBCOVERRIDE = ""
CLASSOVERRIDE = "class-native"
MACHINEOVERRIDES = ""
MACHINE_FEATURES = ""

PATH:prepend = "${COREBASE}/scripts/native-intercept:"

# This class encodes staging paths into its scripts data so can only be
# reused if we manipulate the paths.
SSTATE_SCAN_CMD ?= "${SSTATE_SCAN_CMD_NATIVE}"

# No strip sysroot when DEBUG_BUILD is enabled
INHIBIT_SYSROOT_STRIP ?= "${@oe.utils.vartrue('DEBUG_BUILD', '1', '', d)}"

python native_virtclass_handler () {
    import re
    pn = e.data.getVar("PN")
    if not pn.endswith("-native"):
        return
    bpn = e.data.getVar("BPN")

    # Set features here to prevent appends and distro features backfill
    # from modifying native distro features
    features = set(d.getVar("DISTRO_FEATURES_NATIVE").split())
    filtered = set(bb.utils.filter("DISTRO_FEATURES", d.getVar("DISTRO_FEATURES_FILTER_NATIVE"), d).split())
    d.setVar("DISTRO_FEATURES", " ".join(sorted(features | filtered)))

    classextend = e.data.getVar('BBCLASSEXTEND') or ""
    if "native" not in classextend:
        return

    def map_dependencies(varname, d, suffix = "", selfref=True, regex=False):
        if suffix:
            varname = varname + ":" + suffix
        deps = d.getVar(varname)
        if not deps:
            return
        deps = bb.utils.explode_deps(deps)
        newdeps = []
        for dep in deps:
            if regex and dep.startswith("^") and dep.endswith("$"):
                newdeps.append(dep[:-1].replace(pn, bpn) + "-native$")
            elif dep == pn:
                if not selfref:
                    continue
                newdeps.append(dep)
            elif "-cross-" in dep:
                newdeps.append(dep.replace("-cross", "-native"))
            elif not dep.endswith("-native"):
                # Replace ${PN} with ${BPN} in the dependency to make sure
                # dependencies on, e.g., ${PN}-foo become ${BPN}-foo-native
                # rather than ${BPN}-native-foo-native.
                newdeps.append(dep.replace(pn, bpn) + "-native")
            else:
                newdeps.append(dep)
        output_varname = varname
        # Handle ${PN}-xxx -> ${BPN}-xxx-native
        if suffix != "${PN}" and "${PN}" in suffix:
            output_varname = varname.replace("${PN}", "${BPN}") + "-native"
            d.renameVar(varname, output_varname)
        d.setVar(output_varname, " ".join(newdeps))

    map_dependencies("DEPENDS", e.data, selfref=False)
    # We need to handle things like ${@bb.utils.contains('PTEST_ENABLED', '1', '${PN}-ptest', '', d)}
    # and not pass ${PN}-test since in the native case it would be ignored. This does mean we ignore
    # anonymous python derived PACKAGES entries.
    for pkg in re.split(r"\${@(?:{.*?}|.)+?}|\s", d.getVar("PACKAGES", False)):
        if not pkg:
            continue
        map_dependencies("RDEPENDS", e.data, pkg)
        map_dependencies("RRECOMMENDS", e.data, pkg)
        map_dependencies("RSUGGESTS", e.data, pkg)
        map_dependencies("RPROVIDES", e.data, pkg)
        map_dependencies("RREPLACES", e.data, pkg)
    map_dependencies("PACKAGES", e.data)
    map_dependencies("PACKAGES_DYNAMIC", e.data, regex=True)

    provides = e.data.getVar("PROVIDES")
    nprovides = []
    for prov in provides.split():
        if prov.find(pn) != -1:
            nprovides.append(prov)
        elif not prov.endswith("-native"):
            nprovides.append(prov + "-native")
        else:
            nprovides.append(prov)
    e.data.setVar("PROVIDES", ' '.join(nprovides))


}

addhandler native_virtclass_handler
native_virtclass_handler[eventmask] = "bb.event.RecipePreFinalise"

python do_addto_recipe_sysroot () {
    bb.build.exec_func("extend_recipe_sysroot", d)
}
addtask addto_recipe_sysroot after do_populate_sysroot
do_addto_recipe_sysroot[deptask] = "do_populate_sysroot"

inherit nopackages

do_packagedata[stamp-extra-info] = ""

USE_NLS = "no"

RECIPERDEPTASK = "do_populate_sysroot"
do_populate_sysroot[rdeptask] = "${RECIPERDEPTASK}"

#
# Native task outputs are directly run on the target (host) system after being
# built. Even if the output of this recipe doesn't change, a change in one of
# its dependencies may cause a change in the output it generates (e.g. rpm
# output depends on the output of its dependent zstd library).
#
# This can cause poor interactions with hash equivalence, since this recipes
# output-changing dependency is "hidden" and downstream task only see that this
# recipe has the same outhash and therefore is equivalent. This can result in
# different output in different cases.
#
# To resolve this, unhide the output-changing dependency by adding its unihash
# to this tasks outhash calculation. Unfortunately, don't know specifically
# know which dependencies are output-changing, so we have to add all of them.
#
python native_add_do_populate_sysroot_deps () {
    current_task = "do_" + d.getVar("BB_CURRENTTASK")
    if current_task != "do_populate_sysroot":
        return

    taskdepdata = d.getVar("BB_TASKDEPDATA", False)
    pn = d.getVar("PN")
    deps = {
        dep[0]:dep[6] for dep in taskdepdata.values() if
            dep[1] == current_task and dep[0] != pn
    }

    d.setVar("HASHEQUIV_EXTRA_SIGDATA", "\n".join("%s: %s" % (k, deps[k]) for k in sorted(deps.keys())))
}
SSTATECREATEFUNCS += "native_add_do_populate_sysroot_deps"
