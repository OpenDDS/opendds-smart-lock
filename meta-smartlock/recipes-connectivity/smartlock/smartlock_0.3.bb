DESCRIPTION = "OpenDDS Smartlock application"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"


SRC_URI = "file://SmartlockApp.tar.gz" 

DOC_TAO2_VERSION = "6.5.19"
DOC_TAO2_SHA256SUM = "e0d5faf9ec6fa457747776293eab2c71502109b6655de0e62f30dace04af809c"
DOC_TAO2_URI = "https://github.com/DOCGroup/ACE_TAO/releases/download/ACE+TAO-${@'${DOC_TAO2_VERSION}'.replace('.','_')}/ACE+TAO-src-${DOC_TAO2_VERSION}.tar.gz"
SRC_URI += "${DOC_TAO2_URI};name=ace_tao;"
SRC_URI[ace_tao.sha256sum] = "${DOC_TAO2_SHA256SUM}"

DEPENDS += "opendds"

S = "${WORKDIR}"
MPC_ROOT = "${S}/ACE_wrappers/MPC"
DDS_ROOT = "${S}/recipe-sysroot/usr/share/dds"
TAO_ROOT = "${S}/recipe-sysroot/usr/share/tao"
ACE_ROOT = "${S}/recipe-sysroot/usr/share/ace"

do_configure() {
    ${ACE_ROOT}/bin/mwc.pl -type gnuace -features 'no_pigpio=1' 
}

do_compile() {
    oe_runmake
}

do_install() {
    install -d ${D}${bindir}
    install -m 0755 smartlock ${D}${bindir}
}