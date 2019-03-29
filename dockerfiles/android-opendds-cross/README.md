### About

This docker image provides a build environment which enables cross-compiling OpenDDS
applications for Android.

### Build the image

Building the image downloads and compiles OpenDDS, OpenSSL, Xerces and then copies any libraries required by Android in /home/droid/libs.

`docker build -t android-opendds .`

### Compiling SmartLock within the container

By default, running the docker image will simply drop the user into a bash shell,
allowing them to cross-compile OpenDDS applications for Android (in this case SmartLock).

The typical scenario includes bind-mounting the source directory to some directory
under /home/droid when invoking the container. Then, compile the application, and copy the resultant JAR file/shared object combo, along with the /home/droid/libs contents onto the host android directory.

For example, launch the container from the SmartLock repository root directory
on the host system:

```bash
docker run --rm -ti -v "$PWD":/home/pi/smartlock android-opendds
```

Inside the container build the app using the OpenDDS framework:

```bash
APP_MPC_NAME=SmartLock_Idl_Java
APP_NAME=SmartLock
DDS_ROOT=/home/droid/droid-opendds
source /home/droid/droid-opendds/build/target/setenv.sh
cd /home/droid/smartlock/android/Idl
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
make
```

### Copy dependencies into Android Studio project

```bash
#TODO
```
