#
#   Provides a build environment for OpenDDS on Raspberry Pi with WiringPi to
#   control the GPIO pins.
#
#

FROM debian:bullseye

ARG BUILD_DIR=/home/pi
ARG OPENDDS_BRANCH=master
ARG OPENDDS_GIT_REPO=https://github.com/objectcomputing/OpenDDS.git
ARG OPENDDS_MAKE_JOBS=4
ARG OPENDDS_PREFIX=${BUILD_DIR}/pi-opendds

RUN apt-get update && apt-get install -y \
  sudo \
  build-essential gawk gcc g++ gfortran git texinfo bison \
  make \
  cmake \
  libxerces-c-dev \
  libssl-dev \
  perl-base \
  perl-modules \
  wget \
  curl \
  htop \
  xz-utils \
  nano

RUN useradd --shell /bin/bash --password "" --groups sudo --create-home pi
USER pi

WORKDIR /home/pi

RUN wget -q -O gcc-arm-10.2-2020.11-x86_64-arm-none-linux-gnueabihf.tar.xz \
    "https://developer.arm.com/-/media/Files/downloads/gnu-a/10.2-2020.11/binrel/gcc-arm-10.2-2020.11-x86_64-arm-none-linux-gnueabihf.tar.xz?revision=d0b90559-3960-4e4b-9297-7ddbc3e52783&hash=6F50B04F08298881CA3596CE99E5ABB3925DEB24" && \
  tar -xvf gcc-arm-10.2-2020.11-x86_64-arm-none-linux-gnueabihf.tar.xz

ENV BUILD_ROOT /home/pi
ENV CROSS_PI_GCC=${BUILD_ROOT}/gcc-arm-10.2-2020.11-x86_64-arm-none-linux-gnueabihf
ENV PATH=${PATH}:${CROSS_PI_GCC}/bin

RUN wget -O openssl-1.1.1m.tar.gz \
      https://www.openssl.org/source/openssl-1.1.1m.tar.gz && \
  tar xvzf openssl-1.1.1m.tar.gz

RUN cd openssl-1.1.1m && \
  ./Configure --cross-compile-prefix=arm-none-linux-gnueabihf- linux-armv4 && \
  make && make install DESTDIR=${BUILD_ROOT}/pi-openssl

RUN printf "\
set(CMAKE_SYSTEM_NAME Linux)\n \
set(CMAKE_SYSTEM_PROCESSOR arm)\n \
set(CMAKE_C_COMPILER arm-none-linux-gnueabihf-gcc)\n \
set(CMAKE_CXX_COMPILER arm-none-linux-gnueabihf-g++)\n \
set(CMAKE_FIND_ROOT_PATH ${CROSS_PI_GCC}/arm-none-linux-gnueabihf)\n \
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)\n \
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)\n \
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)\n \
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)\n \
set(THREADS_PTHREAD_ARG 2)\n \
" > ${BUILD_ROOT}/PiToolchain.cmake

RUN wget -O xerces-c-3.2.3.tar.gz \
      https://dlcdn.apache.org//xerces/c/3/sources/xerces-c-3.2.3.tar.gz && \
    tar xvzf xerces-c-3.2.3.tar.gz

RUN cd xerces-c-3.2.3 && \
  mkdir build-pi && cd build-pi && \
  cmake -DCMAKE_TOOLCHAIN_FILE=${BUILD_ROOT}/PiToolchain.cmake \
    -DCMAKE_INSTALL_PREFIX=${BUILD_ROOT}/pi-xerces .. && \
  make && make install

RUN git clone -b ${OPENDDS_BRANCH} ${OPENDDS_GIT_REPO} pi-opendds

RUN cd pi-opendds && \
  ./configure --prefix=${OPENDDS_PREFIX} \
    --ace-github-latest \
    --security --target=linux-cross \
    --target-compiler=arm-none-linux-gnueabihf-g++ \
    --openssl=${BUILD_ROOT}/pi-openssl/usr/local \
    --xerces3=${BUILD_ROOT}/pi-xerces && \
  make -j${OPENDDS_MAKE_JOBS}

RUN tar cvzf pi-openssl.tar.gz pi-openssl
RUN tar cvzf pi-xerces.tar.gz pi-xerces
RUN tar cvzhf pi-opendds.tar.gz pi-opendds/build/target/ACE_TAO/ACE/lib pi-opendds/build/target/lib

RUN wget -O pigpio-v79.tar.gz https://github.com/joan2937/pigpio/archive/refs/tags/v79.tar.gz && \
  tar xzvf pigpio-v79.tar.gz

RUN cd pigpio-79 && \
    make CROSS_PREFIX=arm-none-linux-gnueabihf- && \
    make install DESTDIR=${BUILD_ROOT}/pigpio prefix=

RUN tar czvf pigpio.tar.gz pigpio

ENV PIGPIO_DIR=${BUILD_ROOT}/pigpio

CMD ["/bin/bash"]
