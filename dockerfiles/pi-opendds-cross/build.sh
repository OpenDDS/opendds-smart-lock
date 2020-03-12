#!/bin/bash -e
BUILD_DIR=`pwd`
OPENDDS_BRANCH=master
OPENDDS_GIT_REPO=https://github.com/objectcomputing/OpenDDS
OPENDDS_MAKE_JOBS=4
OPENDDS_PREFIX=${BUILD_DIR}/pi-opendds

wget -nc http://download.objectcomputing.com/OpenDDS/resources/gcc-8.2.0-rpi.tar.bz2
tar xjf gcc-8.2.0-rpi.tar.bz2

ln -sf $BUILD_DIR/cross-pi-gcc-8.2.0 /opt/cross-pi-gcc

PATH+=:/opt/cross-pi-gcc/bin

wget -nc https://www.openssl.org/source/openssl-1.1.1a.tar.gz
tar xzf openssl-1.1.1a.tar.gz

export BUILD_ROOT=$BUILD_DIR

(cd openssl-1.1.1a && \
	  ./Configure --cross-compile-prefix=arm-linux-gnueabihf- linux-armv4 && \
	  make && make install DESTDIR=${BUILD_ROOT}/pi-openssl)

printf "\
	set(CMAKE_SYSTEM_NAME Linux)\n \
	set(CMAKE_SYSTEM_PROCESSOR arm)\n \
	set(CMAKE_C_COMPILER arm-linux-gnueabihf-gcc)\n \
	set(CMAKE_CXX_COMPILER arm-linux-gnueabihf-g++)\n \
	set(CMAKE_FIND_ROOT_PATH /opt/cross-pi-gcc/arm-linux-gnueabihf)\n \
	set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)\n \
	set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)\n \
	set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)\n \
	set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)\n \
	set(THREADS_PTHREAD_ARG 2)\n \
	" > ${BUILD_ROOT}/PiToolchain.cmake

wget -nc http://apache.cs.utah.edu/xerces/c/3/sources/xerces-c-3.2.2.tar.gz
tar xzf xerces-c-3.2.2.tar.gz

(cd xerces-c-3.2.2 && \
  mkdir -p build-pi && cd build-pi && \
  cmake -DCMAKE_TOOLCHAIN_FILE=${BUILD_ROOT}/PiToolchain.cmake -DCMAKE_INSTALL_PREFIX=${BUILD_ROOT}/pi-xerces .. && \
  make && make install)

git clone --depth=1 -b ${OPENDDS_BRANCH} ${OPENDDS_GIT_REPO} pi-opendds

(cd pi-opendds && \
  ./configure --prefix=$OPENDDS_PREFIX --ace-github-latest --security --no-tests --target=linux-cross \
    --target-compiler=arm-linux-gnueabihf-g++ --openssl=$BUILD_ROOT/pi-openssl/usr/local --xerces3=$BUILD_ROOT/pi-xerces && \
  make -j${OPENDDS_MAKE_JOBS})

tar czf pi-openssl.tar.gz pi-openssl
tar czf pi-xerces.tar.gz pi-xerces
tar czhf pi-opendds.tar.gz pi-opendds/build/target/ACE_TAO/ACE/lib pi-opendds/build/target/lib

git clone git://git.drogon.net/wiringPi
(cd wiringPi/wiringPi && make CC=arm-linux-gnueabihf-gcc)

(cd wiringPi/wiringPi && mv libwiringPi.so.2.50 libwiringPi.so)
