DESCRIPTION = "OpenDDS Smartlock application"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit logging
inherit autotools

SRC_URI = "file://SmartlockApp \
file://rtps.ini \
file://smartlock.ini \
file://dpm_password \
file://smartlock.sh \
"

DEPENDS += "opendds opendds-native libgpiod glibc"

RDEPENDS:${PN} += "opendds libgpiod glibc"

export CIAO_ROOT="unused"
export DANCE_ROOT="unused"
export DDS_ROOT="${WORKDIR}/recipe-sysroot/usr/share/DDS_ROOT"
export ACE_ROOT="${DDS_ROOT}/ACE_wrappers"
export MPC_ROOT="${ACE_ROOT}/MPC"
export TAO_ROOT="${ACE_ROOT}/TAO"

export LIBCHECK_PREFIX="${WORKDIR}/recipe-sysroot/usr"
export INSTALL_PREFIX="${WORKDIR}/recipe-sysroot/usr"

export HOST_DDS="${WORKDIR}/recipe-sysroot-native/usr/bin/DDS_HOST_ROOT"
export SSL_ROOT="${WORKDIR}/recipe-sysroot-native/usr"
export XERCESCROOT="${WORKDIR}/recipe-sysroot-native/usr"
export CPATH="${WORKDIR}/recipe-sysroot/usr/include"
export CCFLAGS="--sysroot=${WORKDIR}/recipe-sysroot"

S = "${WORKDIR}/SmartlockApp"
B = "${S}"

do_configure() {
    ${WORKDIR}/recipe-sysroot/usr/share/ace/bin/mwc.pl -type gnuace -features 'no_cxx11=0,no_pigpio=1,ssl=1,xerces3=1,openssl11=1,no_opendds_security=0,cross_compile=1' 
}

do_install() {
    install -d ${D}${bindir}
    install -m 0755 smartlock ${D}${bindir}
    install -m 0755 ${WORKDIR}/smartlock.sh ${D}${bindir} 

    install -d ${D}${sysconfdir}/smartlock
    install -m 0644 ${WORKDIR}/rtps.ini ${D}${sysconfdir}/smartlock 
    install -m 0644 ${WORKDIR}/smartlock.ini ${D}${sysconfdir}/smartlock 
    install -m 0644 ${WORKDIR}/dpm_password ${D}${sysconfdir}/smartlock 
    
    install -d ${D}${libdir}
    cp Idl/libSmartLock_Idl.so.* ${D}${libdir}
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
