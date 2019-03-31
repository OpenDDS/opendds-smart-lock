FROM debian:stretch

ARG OPENDDS_BRANCH=master
ARG OPENDDS_GIT_REPO=https://github.com/objectcomputing/OpenDDS.git
ARG OPENDDS_MAKE_JOBS=4

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

WORKDIR /home/droid

RUN wget -O android-ndk-r19-linux-x86_64.zip \
      https://dl.google.com/android/repository/android-ndk-r19-linux-x86_64.zip && \
    unzip android-ndk-r19-linux-x86_64.zip

RUN ./android-ndk-r19/build/tools/make_standalone_toolchain.py --arch arm64 --api 28 --install-dir ndk-toolchain

ENV ANDROID_NDK=/home/droid/android-ndk-r19
ENV PATH=$ANDROID_NDK/toolchains/llvm/prebuilt/linux-x86_64/bin:$PATH

# Build OpenSSL
RUN wget -O openssl-1.1.1a.tar.gz \
        https://www.openssl.org/source/openssl-1.1.1a.tar.gz && \
    tar xvzf openssl-1.1.1a.tar.gz

RUN cd openssl-1.1.1a && \
  ./Configure android-arm64 -D__ANDROID_API__=28 no-shared --prefix=/home/droid/droid-openssl && \
  make -j4 && make install

# Build Xerces
RUN wget -O xerces-c-3.2.2.tar.gz \
        apache.cs.utah.edu//xerces/c/3/sources/xerces-c-3.2.2.tar.gz && \
        tar xvzf xerces-c-3.2.2.tar.gz

RUN printf "\
set(CMAKE_SYSTEM_NAME Linux)\n \
set(CMAKE_SYSTEM_PROCESSOR arm)\n \
set(CMAKE_C_COMPILER aarch64-linux-android28-clang)\n \
set(CMAKE_CXX_COMPILER aarch64-linux-android28-clang++)\n \
set(CMAKE_FIND_ROOT_PATH /home/droid/toolchains/llvm/prebuilt/linux-x86_64)\n \
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)\n \
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)\n \
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)\n \
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)\n \
set(THREADS_PTHREAD_ARG 2)\n \
" > /home/droid/AndroidToolchain.cmake

RUN cd xerces-c-3.2.2 && \
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
      --macros='ANDROID_ABI=arm64-v8a' \
      --openssl=/home/droid/droid-openssl \
      --xerces3=/home/droid/droid-xerces \
      --security \
      --java

RUN cd droid-opendds/build/host && \
    make -j4 TAO_IDL_EXE && \
    make -j4 opendds_idl && \
    make -j4 idl2jni_codegen

ENV PATH=/home/droid/ndk-toolchain/bin:${PATH}
RUN ["/bin/bash", "-c", \
  "cd droid-opendds/build/target && \
    source setenv.sh && make -j${OPENDDS_MAKE_JOBS}"]

RUN mkdir /home/droid/libs

# Copy dependencies into libs folder.
ENV RUNTIME_LIBS=/home/droid/ndk-toolchain/sysroot/usr/lib/aarch64-linux-android \
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