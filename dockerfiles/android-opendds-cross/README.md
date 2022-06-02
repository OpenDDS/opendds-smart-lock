### About

This docker image provides a build environment which enables cross-compiling OpenDDS
applications for Android.

### Build the image

Building the image downloads and compiles OpenDDS, OpenSSL, Xerces and then copies any libraries required by Android in /home/droid/libs.

For arm64-v8a Android 11 run

`docker build -t android-opendds .`

For arm Android 11 run

`docker build --build-arg ABI=armeabi-v7a --build-arg ABI_PREFIX=armv7a-linux-androideabi --build-arg RUNTIME_ROOT=arm-linux-androideabi --build-arg PLATFORM=android-arm -t android-opendds .`

For x86 Android 11 run

`docker build --build-arg ABI=x86 --build-arg ABI_PREFIX=i686-linux-android --build-arg PLATFORM=android-x86 -t android-opendds .`


### Compiling SmartLock within the container

By default, running the docker image will simply drop the user into a bash shell,
allowing them to cross-compile OpenDDS applications for Android (in this case SmartLock).

The typical scenario includes bind-mounting the source directory to some directory
under /home/droid when invoking the container. Then, compile the application, and copy the resultant JAR file/shared object combo, along with the /home/droid/libs contents onto the host android directory.

For example, launch the container from the SmartLock repository root directory
on the host system:

```bash
docker run --rm -ti -v "$PWD":/home/droid/smartlock android-opendds
```

Inside the container build the app using the OpenDDS framework:

```bash
APP_MPC_NAME=SmartLock_Idl_Java
APP_NAME=SmartLock
DDS_ROOT=/home/droid/droid-opendds
source $DDS_ROOT/build/target/setenv.sh
cd $HOME/smartlock/android/Idl
mwc.pl -type gnuace
make -f GNUmakefile.${APP_MPC_NAME} ${APP_NAME}TypeSupportJC.h && \
        make && \
        $DDS_ROOT/java/build_scripts/javac_wrapper.pl \
          -sourcepath . \
          -d classes \
          -classpath . \
          -implicit:none \
          -classpath $DDS_ROOT/lib/i2jrt_compact.jar \
          -classpath $DDS_ROOT/lib/i2jrt.jar \
          -classpath $DDS_ROOT/lib/OpenDDS_DCPS.jar \
          ${APP_NAME}/*;
```

### Copy dependencies into Android Studio and launch

```bash
cp $HOME/libs/*.jar $HOME/smartlock/android/Idl/*.jar $HOME/smartlock/android/SmartLock/app/libs
mkdir $HOME/smartlock/android/SmartLock/app/native_libs/arm64-v8a
cp $HOME/libs/*.so $HOME/smartlock/android/Idl/*.so $HOME/smartlock/android/SmartLock/app/native_libs/arm64-v8a
```

On the host system, launch Android Studio and open the SmartLock project within
android/SmartLock.
