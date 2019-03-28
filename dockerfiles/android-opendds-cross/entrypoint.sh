#!/bin/bash
set -e

USAGE="
Usage:
    android-opendds [CMD] 
        build-opendds DEST
        build-app DDS_ROOT JAVA_IDL_DIR APP_NAME APP_MPC_NAME
        copydeps DDS_ROOT JAVA_IDL_DIR APP_MPC_NAME APP_JAR_NAME DEST
"

error() {
    MSG="${1}"
    echo "ERROR: ${MSG}"
    return 1
}

build_openssl() {
    export ANDROID_NDK=$HOME/android-ndk-r19
    PATH="$ANDROID_NDK/toolchains/llvm/prebuilt/linux-x86_64/bin:$PATH"

    pushd $HOME
    wget -O openssl-1.1.1a.tar.gz \
        https://www.openssl.org/source/openssl-1.1.1a.tar.gz && \
    tar xvzf openssl-1.1.1a.tar.gz

    pushd openssl-1.1.1a
    ./Configure android-arm64 -D__ANDROID_API__=28 no-shared --prefix=$HOME/droid-openssl
    make -j4 && make install
    popd
    popd
}

build_xerces() {
    export ANDROID_NDK=$HOME/android-ndk-r19
    PATH="$ANDROID_NDK/toolchains/llvm/prebuilt/linux-x86_64/bin:$PATH"

    pushd $HOME
    wget -O xerces-c-3.2.2.tar.gz \
        apache.cs.utah.edu//xerces/c/3/sources/xerces-c-3.2.2.tar.gz && \
        tar xvzf xerces-c-3.2.2.tar.gz
    
    pushd xerces-c-3.2.2
    printf "\
set(CMAKE_SYSTEM_NAME Linux)\n \
set(CMAKE_SYSTEM_PROCESSOR arm)\n \
set(CMAKE_C_COMPILER aarch64-linux-android28-clang)\n \
set(CMAKE_CXX_COMPILER aarch64-linux-android28-clang++)\n \
set(CMAKE_FIND_ROOT_PATH $HOME/toolchains/llvm/prebuilt/linux-x86_64)\n \
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)\n \
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)\n \
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)\n \
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)\n \
set(THREADS_PTHREAD_ARG 2)\n \
" > $HOME/AndroidToolchain.cmake

    mkdir build-android && cd build-android && \
    cmake -DCMAKE_TOOLCHAIN_FILE=$HOME/AndroidToolchain.cmake \
          -DCMAKE_INSTALL_PREFIX=$HOME/droid-xerces .. && \
    make && make install
    popd
    popd
}

build_iconv() {
    export ANDROID_NDK=$HOME/android-ndk-r19
    PATH="$ANDROID_NDK/toolchains/llvm/prebuilt/linux-x86_64/bin:$PATH"

    pushd $HOME
    wget https://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.15.tar.gz && \
        tar xvzf libiconv-1.15.tar.gz
    pushd libiconv-1.15
    ./configure \
        --host=aarch64-linux-android28 \
        CC=aarch64-linux-android28-clang \
        CXX=aarch64-linux-android28-clang++ \
        LD=aarch64-linux-android28-ld \
        CFLAGS="-fPIE -fPIC" \
        LDFLAGS="-pie"
    popd; popd
}

OPENDDS_BRANCH="master"
OPENDDS_REPO="mmcparlane/OpenDDS.git"
build_opendds() {
    DEST="${1}"

    #build_openssl
    #build_xerces

    git clone -b ${OPENDDS_BRANCH} https://github.com/${OPENDDS_REPO} ${DEST}

    pushd ${DEST}

    ./configure \
        --no-tests \
        --ace-github-latest \
        --target=android \
        --macros='ANDROID_ABI=arm64-v8a' \
        --openssl=$HOME/droid-openssl \
        --xerces3=$HOME/droid-xerces \
        --security \
        --java
    
    pushd build/host

    make -j4 TAO_IDL_EXE && \
    make -j4 opendds_idl && \
    make -j4 idl2jni_codegen

    popd
    pushd build/target

    ( source setenv.sh; make -j4; )

    popd
    popd
}

build_app() {
    DDS_ROOT="${1}"
    JAVA_IDL_DIR="${2}"
    APP_NAME="${3}"
    APP_MPC_NAME="${4}"
    [[ ! -d "${DDS_ROOT}" ]] && error "invalid DDS_ROOT directory specified"
    [[ ! -d "${JAVA_IDL_DIR}" ]] && error "invalid JAVA_IDL_DIR directory specified"

    ( source ${DDS_ROOT}/build/target/setenv.sh && \
        cd ${JAVA_IDL_DIR}/.. && \
        mwc.pl -type gnuace . && \
        cd ${JAVA_IDL_DIR} && \
        make -f GNUmakefile.${APP_MPC_NAME} ${APP_NAME}TypeSupportJC.h && \
        make && \
        $DDS_ROOT/java/build_scripts/javac_wrapper.pl \
          -sourcepath . \
          -d classes \
          -classpath . \
          -implicit:none \
          -classpath $DDS_ROOT/lib/i2jrt_compact.jar \
          -classpath $DDS_ROOT/lib/i2jrt.jar \
          -classpath $DDS_ROOT/lib/OpenDDS_DCPS.jar \
          ${APP_NAME}/*; )
}

copydeps() {
    DDS_ROOT="${1}"
    JAVA_IDL_DIR="${2}"
    [[ ! -d "${DDS_ROOT}" ]] && error "invalid DDS_ROOT directory specified"
    DDS_LIBS="${DDS_ROOT}/build/target/lib"
    ACE_LIBS="${DDS_ROOT}/build/target/ACE_TAO/ACE/lib"
    APP_MPC_NAME="${3}"
    APP_JAR_NAME="${4}"
    DEST="${5}"

    RUNTIME_LIBS=$HOME/ndk-toolchain/sysroot/usr/lib/aarch64-linux-android
    XERCES_LIBS=$HOME/droid-xerces/lib

    [[ ! -d "${ACE_LIBS}" ]] && error "invalid ACE lib directory specified"
    [[ ! -d "${DDS_LIBS}" ]] && error "invalid DDS lib directory specified"
    [[ ! -d "${JAVA_IDL_DIR}" ]] && error "invalid app. lib directory specified"
    [[ ! -d "${DEST}" ]] && error "invalid output directory specified"

    cp ${RUNTIME_LIBS}/libc++_shared.so ${DEST}
    cp ${XERCES_LIBS}/libxerces-c-3.2.so ${DEST}

    for i in libACE.so libTAO.so libTAO_AnyTypeCode.so libTAO_BiDirGIOP.so \
                libTAO_CodecFactory.so libTAO_PI.so libTAO_PortableServer.so \
                libACE_XML_Utils.so; do
        cp ${ACE_LIBS}/${i} ${DEST}
    done

    cp ${DDS_LIBS}/* ${DEST}

    for i in ${APP_JAR_NAME}.jar lib${APP_MPC_NAME}.so; do
        cp ${JAVA_IDL_DIR}/${i} ${DEST}
    done
}

case "${1}" in
        build-opendds)
                build_opendds "${2}"
                ;;
        build-app)
                build_app "${2}" "${3}" "${4}" "${5}"
                ;;
        copydeps)
                copydeps "${2}" "${3}" "${4}" "${5}" "${6}"
                ;;
                
        -h|--help)
                echo "${USAGE}"
                ;;
esac
