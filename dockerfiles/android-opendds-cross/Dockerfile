FROM debian:stretch

RUN apt-get update && apt-get install -y \
  sudo \
  git \
  zip \
  unzip \
  python \
  g++ \
  gdb \
  gdbserver \
  make \
  cmake \
  openjdk-8-jdk-headless \
  perl-base \
  perl-modules \
  wget \
  curl \
  htop \
  nano

RUN useradd --shell /bin/bash --password "" --groups sudo --create-home droid
USER droid

WORKDIR $HOME

RUN wget -O android-ndk-r19-linux-x86_64.zip \
      https://dl.google.com/android/repository/android-ndk-r19-linux-x86_64.zip && \
    unzip android-ndk-r19-linux-x86_64.zip

RUN ./android-ndk-r19/build/tools/make_standalone_toolchain.py --arch arm64 --api 28 --install-dir ndk-toolchain

ENV PATH=$PATH:$HOME/ndk-toolchain/bin

COPY entrypoint.sh /entrypoint.sh

VOLUME ["$HOME/opendds", "$HOME/opendds-app"]

# The examples below assume that the image was built with 
# `docker build -t android-opendds .`
#
# Run the following command to get usage info (note: this will create the
# volumes listed above).
#
# docker run --rm android-opendds -h
#
# Or, for custom volume locations (here assuming droid u):
#
# docker run --rm -v "$DDS_ROOT":/home/droid/opendds -v "$APP_ROOT":/home/droid/opendds-app android-opendds -h
#
ENTRYPOINT [ "/entrypoint.sh" ]
