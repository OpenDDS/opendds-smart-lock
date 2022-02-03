#!/bin/bash -e
BUILD_DIR=`pwd`
OPENDDS_BRANCH=master
OPENDDS_GIT_REPO=https://github.com/objectcomputing/OpenDDS
OPENDDS_MAKE_JOBS=4
OPENDDS_PREFIX=${BUILD_DIR}/pi-opendds

wget -nc -O gcc-arm-10.2-2020.11-x86_64-arm-none-linux-gnueabihf.tar.xz \
    "https://developer.arm.com/-/media/Files/downloads/gnu-a/10.2-2020.11/binrel/gcc-arm-10.2-2020.11-x86_64-arm-none-linux-gnueabihf.tar.xz?revision=d0b90559-3960-4e4b-9297-7ddbc3e52783&hash=6F50B04F08298881CA3596CE99E5ABB3925DEB24"

tar -xvf gcc-arm-10.2-2020.11-x86_64-arm-none-linux-gnueabihf.tar.xz

CROSS_PI_GCC=${BUILD_DIR}/gcc-arm-10.2-2020.11-x86_64-arm-none-linux-gnueabihf

PATH+=:${CROSS_PI_GCC}/bin

wget -nc https://www.openssl.org/source/openssl-1.1.1m.tar.gz
tar xzf openssl-1.1.1m.tar.gz

export BUILD_ROOT=$BUILD_DIR

(cd openssl-1.1.1m && \
	  ./Configure --cross-compile-prefix=arm-none-linux-gnueabihf- linux-armv4 && \
	  make && make install DESTDIR=${BUILD_ROOT}/pi-openssl)

printf "\
	set(CMAKE_SYSTEM_NAME Linux)\n \
	set(CMAKE_SYSTEM_PROCESSOR arm)\n \
	set(CMAKE_C_COMPILER arm-none-linux-gnueabihf-gcc)\n \
	set(CMAKE_CXX_COMPILER arm-none-linux-gnueabihf-g++)\n \
	set(CMAKE_FIND_ROOT_PATH /opt/cross-pi-gcc/arm-none-linux-gnueabihf)\n \
	set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)\n \
	set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)\n \
	set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)\n \
	set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)\n \
	set(THREADS_PTHREAD_ARG 2)\n \
	" > ${BUILD_ROOT}/PiToolchain.cmake

wget -nc https://dlcdn.apache.org//xerces/c/3/sources/xerces-c-3.2.3.tar.gz
tar xzf xerces-c-3.2.3.tar.gz

(cd xerces-c-3.2.3 && \
  mkdir -p build-pi && cd build-pi && \
  cmake -DCMAKE_TOOLCHAIN_FILE=${BUILD_ROOT}/PiToolchain.cmake -DCMAKE_INSTALL_PREFIX=${BUILD_ROOT}/pi-xerces .. && \
  make && make install)

git clone --depth=1 -b ${OPENDDS_BRANCH} ${OPENDDS_GIT_REPO} pi-opendds

(cd pi-opendds && \
  ./configure --prefix=$OPENDDS_PREFIX --ace-github-latest --security --no-tests --target=linux-cross \
    --target-compiler=arm-none-linux-gnueabihf-g++ --openssl=$BUILD_ROOT/pi-openssl/usr/local --xerces3=$BUILD_ROOT/pi-xerces && \
  make -j${OPENDDS_MAKE_JOBS})

tar czf pi-openssl.tar.gz pi-openssl
tar czf pi-xerces.tar.gz pi-xerces
tar czhf pi-opendds.tar.gz pi-opendds/build/target/ACE_TAO/ACE/lib pi-opendds/build/target/lib

wget -O pigpio-v79.tar.gz https://github.com/joan2937/pigpio/archive/refs/tags/v79.tar.gz
tar xzvf pigpio-v79.tar.gz

(cd pigpio-79 && \
    make CROSS_PREFIX=arm-none-linux-gnueabihf- && \
    make install DESTDIR=${BUILD_ROOT}/pigpio prefix=)

tar czvf pigpio.tar.gz pigpio
