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
COPY --chown=pi ./build.sh ${BUILD_DIR}

USER pi

WORKDIR /home/pi

ENV BUILD_ROOT /home/pi
ENV CROSS_PI_GCC=${BUILD_ROOT}/gcc-arm-10.2-2020.11-x86_64-arm-none-linux-gnueabihf
ENV PATH=${PATH}:${CROSS_PI_GCC}/bin

RUN bash ./build.sh

ENV PIGPIO_DIR=${BUILD_ROOT}/pigpio

CMD ["/bin/bash"]
