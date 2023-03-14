FROM debian:bullseye

ARG BUILD_DIR=/home/droid
ARG OPENDDS_BRANCH=master
ARG OPENDDS_GIT_REPO=https://github.com/objectcomputing/OpenDDS.git
ARG OPENDDS_MAKE_JOBS=4

# these can be overridden with --build-args
ARG API=31
ARG MIN_API=26
ARG ABI=arm64-v8a
ARG ABI_PREFIX=aarch64-linux-android
ARG RUNTIME_ROOT=$ABI_PREFIX
ARG PLATFORM=android-arm64
ARG BUILD_SOURCE

ENV ANDROID_API=$API
ENV ANDROID_MIN_API=$MIN_API
ENV ANDROID_ABI=$ABI
ENV ANDROID_ABI_PREFIX=$ABI_PREFIX
ENV ANDROID_RUNTIME_ROOT=$RUNTIME_ROOT
ENV ANDROID_ARCH=$PLATFORM
ENV ANDROID_CC="${ABI_PREFIX}${API}-clang"
ENV ANDROID_CXX="${ABI_PREFIX}${API}-clang++"

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
  openjdk-11-jdk-headless \
  perl-base \
  perl-modules \
  wget \
  curl \
  htop \
  nano

RUN useradd --shell /bin/bash --password "" --groups sudo --create-home droid
USER droid

WORKDIR /home/droid


# download ndk
RUN wget -O android-ndk-r23b-linux.zip \
      https://dl.google.com/android/repository/android-ndk-r23b-linux.zip && \
    unzip android-ndk-r23b-linux.zip

ENV ANDROID_NDK=/home/droid/android-ndk-r23b
ENV PATH=$ANDROID_NDK/toolchains/llvm/prebuilt/linux-x86_64/bin:$PATH

# download sdk commandline tools
RUN wget -O commandlinetools-linux-8092744_latest.zip \
      https://dl.google.com/android/repository/commandlinetools-linux-8092744_latest.zip && \
    unzip commandlinetools-linux-8092744_latest.zip

ENV ANDROID_SDK=/home/droid/android_sdk

RUN yes | /home/droid/cmdline-tools/bin/sdkmanager --sdk_root=${ANDROID_SDK} "platforms;android-${ANDROID_API}"


# Build OpenSSL
RUN wget -O openssl-1.1.1m.tar.gz \
        https://www.openssl.org/source/openssl-1.1.1m.tar.gz && \
    tar xvzf openssl-1.1.1m.tar.gz

RUN cd openssl-1.1.1m && \
  ./Configure ${ANDROID_ARCH} -D__ANDROID_API__=${ANDROID_MIN_API} no-shared -Wno-macro-redefined --prefix=/home/droid/droid-openssl && \
  make -j4 && make install

# Download CMake
RUN wget -O cmake-3.23.1-Linux-x86_64.tar.gz \
        https://github.com/Kitware/CMake/releases/download/v3.23.1/cmake-3.23.1-linux-x86_64.tar.gz && \
        tar xzvf cmake-3.23.1-Linux-x86_64.tar.gz

ENV PATH="/home/droid/cmake-3.23.1-linux-x86_64/bin:${PATH}"

# Build Xerces
RUN wget -O xerces-c-3.2.4.tar.gz \
        https://dlcdn.apache.org//xerces/c/3/sources/xerces-c-3.2.4.tar.gz && \
        tar xvzf xerces-c-3.2.4.tar.gz

RUN cd xerces-c-3.2.4 && \
  mkdir build && cd build && \
  cmake -DCMAKE_TOOLCHAIN_FILE=/$ANDROID_NDK/build/cmake/android.toolchain.cmake \
        -DANDROID_ABI=${ANDROID_ABI} -DANDROID_PLATFORM=${ANDROID_API} \
        -DCMAKE_INSTALL_PREFIX=/home/droid/droid-xerces .. && \
  make && make install

# Build OpenDDS

RUN git clone -b ${OPENDDS_BRANCH} ${OPENDDS_GIT_REPO} droid-opendds

RUN cd droid-opendds && \
    ./configure \
      --ace-github-latest \
      --target=android \
      --macros=android_abi=${ANDROID_ABI} \
      --macros=android_api=${ANDROID_MIN_API} \
      --macros=android_ndk=${ANDROID_NDK} \
      --macros=android_sdk=${ANDROID_SDK} \
      --macros=android_target_api=${ANDROID_API} \
      --macros=no_hidden_visibility=1 \
      --openssl=/home/droid/droid-openssl \
      --xerces3=/home/droid/droid-xerces \
      --security \
      --java

RUN cd droid-opendds/build/host && \
    make -j${OPENDDS_MAKE_JOBS} TAO_IDL_EXE && \
    make -j${OPENDDS_MAKE_JOBS} opendds_idl && \
    make -j${OPENDDS_MAKE_JOBS} idl2jni_codegen

RUN cd droid-opendds/build/target && \
    make -j${OPENDDS_MAKE_JOBS}

RUN mkdir /home/droid/libs

# Copy dependencies into libs folder.
ENV RUNTIME_LIBS=${ANDROID_NDK}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/${ANDROID_RUNTIME_ROOT} \
  XERCES_LIBS=/home/droid/droid-xerces/lib \
  DDS_LIBS=/home/droid/droid-opendds/build/target/lib \
  ACE_LIBS=/home/droid/droid-opendds/build/target/ACE_TAO/ACE/lib

RUN cp ${RUNTIME_LIBS}/libc++_shared.so /home/droid/libs && \
    cp ${XERCES_LIBS}/libxerces-c-3.2.so /home/droid/libs

RUN cp ${ACE_LIBS}/* /home/droid/libs && \
    cp ${DDS_LIBS}/* /home/droid/libs

## Build the compile script
COPY --chown=droid clone-smartlock ${BUILD_DIR}/compile.sh
COPY --chown=droid android-compile ${BUILD_DIR}
RUN cat ${BUILD_DIR}/android-compile >> ${BUILD_DIR}/compile.sh && rm ${BUILD_DIR}/android-compile

RUN if [ -n "$BUILD_SOURCE" ]; then bash ./compile.sh; fi

CMD ["/bin/bash"]
