FROM debian:bullseye

ARG OPENDDS_BRANCH=master
ARG OPENDDS_GIT_REPO=https://github.com/objectcomputing/OpenDDS.git
ARG OPENDDS_MAKE_JOBS=4

# these can be overridden with --build-args
ARG API=30
ARG ABI=arm64-v8a
ARG ABI_PREFIX=aarch64-linux-android
ARG PLATFORM=android-arm64

ENV ANDROID_API=$API
ENV ANDROID_ABI=$ABI
ENV ANDROID_ABI_PREFIX=$ABI_PREFIX
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
  cmake \
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

RUN wget -O android-ndk-r23b-linux.zip \
      https://dl.google.com/android/repository/android-ndk-r23b-linux.zip && \
    unzip android-ndk-r23b-linux.zip

ENV ANDROID_NDK=/home/droid/android-ndk-r23b
ENV PATH=$ANDROID_NDK/toolchains/llvm/prebuilt/linux-x86_64/bin:$PATH

# Build OpenSSL
RUN wget -O openssl-1.1.1m.tar.gz \
        https://www.openssl.org/source/openssl-1.1.1m.tar.gz && \
    tar xvzf openssl-1.1.1m.tar.gz

RUN cd openssl-1.1.1m && \
  ./Configure ${ANDROID_ARCH} -D__ANDROID_API__=${ANDROID_API} no-shared -Wno-macro-redefined --prefix=/home/droid/droid-openssl && \
  make -j4 && make install

# Build Xerces
RUN wget -O xerces-c-3.2.3.tar.gz \
        https://dlcdn.apache.org//xerces/c/3/sources/xerces-c-3.2.3.tar.gz && \
        tar xvzf xerces-c-3.2.3.tar.gz

RUN printf "\
set(CMAKE_SYSTEM_NAME Linux)\n \
set(CMAKE_SYSTEM_PROCESSOR arm)\n \
set(CMAKE_C_COMPILER ${ANDROID_CC})\n \
set(CMAKE_CXX_COMPILER ${ANDROID_CXX})\n \
set(CMAKE_FIND_ROOT_PATH /home/droid/toolchains/llvm/prebuilt/linux-x86_64)\n \
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)\n \
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)\n \
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)\n \
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)\n \
set(THREADS_PTHREAD_ARG 2)\n \
" > /home/droid/AndroidToolchain.cmake

RUN cd xerces-c-3.2.3 && \
  mkdir build && cd build && \
  cmake -DCMAKE_TOOLCHAIN_FILE=/home/droid/AndroidToolchain.cmake \
        -DCMAKE_INSTALL_PREFIX=/home/droid/droid-xerces .. && \
  make && make install

# Build OpenDDS

RUN git clone -b ${OPENDDS_BRANCH} ${OPENDDS_GIT_REPO} droid-opendds

RUN cd droid-opendds && \
    ./configure \
      --no-tests \
      --ace-github-latest \
      --target=android \
      --macros=android_abi=${ANDROID_ABI} \
      --macros=android_api=${ANDROID_API} \
      --macros=android_ndk=${ANDROID_NDK} \
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
ENV RUNTIME_LIBS=${ANDROID_NDK}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/${ABI_PREFIX} \
  XERCES_LIBS=/home/droid/droid-xerces/lib \
  DDS_LIBS=/home/droid/droid-opendds/build/target/lib \
  ACE_LIBS=/home/droid/droid-opendds/build/target/ACE_TAO/ACE/lib

RUN cp ${RUNTIME_LIBS}/libc++_shared.so /home/droid/libs && \
    cp ${XERCES_LIBS}/libxerces-c-3.2.so /home/droid/libs

RUN for i in libACE.so libTAO.so libTAO_AnyTypeCode.so libTAO_BiDirGIOP.so \
              libTAO_CodecFactory.so libTAO_PI.so libTAO_PortableServer.so \
              libACE_XML_Utils.so; do cp ${ACE_LIBS}/${i} /home/droid/libs; done

RUN cp ${DDS_LIBS}/* /home/droid/libs

CMD ["/bin/bash"]
