#
#   Provides a build environment for OpenDDS on Raspberry Pi with WiringPi to
#   control the GPIO pins.
#
#

FROM debian:stretch

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
  nano

RUN useradd --shell /bin/bash --password "" --groups sudo --create-home pi
USER pi

WORKDIR /home/pi
RUN sudo apt-get install -y bsdtar \
    && sudo cp $(which tar) $(which tar)~ \
    && sudo ln -sf $(which bsdtar) $(which tar)

#RUN wget -O cross-gcc-8.3.0-pi_2-3.tar.gz \
#      https://sourceforge.net/projects/raspberry-pi-cross-compilers/files/Raspberry%20Pi%20GCC%20Cross-Compiler%20Toolchains/GCC%208.3.0/Raspberry%20Pi%202%2C%203/cross-gcc-8.3.0-pi_2-3.tar.gz/download
#RUN tar -xvzf cross-gcc-8.3.0-pi_2-3.tar.gz

RUN wget --no-check-certificate -O gcc-8.2.0-rpi.tar.bz2 \
      http://download.objectcomputing.com/OpenDDS/resources/gcc-8.2.0-rpi.tar.bz2
RUN tar -xvzf gcc-8.2.0-rpi.tar.bz2

RUN sudo mv $(which tar)~ $(which tar)

#RUN mv /home/pi/cross-pi-gcc-8.2.0 /home/pi/opt/cross-pi-gcc

RUN sudo ln -s /home/pi/cross-pi-gcc-8.2.0 /opt/cross-pi-gcc
RUN sudo ln -s /home/pi/cross-pi-gcc-8.2.0 /opt/cross-pi-gcc-8.2.0-1

ENV PATH=${PATH}:/opt/cross-pi-gcc/bin

RUN wget -O openssl-1.1.1a.tar.gz \
      https://www.openssl.org/source/openssl-1.1.1a.tar.gz && \
  tar xvzf openssl-1.1.1a.tar.gz

ENV BUILD_ROOT /home/pi

RUN cd openssl-1.1.1a && \
  ./Configure --cross-compile-prefix=arm-linux-gnueabihf- linux-armv4 && \
  make && make install DESTDIR=${BUILD_ROOT}/pi-openssl

RUN printf "\
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

RUN wget -O xerces-c-3.2.2.tar.gz \
      apache.cs.utah.edu//xerces/c/3/sources/xerces-c-3.2.2.tar.gz && \
    tar xvzf xerces-c-3.2.2.tar.gz

RUN cd xerces-c-3.2.2 && \
  mkdir build-pi && cd build-pi && \
  cmake -DCMAKE_TOOLCHAIN_FILE=${BUILD_ROOT}/PiToolchain.cmake \
    -DCMAKE_INSTALL_PREFIX=${BUILD_ROOT}/pi-xerces .. && \
  make && make install

RUN git clone -b ${OPENDDS_BRANCH} ${OPENDDS_GIT_REPO} pi-opendds

RUN cd pi-opendds && \
  ./configure --prefix=${OPENDDS_PREFIX} \
    --ace-github-latest \
    --security --no-tests --target=linux-cross \
    --target-compiler=arm-linux-gnueabihf-g++ \
    --openssl=${BUILD_ROOT}/pi-openssl/usr/local \
    --xerces3=${BUILD_ROOT}/pi-xerces && \
  make -j${OPENDDS_MAKE_JOBS}

RUN tar cvzf pi-openssl.tar.gz pi-openssl
RUN tar cvzf pi-xerces.tar.gz pi-xerces
RUN tar cvzhf pi-opendds.tar.gz pi-opendds/build/target/ACE_TAO/ACE/lib pi-opendds/build/target/lib

RUN git clone git://git.drogon.net/wiringPi
RUN cd wiringPi/wiringPi && \
  make CC=/opt/cross-pi-gcc/bin/arm-linux-gnueabihf-gcc

RUN cd wiringPi/wiringPi && \
  mv libwiringPi.so.2.50 libwiringPi.so

ENV WIRING_PI ${BUILD_ROOT}/wiringPi/wiringPi

CMD ["/bin/bash"]
