CrossPack for AVR Development is a development environment for Atmel's AVR
microcontrollers running on Apple's OS X, similar to AVR Studio on Windows.
It consists of the GNU compiler suite, a C library for the AVR, the AVRDUDE
downloader and several other useful tools.

This repository contains a shell script which downloads the source code of
all required packages, compiles them, builds an installer package and wraps
it into a disk image, ready for distribution. It also contains resources such
as a project template, manual etc.

The repository maintained by obdev seems to be dead, so this repository aims to
update the shell script to work on macOS 10.15.

PREREQUISITES
=============

* Xcode 5 or newer versions.
* Mac OS 10.9 or later.


BUILDING CROSSPACK-AVR
======================

After installing Xcode, simply run

    sudo ./mkdist.sh

or

    sudo ./mkdist.sh debug

in the root directory of the project. You may want to edit some options in
the script before running it, e.g. the version of CrossPack-AVR or versions
of packages downloaded and compiled. The user who runs the script needs write
permissions to the directory /usr/local.

The resulting disk image can be found in /tmp.

The build procedure preserves all downloaded packages. If you want to remove
them in order to save disk space, run

    sudo ./mkclean.sh

