DESCRIPTION = "OpenDDS Smartlock application"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit logging
# inherit autotools

SRC_URI = "file://SmartlockApp.tar.gz" 

DEPENDS += "opendds opendds-native"

NATIVE_INSTALL_PREFIX = "${WORKDIR}/recipe-sysroot-native/usr"
TARGET_INSTALL_PREFIX = "${WORKDIR}/recipe-sysroot/usr"

export MPC_ROOT = "${TARGET_INSTALL_PREFIX}/share/MPC"
export ACE_ROOT = "${TARGET_INSTALL_PREFIX}/share/ace"
export DDS_ROOT = "${TARGET_INSTALL_PREFIX}/share/dds"
export TAO_ROOT = "${TARGET_INSTALL_PREFIX}/share/tao"

export LIBCHECK_PREFIX = "${TARGET_INSTALL_PREFIX}"
export INSTALL_PREFIX = "${TARGET_INSTALL_PREFIX}"

export HOST_DDS = "${NATIVE_INSTALL_PREFIX}/bin/DDS_HOST_ROOT"
export HOST_ACE = "${NATIVE_INSTALL_PREFIX}"

# export TAO_IDL_PREPROCESSOR_ARGS = "-I${TARGET_INSTALL_PREFIX}/include"
# export CPPFLAGS = "-I${TARGET_INSTALL_PREFIX}/include"

S = "${WORKDIR}/SmartlockApp"
B = "${S}"

do_configure() {
    ${NATIVE_INSTALL_PREFIX}/share/ace/bin/mwc.pl -type gnuace -features 'no_cxx11=0,no_pigpio=1' 
}

do_compile() {
    make
}

# do_install() {
#     install -d ${D}${bindir}
#     install -m 0755 smartlock ${D}${bindir}
# }  