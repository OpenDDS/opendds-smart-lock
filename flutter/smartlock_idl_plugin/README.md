# smartlock_idl_plugin

A Flutter FFI plugin for the SmartLock IDL library.

## Requirements

* LLVM
* Docker or Podman to build the Android toolchain and SmartLock Idl project.

## Project Structure

* The C/C++ source code is under the `src` directory.
  * Run this command in the `smartlock_idl_plugin` directory if the source header changes:
  * `flutter pub run ffigen --config ffigen.yaml`
* The Flutter binding is under the `lib` directory.
* The external libraries are placed in a directory corresponding to the architecture under the `android/src/main/jniLibs` directory.

## Build Preparation
Set your `ACE_ROOT`, `TAO_ROOT`, and `DDS_ROOT` environment variables to the
directories from which the external libraries were built.  These variables
and the directories to which they point must be accessible by Android Studio.

Run the build script in the `opendds-smart-lock` directory to get copies of the
Android toolchain and SmartLock Idl libraries.

```shell
smart-lock android build-toolchain-x86
smart-lock android compile
```

This plugin requires the following libraries.

```shell
libACE.so
libACE_XML_Utils.so
libc++_shared.so
libOpenDDS_Dcps.so
libOpenDDS_Rtps.so
libOpenDDS_Security.so
libSmartLock_Idl_Java.so
libTAO.so
libTAO_AnyTypeCode.so
libTAO_BiDirGIOP.so
libTAO_CodecFactory.so
libTAO_PI.so
libTAO_PortableServer.so
libTAO_Valuetype.so
libxerces-c-3.2.so
```
