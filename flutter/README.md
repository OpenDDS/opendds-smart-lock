# Getting Started

Set your FLUTTER_ROOT environment to the full path of the Flutter installation.

# Building for Android

Use the `smart-lock` script in the root of this repository to build the toolchain and idl project for the supported platforms.

```shell
./smart-lock android build-toolchain-arm64
./smart-lock android compile
./smart-lock android build-toolchain-x86
./smart-lock android compile
```
Once those are complete, you can build the Flutter app for android.

```shell
cd flutter/smartlock
flutter build apk --split-per-abi --release
```

The .apk files will be in `build/app/outputs/apk/release`.

# Building for iOS

This must be done on a mac and requires xcode.

## Building for the Simulator

Set the IOS_ARCH environtment variable to x86_64.

```shell
export IOS_ARCH=x86_64
```

Use the build script in the `ios` directory of the root directory of this repository to build the smartlock idl library and it's supporting libraries.

```shell
cd ios
./build.sh --simulator
```

Once this is complete, you can build and run the Flutter app on the iOS simulator.  Be sure that the iOS simulator is running before running these commands.  If you have built the app previously with a different `IOS_ARCH` environment variable value, you will want to run `flutter clean` before building.

```shell
cd flutter/smartlock
flutter run
```

## Building for the iPhone

Set the IOS_ARCH environtment variable to arm64.

```shell
export IOS_ARCH=x86_64
```

Use the build script in the `ios` directory of the root directory of this repository to build the smartlock idl library and it's supporting libraries.

```shell
cd ios
./build.sh
```

Once this is complete, you can build and run the Flutter app on an iPhone.  This will either require an Apple Developer account or that you have an iPhone connected to the build machine.  If you have built the app previously with a different `IOS_ARCH` environment variable value, you will want to run `flutter clean` before building.

To build an .ipa file, run these commands.

```shell
cd flutter/smartlock
flutter build ios
```

To run it directly on a connected iPhone, use these commands.

```shell
cd flutter/smartlock
flutter run
```

