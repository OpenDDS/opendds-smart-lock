# Specify SHA-1 for the release to avoid constantly checking the upstream repo.

SRCREV = "9ededb80594119d8d54b1622cc68f4666b1479a5"
DDS_SRC_BRANCH = "branch-DDS-3.24"
SRC_URI = "git://github.com/OpenDDS/OpenDDS.git;protocol=https;branch=${DDS_SRC_BRANCH};name=opendds"
SRC_URI += "file://SmartlockApp.tar.gz" 
SRC_URI += "file://dds_custom.mwc" 

SUMMARY = "OpenDDS is an open source C++ implementation of the Object Management Group (OMG) Data Distribution Service (DDS)"
HOMEPAGE = "https://opendds.org"

LICENSE = "OpenDDS"
LIC_FILES_CHKSUM = "file://LICENSE;md5=11ee76f6fb51f69658b5bb8327c50b11"

inherit autotools

DEPENDS += " \
    perl-native \
    cmake-native \
    smartlock-native \
    openssl \
    xerces-c \     
"

RDEPENDS:${PN}-dev += " coreutils perl"

S = "${WORKDIR}/git"

# Set the build directory to be the source directory
B = "${S}"

do_unpack_extra() {
    # the configure script does not support arguments to the cross compiler
    # but the bitbake toolchain needs those
    # create shell scripts which inject the arguments into the calls
    cc_bin=${S}/${HOST_PREFIX}gcc
    echo '#!/bin/sh' > ${cc_bin}
    echo "${CC} \"\$@\"" >> ${cc_bin}
    chmod +x ${cc_bin}

    cxx_bin=${S}/${HOST_PREFIX}g++
    echo '#!/bin/sh' > ${cxx_bin}
    echo "${CXX} \"\$@\"" >> ${cxx_bin}
    chmod +x ${cxx_bin}

    ar_bin=${S}/${HOST_PREFIX}ar
    echo '#!/bin/sh' > ${ar_bin}
    echo "${AR} \"\$@\"" >> ${ar_bin}
    chmod +x ${ar_bin}
}
addtask unpack_extra after do_unpack before do_patch

OECONF ??= ""
OECONF:append = "\
    --prefix=${prefix} \
    --verbose \
    --no-tests \
    --no-rapidjson \
    --security \
    --openssl=${WORKDIR}/recipe-sysroot/usr \
    --xerces3=${WORKDIR}/recipe-sysroot/usr \
    --workspace=${WORKDIR}/dds_custom.mwc \
"

OECONF:append:class-target = "\
    --host-tools=${STAGING_BINDIR_NATIVE}/DDS_HOST_ROOT \
    --target=linux-cross \
    --target-compiler=${S}/${HOST_PREFIX}g++ \
"
OECONF:append:class-native = "\
    --target=linux \
    --host-tools-only \
    --security \
    --openssl=${WORKDIR}/recipe-sysroot-native/usr \
    --xerces3=${WORKDIR}/recipe-sysroot-native/usr \
"
OECONF:append:class-nativesdk = "\
    --compiler=${S}/${HOST_PREFIX}g++ \
    --target=linux \
    --host-tools-only \
"

do_configure() {
    cp -r ${WORKDIR}/SmartlockApp ${S}/SmartlockApp
    ./configure ${OECONF}
}

do_install:append:class-target() {
    rm ${D}${datadir}/dds/dds/Version.h
    cp ${D}${includedir}/dds/Version.h ${D}${datadir}/dds/dds

    sed -i -e s:${D}/::g ${D}${datadir}/dds/dds-devel.sh

    # workaround: /usr/share/dds/dds/idl/IDLTemplate.txt should be placed into target sysroot
    install -d ${D}${datadir}/dds/dds/idl
    cp ${S}/dds/idl/IDLTemplate.txt ${D}${datadir}/dds/dds/idl

    for shared_lib in ${D}${libdir}/*.so.*; do
        if [ -f $shared_lib ]; then
            baselib=$(basename $shared_lib)
            shortlib=$(echo $baselib | sed 's/.so.*//')
            extn=$(echo $baselib | sed -n 's/^[^.]*\.so//p')
            extn=$(echo $extn | sed 's/[^. 0-9]*//g')
            while [ -n "$extn" ]; do
                extn=$(echo $extn | sed 's/\.[^.]*$//')
                ln -sf $baselib ${D}${libdir}/$shortlib.so$extn
            done
        fi
    done
}

do_install:append:class-native() {
    rm ${D}${datadir}/dds/bin/opendds_idl
    rm ${D}${datadir}/ace/bin/ace_gperf
    rm ${D}${datadir}/ace/bin/tao_idl
}

do_install:append:class-native() {
    # Prepare HOST_ROOT expected by DDS for target build
    mkdir -p ${D}${bindir}/DDS_HOST_ROOT/ACE_wrappers/bin
    mkdir -p ${D}${bindir}/DDS_HOST_ROOT/bin
    ln -sr ${D}${bindir}/opendds_idl ${D}${bindir}/DDS_HOST_ROOT/bin/opendds_idl
    ln -sr ${D}${bindir}/ace_gperf ${D}${bindir}/DDS_HOST_ROOT/ACE_wrappers/bin/ace_gperf
    ln -sr ${D}${bindir}/tao_idl ${D}${bindir}/DDS_HOST_ROOT/ACE_wrappers/bin/tao_idl
}

do_install:append:class-nativesdk() {
    ln -sf ${bindir}/opendds_idl ${D}${datadir}/dds/bin/opendds_idl
    ln -sf ${bindir}/ace_gperf ${D}${datadir}/ace/bin/ace_gperf
    ln -sf ${bindir}/tao_idl ${D}${datadir}/ace/bin/tao_idl
}

INSANE_SKIP:${PN} += "dev-so"

FILES:SOLIBSDEV = ""
FILES:${PN} += "${libdir}/*.so"
FILES:${PN}-dev += "${datadir}"

BBCLASSEXTEND = "native nativesdk"

DOC_TAO2_VERSION = "6.5.19"

DOC_TAO2_SHA256SUM = "e0d5faf9ec6fa457747776293eab2c71502109b6655de0e62f30dace04af809c"

DOC_TAO2_URI = "https://github.com/DOCGroup/ACE_TAO/releases/download/ACE+TAO-${@'${DOC_TAO2_VERSION}'.replace('.','_')}/ACE+TAO-src-${DOC_TAO2_VERSION}.tar.gz"

SRC_URI += "${DOC_TAO2_URI};name=ace_tao;unpack=0;subdir=git"
SRC_URI[ace_tao.sha256sum] = "${DOC_TAO2_SHA256SUM}"