
### Build notes

Building the image pulls down OpenDDS, OpenSSL, and Xerces; compiles them; and
packages them into tarballs which can then be copied to the target Raspberry Pi
manually (using scp or something similar).

`docker build -t pi-opendds .`

### Run notes

Before running this change into the a directory that you would like to have the
cross-compiled tarballs install into.

Run this command to copy the tarballs onto the host machine:

On Windows:
`docker run --rm -v "%cd%":/home/pi/dst pi-opendds`

On Unix:
`docker run --rm -v "$(pwd)":/home/pi/dst pi-opendds`
