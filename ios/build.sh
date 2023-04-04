#!/bin/sh -x

SMARTLOCK_DIR=`dirname $0`/..
SMARTLOCK_DIR=`realpath $SMARTLOCK_DIR`

TARGET=arm64
OPENSSL=openssl-1.1.1m
XERCES=xerces-c-3.2.4
XCODE=/Applications/Xcode.app/Contents/Developer
XCODE_BIN=$XCODE/Toolchains/XcodeDefault.xctoolchain/usr/bin
OPENDDS_BRANCH=master
OPENDDS_GIT_REPO=https://github.com/objectcomputing/OpenDDS
MIDDLEWARE=$SMARTLOCK_DIR/flutter/middleware

while [ $# -ne 0 ]; do
  arg="$1"
  shift
  case $arg in
    --help)
      usage=1
      ;;
    --simulator)
      TARGET=simulator
      ;;
    *)
      usage=1
      ;;
  esac
done

if [ -n "$usage" ]; then
  echo "Usage: `basename $0` [--simulator]"
  exit 1
fi

if [ "$TARGET" = "simulator" ]; then
  OPENSSL_TARGET=iossimulator-xcrun
  OPENDDS_TARGET=SIMULATOR
  XCODE_ARCH=x86_64
  XCODE_SDK=$XCODE/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk
else
  OPENSSL_TARGET=ios64-xcrun
  OPENDDS_TARGET=HARDWARE
  XCODE_ARCH=arm64
  XCODE_SDK=$XCODE/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk
fi

function check_xerces {
  status=0
  if [ -r $MIDDLEWARE/ios-xerces/lib/libxerces-c.a ]; then
    pushd $TMPDIR
    file=PosixFileMgr.cpp.o
    tar xf $MIDDLEWARE/ios-xerces/lib/libxerces-c.a $file
    if [ -n "`file $file 2> /dev/null | grep $XCODE_ARCH`" ]; then
      status=1
    fi
    rm -f $file
    popd
  fi
  return $status
}

## Download the source archives
if [ ! -r $OPENSSL.tar.gz ]; then
  curl -o $OPENSSL.tar.gz https://www.openssl.org/source/$OPENSSL.tar.gz
  FORCE_OPENSSL=1
fi
if [ ! -r $XERCES.tar.gz ]; then
  curl -o $XERCES.tar.gz https://dlcdn.apache.org/xerces/c/3/sources/$XERCES.tar.gz
  FORCE_XERCES=1
fi

mkdir -p $TARGET
cd $TARGET

if [ $? -eq 0 ]; then
  mkdir -p $MIDDLEWARE

  if [ -n "$FORCE_OPENSSL" -o -z "`file $MIDDLEWARE/ios-openssl/lib/libcrypto.dylib 2> /dev/null | grep $XCODE_ARCH`" ]; then
    ## Build OpenSSL
    if [ ! -r $OPENSSL/Configure ]; then
      tar xzf ../$OPENSSL.tar.gz
    fi
    cd $OPENSSL
    if [ ! -r Makefile ]; then
      ./Configure $OPENSSL_TARGET
    fi
    make && make install DESTDIR=$MIDDLEWARE/ios-openssl
    pushd $MIDDLEWARE/ios-openssl
    rm -rf bin include lib share ssl
    mv usr/local/* .
    rm -rf usr lib/*.dylib
    popd
    cd ..
  fi

  check_xerces
  if [ -n "$FORCE_XERCES" -o $? -eq 0 ]; then
    ## Build xerces
    if [ ! -r $XERCES/CMakeLists.txt ]; then
      tar xzf ../$XERCES.tar.gz
    fi
    cd $XERCES
    export CC="$XCODE_BIN/clang -miphoneos-version-min=12.0 -arch $XCODE_ARCH"
    export CXX="$XCODE_BIN/clang++ -miphoneos-version-min=12.0 -arch $XCODE_ARCH"
    cmake . -DBUILD_SHARED_LIBS:BOOL=OFF -Dnetwork:BOOL=OFF -Dtranscoder=iconv \
          -DCMAKE_INSTALL_PREFIX=$MIDDLEWARE/ios-xerces \
          -DCMAKE_OSX_SYSROOT=$XCODE_SDK -DCMAKE_C_COMPILER_WORKS=1 \
          -DCMAKE_CXX_COMPILER_WORKS=1
    make && make install
    cd ..
  fi

  ## Build OpenDDS
  if [ -r ios-opendds/dds/Version.h ]; then
    cd ios-opendds
    git pull
    make depend > /dev/null 2>&1 &
  else
    git clone --depth=1 -b $OPENDDS_BRANCH $OPENDDS_GIT_REPO ios-opendds
    cd ios-opendds
    ./configure --ace-github-latest --security --target=ios \
      --macros=IPHONE_TARGET=$OPENDDS_TARGET \
      --openssl=$MIDDLEWARE/ios-openssl \
      --xerces3=$MIDDLEWARE/ios-xerces
  fi
  ## Building the smartlock_idl_plugin with ACE_HAS_CPP11 defined causes
  ## the app to crash during initialization.
  ACE_CONFIG=build/target/ACE_TAO/ACE/ace/config.h
  if [ -z "`grep ACE_HAS_CPP11 $ACE_CONFIG`" ]; then
    echo '#undef ACE_HAS_CPP11' >> $ACE_CONFIG
  fi
  make

  ## Install ACE/TAO/OpenDDS
  rm -rf $MIDDLEWARE/ACE_TAO $MIDDLEWARE/OpenDDS
  . build/target/setenv.sh
  cd $ACE_ROOT/ace
  make INSTALL_PREFIX=$MIDDLEWARE/ACE_TAO install
  cd $TAO_ROOT/tao
  make INSTALL_PREFIX=$MIDDLEWARE/ACE_TAO install
  cd $DDS_ROOT/dds
  make INSTALL_PREFIX=$MIDDLEWARE/OpenDDS install

  ## Build the IDL
  cd $SMARTLOCK_DIR/flutter/Idl
  $ACE_ROOT/bin/mwc.pl -type gnuace
  make clean all
fi
