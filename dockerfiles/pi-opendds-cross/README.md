### About

This docker image provides a build environment which enables cross-compiling OpenDDS
applications for the Raspberry Pi.

### Build the image

Building the image downloads and compiles OpenDDS, OpenSSL, Xerces, and WiringPi.
It then creates tarballs of each, which can be copied to the Raspberry Pi and ex-
tracted into the home directory to enable the SmartLock service (see run notes).

`docker build -t pi-opendds .`

### Compiling SmartLock within the container

By default, running the docker image will simply drop the user into a bash shell,
allowing them to cross-compile OpenDDS applications for the Raspberry Pi.

The typical scenario includes bind-mounting the source directory to some directory
under /home/pi when invoking the container. Then, compile the application, create a
tarball the result, copy and extract this tarball along with the system-created tarballs.

For example, launch the container from the SmartLock repository root directory
on the host system:

```bash
cd src
docker run --rm -ti -v "$PWD":/home/pi/smartlock pi-opendds
```

Inside the container build the app using the OpenDDS framework:

```bash
source /home/pi/pi-opendds/build/target/setenv.sh
cd /home/pi/smartlock
mwc.pl -type gnuace -features 'no_wiring_pi=0'
make
```

### Copy binaries and dependencies to the Raspbery Pi

Since the dependencies are already created as part of the image-creation process,
simply copy them to the Raspberry Pi using scp. Here we assume `PI_IP` is set to
the IP address of the target Raspberry Pi.

```bash
PI_IP=xxx.xxx.xxx.xxx
```

```bash
cd /home/pi
tar -cvzf smartlock.tar.gz smartlock
scp smartlock.tar.gz pi-opendds.tar.gz pi-openssl.tar.gz pi-xerces.tar.gz pi@${PI_IP}:
```

For quicker development turnover consider copying the dependencies as usual and then use `rsync` instead of a tarball for the SmartLock app.

```bash
rsync -avz -e "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" /home/pi/smartlock pi@${PI_IP}:
```

### Set up and run the smartlock service

```bash
# TODO
```
