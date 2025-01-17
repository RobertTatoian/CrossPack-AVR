#!/bin/sh
#
#  mkdist.sh
#  ____                                  ____                 __                ______  __  __  ____
# /\  _`\                               /\  _`\              /\ \              /\  _  \/\ \/\ \/\  _`\
# \ \ \/\_\  _ __   ___     ____    ____\ \ \L\ \ __      ___\ \ \/'\          \ \ \L\ \ \ \ \ \ \ \L\ \
#  \ \ \/_/_/\`'__\/ __`\  /',__\  /',__\\ \ ,__/'__`\   /'___\ \ , <    _______\ \  __ \ \ \ \ \ \ ,  /
#   \ \ \L\ \ \ \//\ \L\ \/\__, `\/\__, `\\ \ \/\ \L\.\_/\ \__/\ \ \\`\ /\______\\ \ \/\ \ \ \_/ \ \ \\ \
#    \ \____/\ \_\\ \____/\/\____/\/\____/ \ \_\ \__/.\_\ \____\\ \_\ \_\/______/ \ \_\ \_\ `\___/\ \_\ \_\
#     \/___/  \/_/ \/___/  \/___/  \/___/   \/_/\/__/\/_/\/____/ \/_/\/_/          \/_/\/_/`\/__/  \/_/\/ /

#  Created by Christian Starkjohann on 2012-11-28.
#  Copyright (c) 2012 Objective Development Software GmbH.

# Package name and version number
pkgUnixName=CrossPack-AVR
pkgPrettyName="CrossPack for AVR Development"
pkgUrlName=crosspack    # name used for http://www.obdev.at/$pkgUrlName
pkgUpdateMonth=02
pkgUpdateDay=10
pkgUpdateYear=2017
pkgVersion=$pkgUpdateYear$pkgUpdateMonth$pkgUpdateDay

# Clear the terminal screen
clear

echo " #####                              ######                                #    #     # ######"
echo "#     # #####   ####   ####   ####  #     #   ##    ####  #    #         # #   #     # #     #"
echo "#       #    # #    # #      #      #     #  #  #  #    # #   #         #   #  #     # #     #"
echo "#       #    # #    #  ####   ####  ######  #    # #      ####   ##### #     # #     # ######"
echo "#       #####  #    #      #      # #       ###### #      #  #         #######  #   #  #   #"
echo "#     # #   #  #    # #    # #    # #       #    # #    # #   #        #     #   # #   #    #"
echo " #####  #    #  ####   ####   ####  #       #    #  ####  #    #       #     #    #    #     #"
echo "                        +-+-+-+-+-+-+-+ +-+-+-+-+-+ +-+-+-+-+-+-+-+"
echo "                        |P|a|c|k|a|g|e| |B|u|i|l|d| |U|t|i|l|i|t|y|"
echo "                        +-+-+-+-+-+-+-+ +-+-+-+-+-+ +-+-+-+-+-+-+-+"
echo "Version: $pkgVersion"
echo "Last Updated: $pkgUpdateMonth/$pkgUpdateDay/$pkgUpdateYear"
echo "GitHub URL:"

# Versions current as of 11/09/19
# MARK: Core build dependencies
version_binutils=2.33.1
version_gcc=9.2.0
version_avrlibc=2.0.0

# MARK: Optional build dependencies
version_avrdude=6.3
version_gdb=8.3.1
version_avarice=2.13
version_simulavr=1.0.0

# MARK: GCC build dependencies
version_gmp=6.1.2
version_mpfr=4.0.2
version_mpc=1.1.0

# MARK: Other build dependencies
version_automake=1.15
version_autoconf=2.68
version_ppl=0.12.1
version_cloog=0.16.2
version_libusb=1.0.23
version_swig=1.3.40		# The latest version is: 4.0.1, but simulavr requires 1.3.xx.


debug=false
if [ "$1" = debug ]; then
    debug=true
fi

# Set the path to the installation directory.
prefix="/usr/local/$pkgUnixName-$pkgVersion"
configureArgs="--disable-dependency-tracking --disable-nls --disable-werror"

umask 0022

# Set the path to the macOS SDK.
xcodepath="$(xcode-select -print-path)"
sysroot="$xcodepath/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"

# Do not include original PATH in our PATH to ensure that third party stuff is not found
PATH="$prefix:$prefix/bin:$xcodepath/usr/bin:$xcodepath/Toolchains/XcodeDefault.xctoolchain/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin"
export PATH

# Commonly used flags when building various tools.
# macOS 10.9 is needed to build binutils

commonCFLAGS="-isysroot $sysroot -mmacosx-version-min=10.9"

# Build libraries for i386 and x86_64, but executables i386 only so that the
# size of the distribution is not unecessary large.

# Only x86_64 is supported on 10.15 and later, using x86_64 should not affect
# compatibility with 10.9.
buildCFLAGS="$commonCFLAGS -arch x86_64 -fno-stack-protector"  # used for tool chain

# Why -fno-stack-protector? Gcc 4.7.2 compiled with Xcode 5 aborts with a stack
# protection failure when building libgcc for avrtiny. The problem occurs with -O2
# only, not with -O0. It's hard to debug with the heavy inlining of -O2. Since
# there is no obvious overflow, this is maybe a bug in clang's stack protector.
# In any case, we are not responsible for debugging either of the two compilers,
# so we simply disable the check.



###############################################################################
# Check prerequisites first
###############################################################################

# Check that the release notes have been updated, if this is a release build.
releaseNotesVersion=$(sed -n -e '/20[01234][0-9][01][0-9][0-3][0-9]<[/]h/ s/^.*\([0-9]\{8\}\).*$/\1/g p' manual-source/releasenotes.html | head -1)
if ! $debug; then
    if [ "$releaseNotesVersion" != "$pkgVersion" ]; then
        echo "*** Release notes not up-to-date!"
        echo "Latest release notes are for version $releaseNotesVersion, package version is $pkgVersion"
        exit 1
    fi
fi

###############################################################################
# Obtaining the packages from the net
###############################################################################

###############################################
#Function Name: getPackage
#Arguments: <url> <alwaysDownload> <package-name>
#
#Description: Download a package and unpack it.
#MARK: getPackage
###############################################
getPackage()
{
	# Set the URL and use basename to get the filename of the package.
    url="$1"
    package=$(basename "$url")
    
    # No idea what this does
    [ "$3" ] && package="$3"
    
    # Check if we want to download the package.
    doDownload=no
    if [ ! -f "packages/$package" ]; then
        doDownload=yes		# not yet downloaded.
    elif ! $debug; then
        if [ "$2" = alwaysDownload ]; then
            doDownload=yes	# release build and download forced.
        fi
    fi
	
	# Download the package if we need to.
    if [ "$doDownload" = yes ]; then
        echo "=== Downloading package $package"
        rm -f "packages/$package"	# Clean out any existing package.
        curl --location --progress-bar -o "packages/$package" "$url"
        if [ $? -ne 0 ] || file "packages/$package" | grep -q HTML; then
            echo "################################################################################"
            echo "Failed to download $url"
            echo "################################################################################"
            rm -f "packages/$package"
            exit 1
        fi
    fi
}


###############################################################################
# helper for building fat libraries
###############################################################################


###############################################
#Function Name: lipoHelper
#Arguments: <action> <file>
#
#Description:
#MARK: lipoHelper
###############################################
#TODO: Check x86_64 compatibility.
#TODO: Write function description.
lipoHelper()
{
    action="$1"
    file="$2"
    if [ "$action" = rename ]; then
        if echo "$file" | egrep '\.(i386|x86_64)$' >/dev/null; then
            : # already renamed
        elif arch=$(lipo -info "$file" 2>/dev/null); then # true if lipo is applicable
            arch=$(echo $arch | sed -e 's/^.*: \([^:]*\)$/\1/g')
            case "$arch" in
            x86_64|i386)
                mv "$file" "$file.$arch";;
            esac
        fi
    elif [ "$action" = merge ]; then
        base=$(echo "$file" | sed -E -e 's/[.](i386|x86_64)$//g')
        if [ ! -f "$base.x86_64" ]; then
            mv -f "$base.i386" "$base"
        elif [ ! -f "$base.i386" ]; then
            mv -f "$base.x86_64" "$base"
        elif lipo -create -arch i386 "$base.i386" -arch x86_64 "$base.x86_64" -output "$base"; then
            rm -f "$base.i386" "$base.x86_64"
        fi
    else
        echo "Invalid action $1"
    fi
}

###############################################
#Function Name: lipoHelper
#Arguments: <action> <baseDir>
#
#Description:
#MARK: lipoHelper
###############################################
#TODO: Check x86_64 compatibility.
#TODO: Write function description.
lipoHelperRecursive()
{
    action="$1"
    baseDir="$2"
    if [ "$action" = "rename" ]; then
        find "$baseDir" -type f -and '(' -name '*.a' -or -name '*.dylib*' -or -name '*.so*' -or -perm -u+x ')' -print | while read i; do
            lipoHelper "$action" "$i"
        done
    else
        find "$baseDir" -type f -and -name '*.i386' -print | while read i; do
            lipoHelper "$action" "$i"
        done
    fi
}


###############################################################################
# building the packages
###############################################################################

###############################################
#Function Name: checkreturn
#Arguments:
#
#Description: checkreturn is used to check for exit status of subshell
#MARK: checkreturn
###############################################
checkreturn()
{
	rval="$?"
	if [ "$rval" != 0 ]; then
		exit "$rval"
	fi
}

###############################################
#Function Name: applyPatches
#Arguments: <package-name>
#
#Description:
#MARK: applyPatches
###############################################
applyPatches()
{
    name="$1"
    base=$(echo "$name" | sed -e 's/-[.0-9]\{1,\}$//g')
    for patchdir in patches-local; do
        for target in "$base" "$name"; do
            if [ -d "$patchdir/$target" ]; then
                echo "=== applying patches from $patchdir/$target"
                (
                    cd "compile/$name"
                    for patch in "../../$patchdir/$target/"*; do
                        if [ "$patch" != "../$patchdir/$target/*" ]; then
                            echo "    -" "$(basename "$patch")"
                            if ! patch --silent -f -p0 < "$patch"; then
                                echo "Patch $patch failed!"
                                echo "Press enter to continue anyway"
                                read
                            fi
                        fi
                    done
                )
            fi
        done
    done
}

###############################################
#Function Name: unpackPackage
#Arguments: <package-name>
#
#Description:
#MARK: unpackPackage
###############################################
unpackPackage() # <package-name>
{
    name="$1"
    archive=$(ls "packages/$name"* | grep -E "$name\..+$")    # wildcard expands to compression extension
    extension=$(echo "$archive" | awk -F . '{print $NF}')
    zipOption="-z"
    if [ "$extension" = "bz2" ]; then
        zipOption="-j"
    fi
    if [ ! -d compile ]; then
        mkdir compile
    fi
    echo "=== unpacking $name"
    rm -rf "compile/$name"
    mkdir "compile/tmp"
    if [ "$extension" = "zip" ]; then
        unzip -d compile/tmp "$archive"
    else
        tar -x $zipOption -C compile/tmp -f "$archive"
    fi
    mv compile/tmp/* "compile/$name"
    rm -rf compile/tmp
    if [ ! -d "compile/$name" ]; then
        echo "*** Package $name does not contain expected directory"
        exit 1
    fi
    dir=$(echo "compile/$name/"*)
    if [ $(echo "$dir" | wc -w) = 1 ]; then     # package contains single dir
        mv "$dir"/* "compile/$name"             # move everything up one level
        rm -rf "$dir"
    fi
}

###############################################
#Function Name: buildPackage
#Arguments: <package-name> <known-product> <additional-config-args...>
#
#Description:
#MARK: buildPackage
###############################################
buildPackage()
{
    name="$1"
    product="$2"
    if [ -f "$product" ]; then
        echo "Skipping build of $name because it's already built"
        return  # the product we generate exists already
    fi
    shift; shift
	
	echo "*═══════════════════════════════════════════════════════*"
	echo "║Started building $name at $(date +"%Y-%m-%d %H:%M:%S")"
	echo "*═══════════════════════════════════════════════════════*"
	
    cwd=$(pwd)
	base=$(echo "$name" | sed -e 's/-[.0-9]\{1,\}$//g')
    version=$(echo "$name" | sed -e 's/^.*-\([.0-9]\{1,\}\)$/\1/')
    unpackPackage "$name"
    applyPatches "$name"
    (
        cd "compile/$name"
        
        if [ "$name" = "libusb-compat-0.1" ]; then
			echo $PATH
			echo "Current package is libusb-compat-0.1, execute autogen.sh"
			./autogen.sh
        fi
        
        if [ "$base" = gcc ]; then
            # manually clean dependent files, these are not always removed by make distclean
            grep -RiIn --exclude-dir zlib 'generated automatically by' . | tr ':' ' ' | while read file line rest; do
                if [ "$line" -lt 4 ]; then
                    echo "removing dependent file $file"
                    rm "$file"
                fi
            done
        fi
        
        if [ "$base" = gcc -o "$base" = simulavr ]; then    # build gcc in separate dir, it will fail otherwise
            mkdir build-objects
            rm -rf build-objects/*
            cd build-objects
            rootdir=..
        else
            rootdir=.
        fi
        
        if [ "$base" != avr-libc ]; then
            export CC="xcrun gcc $buildCFLAGS"
            export CXX="xcrun g++ $buildCFLAGS"
        fi
        
        make distclean 2>/dev/null
        
        echo "cwd=`pwd`"
        echo "$PATH"
        if [ "$base" = avrdude ]; then
			echo "Configuring AVRDUDE with libusb support"
			echo $rootdir/configure --prefix="$prefix" $configureArgs "$@"
			$rootdir/configure --prefix="$prefix" $configureArgs CFLAGS="-I$prefix/include/libusb-1.0 -I$prefix/include" LDFLAGS="-L$prefix/lib" LIBS="-lusb-1.0 -lobjc -framework IOKit -framework CoreFoundation" || exit 1
		elif [ "$base" = libusb-compat ]; then
			echo "Configuring libusb-compat"
			echo $rootdir/configure --prefix="$prefix" $configureArgs PKG_CONFIG_PATH=$prefix/lib/pkgconfig "$@"
			$rootdir/configure --prefix="$prefix" $configureArgs PKG_CONFIG_PATH=$prefix/lib/pkgconfig "$@" || exit 1
		else
			echo $rootdir/configure --prefix="$prefix" $configureArgs "$@"
			$rootdir/configure --prefix="$prefix" $configureArgs "$@" || exit 1
		fi
		
		
		
        if ! make; then
			echo "*═══════════════════════════════════════════════════════*"
			echo "║Building $name failed at $(date +"%Y-%m-%d %H:%M:%S")"
			echo "*═══════════════════════════════════════════════════════*"
            exit 1
        fi
		
		echo "*═══════════════════════════════════════════════════════*"
		echo "║Finished building $name at $(date +"%Y-%m-%d %H:%M:%S")"
		echo "*═══════════════════════════════════════════════════════*"
		
        make install || exit 1
        
        case "$product" in
            "$cwd"/*)   # install destination is in source tree -> do nothing
                echo "package $name is not part of distribution"
                ;;
            *)          # install destination is not in source tree
                mkdir "$prefix" 2>/dev/null
                mkdir "$prefix/etc" 2>/dev/null
                mkdir "$prefix/etc/versions.d" 2>/dev/null
                echo "$base: $version" >"$prefix/etc/versions.d/$base"
                ;;
        esac
        
		echo "*═══════════════════════════════════════════════════════*"
		echo "║Finished installing $name at $(date +"%Y-%m-%d %H:%M:%S")"
		echo "*═══════════════════════════════════════════════════════*"
		
    )
    checkreturn
}

###############################################
#Function Name: copyPackage
#Arguments: <package-name> <destination>
#
#Description:
#MARK: copyPackage
###############################################
copyPackage()
{
    name="$1"
    destination="$2"
    unpackPackage "$name"
    mkdir -p "$destination" 2>/dev/null
    echo "=== installing files in $name"
    mv "compile/$name/"* "$destination/"
    chmod -R a+rX "$destination"
}

###############################################################################
# Main Code
# MARK: Main Code
###############################################################################

if [ -d "$prefix" -a ! -w "$prefix" -a -x "$prefix/uninstall" ]; then
    echo "Please type your password so that we can run uninstall as root:"
    if ! sudo "$prefix/uninstall"; then
        echo "Aborting because uninstall failed"
        exit 1
    fi
fi

if [[ $(id -u) != 0 ]]; then
	echo "Please type your password so that we can run as root.\n"
	exit 1
fi

# If we're in release, clean up these directories before continuing.
if ! "$debug"; then
    rm -rf "$installdir"
    rm -rf compile
    rm -rf "$prefix"
fi

# Create the package directory if not there.
if [ ! -d packages ]; then
    mkdir packages
fi

echo "*═══════════════════════════════════════════════════════*"
echo "║Starting downloads at: $(date +"%Y-%m-%d %H:%M:%S")"
echo "*═══════════════════════════════════════════════════════*"

#getPackage https://ftp.gnu.org/gnu/automake/automake-"$version_automake".tar.gz
#getPackage https://ftp.gnu.org/gnu/autoconf/autoconf-"$version_autoconf".tar.gz

#getPackage http://downloads.sourceforge.net/project/libusb/libusb-compat-0.1/libusb-compat-"$version_libusb_compat"/libusb-compat-"$version_libusb_compat".tar.bz2

# Commonly used URLs
gnuBaseURL="https://ftp.gnu.org/gnu"
savannahBaseURL="http://download.savannah.gnu.org/releases"
sourceforgeBaseURL="https://sourceforge.net/projects"

# MARK: Core Tools.
# The core tools required are binutils, GCC, and AVR LibC.
getPackage "$gnuBaseURL/binutils/binutils-$version_binutils.tar.xz"
getPackage "$gnuBaseURL/gcc/gcc-$version_gcc/gcc-$version_gcc.tar.gz"
getPackage "$savannahBaseURL/avr-libc/avr-libc-$version_avrlibc.tar.bz2"

# MARK: GCC Dependencies
# Required to build the GCC
getPackage "$gnuBaseURL/gmp/gmp-$version_gmp.tar.xz"
getPackage "$gnuBaseURL/mpc/mpc-$version_mpc.tar.gz"
getPackage "$gnuBaseURL/mpfr/mpfr-$version_mpfr.tar.gz"

# MARK: Optional Tools
# Optional tools are AVRDUDE, GDB, SimulAVR, and AVaRICE.
getPackage "$savannahBaseURL/avrdude/avrdude-$version_avrdude.tar.gz"
getPackage "$gnuBaseURL/gdb/gdb-$version_gdb.tar.xz"
getPackage "$savannahBaseURL/simulavr/simulavr-$version_simulavr.tar.gz"
getPackage "$sourceforgeBaseURL/avarice/files/avarice/avarice-$version_avarice/avarice-$version_avarice.tar.bz2"

# MARK: Other dependencies
# Other dependencies
getPackage "https://github.com/libusb/libusb/releases/download/v$version_libusb/libusb-$version_libusb.tar.bz2"
getPackage "https://github.com/libusb/libusb-compat-0.1/archive/master.zip"
getPackage "$sourceforgeBaseURL/swig/files/swig/swig-$version_swig/swig-$version_swig.tar.gz"

# MARK: Documentation
getPackage "$savannahBaseURL/avrdude/avrdude-doc-$version_avrdude.tar.gz"
getPackage "$savannahBaseURL/avr-libc/avr-libc-manpages-$version_avrlibc.tar.bz2"
getPackage "$savannahBaseURL/avr-libc/avr-libc-user-manual-$version_avrlibc.tar.bz2"

echo "*═══════════════════════════════════════════════════════*"
echo "║Finished downloads at: $(date +"%Y-%m-%d %H:%M:%S")"
echo "*═══════════════════════════════════════════════════════*"

installdir="$(pwd)/temporary-install"
if [ ! -d "$installdir" ]; then
    mkdir "$installdir"
fi

# Rename libusb-compat
if [ -f "$(pwd)/packages/master.zip" ]; then
	cp "$(pwd)/packages/master.zip" "$(pwd)/packages/libusb-compat-0.1.zip"
fi

#########################################################################
# Build sources
#########################################################################
echo "*═══════════════════════════════════════════════════════*"
echo "║Started building packages at: $(date +"%Y-%m-%d %H:%M:%S")"
echo "*═══════════════════════════════════════════════════════*"

#########################################################################
# math and other prerequisites
#########################################################################
#export M4="xcrun m4"
#buildPackage autoconf-"$version_autoconf" "$installdir/autoconf/bin/autoconf" --prefix="$installdir/autoconf"
#unset M4
#export PATH="$installdir/autoconf/bin:$PATH"
#
#buildPackage automake-"$version_automake" "$installdir/automake/bin/automake" --prefix="$installdir/automake"
#export PATH="$installdir/automake/bin:$PATH"

#########################################################################
# GMP, MPFR, and MPC binaries needed for GCC.
# MARK: Build GCC Dependencies
#########################################################################
buildPackage gmp-"$version_gmp"   "$installdir/lib/libgmp.a"  --prefix="$installdir" --enable-cxx --enable-shared=no --disable-assembly
buildPackage mpfr-"$version_mpfr" "$installdir/lib/libmpfr.a" --with-gmp="$installdir" --prefix="$installdir" --enable-shared=no
buildPackage mpc-"$version_mpc"   "$installdir/lib/libmpc.a"  --with-gmp="$installdir" --with-mpfr="$installdir" --prefix="$installdir" --enable-shared=no

rm -f "$installdir/lib/"*.dylib # ensure we have no shared libs

#########################################################################
# libusb needed for AVRDUDE
# MARK: Build libusb
#########################################################################
(
	buildCFLAGS="$commonCFLAGS -arch x86_64"
	
	buildPackage libusb-"$version_libusb" "$prefix/lib/libusb-1.0.a" --disable-shared
#	export LIBUSB_1_0_CFLAGS="-I$prefix/include/libusb-1.0"
#	export LIBUSB_1_0_LIBS="-lusb"
	
	buildPackage libusb-compat-0.1 "$prefix/lib/libusb.a" --disable-shared
	
	rm -f "$prefix/lib"/libusb*.dylib
	
	for file in "$prefix/lib"/libusb*.a; do
		if [ "$file" != "$prefix/lib"/libusb*.a ]; then
			lipoHelper rename "$file"
		fi
	done
)
checkreturn

#########################################################################
# binutils and prerequisites
# MARK: Build binutils
#########################################################################
buildPackage binutils-"$version_binutils" "$prefix/bin/avr-nm" --target=avr

if [ ! -f "$prefix/bfd/lib/libbfd.a" ]; then
    mkdir -p "$prefix/bfd/include"  # copy bfd directory manually
    mkdir "$prefix/bfd/lib"
    cp compile/binutils-"$version_binutils"/bfd/libbfd.a "$prefix/bfd/lib/"
    cp compile/binutils-"$version_binutils"/bfd/bfd.h "$prefix/bfd/include/"
    cp compile/binutils-"$version_binutils"/bfd/bfd_stdint.h "$prefix/bfd/include/"
    cp compile/binutils-"$version_binutils"/include/ansidecl.h "$prefix/bfd/include/"
    cp compile/binutils-"$version_binutils"/include/symcat.h "$prefix/bfd/include/"
    cp compile/binutils-"$version_binutils"/include/diagnostics.h "$prefix/bfd/include/"
fi

if [ ! -f "$prefix/lib/libiberty.a" ]; then
	if [ ! -d "$prefix/lib" ]; then
		mkdir "$prefix/lib"
    fi
    cp compile/binutils-"$version_binutils"/libiberty/libiberty.a "$prefix/lib/"
fi

#########################################################################
# gcc bootstrap
# MARK: Bootstrap GCC
#########################################################################
buildPackage gcc-"$version_gcc" "$prefix/bin/avr-g++" --target=avr --enable-languages=c,c++ --disable-libssp --disable-libada --with-dwarf2 --disable-shared --with-avrlibc=yes --with-gmp="$installdir" --with-mpfr="$installdir" --with-mpc="$installdir"

#########################################################################
# avr-libc
# MARK: Build AVR-LibC
#########################################################################
buildPackage avr-libc-"$version_avrlibc" "$prefix/avr/lib/libc.a" --host=avr --enable-device-lib
copyPackage avr-libc-user-manual-"$version_avrlibc" "$prefix/doc/avr-libc"
copyPackage avr-libc-manpages-"$version_avrlibc" "$prefix/man"

#########################################################################
# avr-gcc full build
# MARK: GCC with C & C++ Support
#########################################################################
#buildPackage gcc-"$version_gcc" "$prefix/bin/avr-g++" --target=avr --enable-languages=c,c++ --disable-libssp --disable-libada --with-dwarf2 --disable-shared --with-avrlibc=yes --with-gmp="$installdir" --with-mpfr="$installdir" --with-mpc="$installdir"


#########################################################################
# GDB
# MARK: Build GDB
#########################################################################
buildPackage gdb-"$version_gdb" "$prefix/bin/avr-gdb" --target=avr --without-python

#########################################################################
# AVaRICE
# MARK: Build AVaRICE
##########################################################################
#(
#    binutils="$(pwd)/compile/binutils-$version_binutils"
#    buildCFLAGS="$buildCFLAGS $("$prefix/bin/libusb-config" --cflags) -I$binutils/bfd -I$binutils/include -O"
#    export LDFLAGS="$LDFLAGS $("$prefix/bin/libusb-config" --libs) -L$binutils/bfd -lz -L$binutils/libiberty -liberty"
#    buildPackage avarice-"$version_avarice" "$prefix/bin/avarice"
#)
#checkreturn

#########################################################################
# SimulAVR
# MARK: Build SimulAVR
# FIXME: SimulAVR 1.0.0 does not build. Commenting out for now, will revisit at a later point.
#########################################################################
#(
#    export CFLAGS="-Wno-error -g -O2"
#    buildPackage simulavr-"$version_simulavr" "$prefix/bin/simulavr" --with-bfd="$prefix/bfd" --with-libiberty="$prefix" --disable-static --enable-dependency-tracking
#)
#checkreturn

#########################################################################
# AVRDUDE
# MARK: Build AVRDUDE
#########################################################################
(
    buildPackage avrdude-"$version_avrdude" "$prefix/bin/avrdude"
    
    copyPackage avrdude-doc-"$version_avrdude" "$prefix/doc/avrdude"
    if [ ! -f "$prefix/doc/avrdude/index.html" ]; then
        ln -s avrdude.html "$prefix/doc/avrdude/index.html"
    fi
)
checkreturn

#########################################################################
# ensure that we don't link anything local:
#########################################################################
libErrors=$(find "$prefix" -type f -perm +0100 -print | while read file; do
    locallibs=$(otool -L "$file" | tail -n +2 | grep '^/usr/local/')
    if [ -n "$locallibs" ]; then
        echo "*** $file uses local libraries:"
        echo "$locallibs"
    fi
done)

if [ -n "$libErrors" ]; then
    echo "################################################################################"
    echo "Aborting build due to above errors"
    echo "################################################################################"
    exit 1
fi

#########################################################################
# basic tests
#########################################################################
tmpfile="/tmp/test-$$.elf"
rm -rf "$tmpfile"
echo "int main(void) { return 0; }" | "$prefix/bin/avr-gcc" -x c -o "$tmpfile" -
if [ ! -f "$tmpfile" ]; then
    echo "################################################################################"
    echo "Aborting build because avr-gcc cannot compile C code"
    echo "################################################################################"
    exit 1
fi

rm -rf "$tmpfile"
echo "int main(void) { return 0; }" | "$prefix/bin/avr-gcc" -x c++ -o "$tmpfile" -
if [ ! -f "$tmpfile" ]; then
    echo "################################################################################"
    echo "Aborting build because avr-gcc cannot compile C++ code"
    echo "################################################################################"
    exit 1
fi
rm -f "$tmpfile"

for i in "$prefix/bin/"*; do
    case $(basename "$i") in
    avr-gcc-ar|avr-gcc-nm|avr-gcc-ranlib)
        ;;
    *)
        if [ "$(head -c 2 "$i")" != "#!" ]; then
            "$i" --help >/dev/null 2>&1
            rval=$?
            if [ "$rval" != 0 -a "$rval" != 1 ]; then   # Those executables which don't understand --help, exit with status 1
                echo "*** Cannot execute $i, rval=$rval"
                exit 1
            fi
        fi
        ;;
    esac
done

#########################################################################
# Create shell scripts and supporting files
#########################################################################
rm -f "$prefix/versions.txt"
cat "$prefix/etc/versions.d"/* >"$prefix/versions.txt"
echo "stripping all executables"
find "$prefix" -type f -perm -u+x -exec strip '{}' \; 2>/dev/null

# avr-man
cat >"$prefix/bin/avr-man" <<-EOF
	#!/bin/sh
	exec man -M "$prefix/man:$prefix/share/man" "\$@"
EOF
chmod a+x "$prefix/bin/avr-man"

# avr-info
cat >"$prefix/bin/avr-info" <<-EOF
	#!/bin/sh
	exec info -d "$prefix/share/info" "\$@"
EOF
chmod a+x "$prefix/bin/avr-info"

# avr-help
cat >"$prefix/bin/avr-help" <<-EOF
	#!/bin/sh
	exec open "$prefix/manual/index.html"
EOF
chmod a+x "$prefix/bin/avr-help"

# avr-gcc-select
cat > "$prefix/bin/avr-gcc-select" <<-EOF
	#!/bin/sh
	echo "avr-gcc-select is not supported any more."
	echo "This version of $pkgPrettyName comes with gcc 4 only."
	exit 0
EOF
chmod a+x "$prefix/bin/avr-gcc-select"

# uninstall script
cat >"$prefix/uninstall" <<-EOF
	#!/bin/sh
	if [ "\$1" != nocheck ]; then
		if [ "\$(whoami)" != root ]; then
			echo "\$0 must be run as root, use \\"sudo \$0\\""
			exit 1
		fi
	fi
	echo "Are you sure you want to uninstall $pkgPrettyName $pkgVersion?"
	echo "[y/N]"
	read answer
	if echo "\$answer" | egrep -i 'y|yes' >/dev/null; then
		echo "Starting uninstall."
		if cd "$prefix/.."; then
			rm -f "$pkgUnixName"
		fi
		rm -rf "$prefix"
        rm -rf "/etc/paths.d/50-at.obdev.$pkgUnixName"
		rm -f "/Applications/$pkgUnixName-Manual.html"
		rm -rf "/Library/Receipts/$pkgUnixName.pkg"
		echo "$pkgPrettyName is now removed."
	else
		echo "Uninstall aborted."
	fi
EOF
chmod a+x "$prefix/uninstall"

# avr-project
cat >"$prefix/bin/avr-project" <<-EOF
	#!/bin/sh
	if [ \$# != 1 ]; then
		echo "usage: \$0 <ProjectName>" 1>&2
		exit 1
	fi
	if [ "\$1" = "--help" -o "\$1" = "-h" ]; then
		{
			echo "This command creates an empty project with template files";
			echo
			echo "usage: \$0 <ProjectName>"
		} 1>&2
		exit 0;
	fi

	name=\$(basename "\$1")
	dir=\$(dirname "\$1")
	cd "\$dir"
	if [ -x "\$name" ]; then
		echo "An object named \$name already exists." 1>&2
		echo "Please delete this object and try again." 1>&2
		exit 1
	fi
	template=~/.$pkgUnixName/templates/TemplateProject
	if [ ! -d "\$template" ]; then
		template="$prefix/etc/templates/TemplateProject"
	fi
	echo "Using template: \$template"
	cp -R "\$template" "\$name" || exit 1
	cd "\$name" || exit 1
	mv TemplateProject.xcodeproj "\$name.xcodeproj"
EOF
chmod a+x "$prefix/bin/avr-project"

# templates
rm -rf "$prefix/etc/templates"
cp -R "templates" "$prefix/etc/"
(
	if cd "$prefix/etc/templates/TemplateProject/TemplateProject.xcodeproj"; then
		rm -rf *.mode1 *.pbxuser xcuserdata project.xcworkspace/xcuserdata
	fi
)

# manual
(
    cd manual-source
    ./mkmanual.sh "$prefix" "$pkgPrettyName"
)
rm -rf "$prefix/manual"
mv "manual" "$prefix/"


#########################################################################
# Mac OS X Package creation
# MARK: Package creation
#########################################################################

echo "Starting package creation at $(date +"%Y-%m-%d %H:%M:%S")"

# remove files which should not make it into the package
chmod -R a+rX "$prefix"
find "$prefix" -type f -name '.DS_Store' -exec rm -f '{}' \;
find "$prefix" -type f \( -name '*.i386' -or -name '*.x86_64' \) -print -exec rm -f '{}' \;

echo "=== Making Mac OS X Package"
pkgroot="/tmp/$pkgUnixName-root-$$"
rm -rf "$pkgroot"
mkdir "$pkgroot"
mkdir "$pkgroot/usr"
mkdir "$pkgroot/usr/local"

# Do not use cp -a below because it does not preserve hard links.
tar -C "$(dirname "$prefix")" -c -f - "$(basename "$prefix")" | tar -C "$pkgroot/usr/local" -x -f -

osxpkgtmp="/tmp/osxpkg-$$"
rm -rf "$osxpkgtmp"
cp -a package-info "$osxpkgtmp"
find "$osxpkgtmp" \( -name '*.plist' -or -name '*.rtf' -or -name '*.html' -or -name '*.txt' -or -name 'post*' \) -print | while read i; do
    echo "Running substitution on $i"
    cp "$i" "$i.tmp"	# create file with same permissions (is overwritten in next line)
    sed -e "s|%version%|$pkgVersion|g" -e "s|%pkgPrettyName%|$pkgPrettyName|g" -e "s|%prefix%|$prefix|g" -e "s|%pkgUnixName%|$pkgUnixName|g" -e "s|%pkgUrlName%|$pkgUrlName|g" "$i" > "$i.tmp"
    rm -f "$i"
    mv "$i.tmp" "$i"
done

echo "Building package..."

rm -rf "/tmp/$pkgUnixName-flat.pkg"
pkgbuild --identifier at.obdev.$pkgUnixName --scripts "$osxpkgtmp/scripts" --version "$pkgVersion" --install-location / --root "$pkgroot" "/tmp/$pkgUnixName-flat.pkg"
distfile="/tmp/$pkgUnixName-$$.dist"
cat >"$distfile" <<EOF
<?xml version="1.0" encoding="utf-8" standalone="no"?>
<installer-gui-script minSpecVersion="1">
    <title>$pkgPrettyName</title>
    <welcome file="Welcome.rtf" />
    <readme file="Readme.rtf" />
    <background file="background.jp2" scaling="proportional" alignment="center" />
    <pkg-ref id="at.obdev.$pkgUnixName"/>
    <options customize="never" require-scripts="false"/>
    <choices-outline>
        <line choice="default">
            <line choice="at.obdev.$pkgUnixName"/>
        </line>
    </choices-outline>
    <choice id="default"/>
    <choice id="at.obdev.$pkgUnixName" visible="false">
        <pkg-ref id="at.obdev.$pkgUnixName"/>
    </choice>
    <pkg-ref id="at.obdev.$pkgUnixName" version="$pkgVersion" onConclusion="none">$pkgUnixName-flat.pkg</pkg-ref>
</installer-gui-script>
EOF
productbuild --distribution "$distfile" --package-path /tmp --resources "$osxpkgtmp/Resources" "/tmp/$pkgUnixName.pkg"
rm -f "$distfile"
rm -rf "/tmp/$pkgUnixName-flat.pkg"
rm -rf "$pkgroot"


#########################################################################
# Disk Image
# MARK: Create Disk Image
#########################################################################

echo "Starting disk image creation at $(date +"%Y-%m-%d %H:%M:%S")"

rwImage="/tmp/$pkgUnixName-$pkgVersion-rw-$$.dmg"   # temporary disk image
dmg="/tmp/$pkgUnixName-$pkgVersion.dmg"

mountpoint="/Volumes/$pkgUnixName"

# Unmount remainings from previous attempts so that we can be sure that
# We don't get a digit-suffix for our mount point
for i in "$mountpoint"*; do
    hdiutil eject "$i" 2>/dev/null
done

# Create a new disk image and mount it
rm -f "$rwImage"
hdiutil create -type UDIF -fs HFS+ -fsargs "-c c=64,a=16,e=16" -nospotlight -volname "$pkgUnixName" -size 65536k "$rwImage"
hdiutil attach -readwrite -noverify -noautoopen "$rwImage"

# Copy our data to the disk image:
# Readme:
cp -a "$osxpkgtmp/Readme.rtf" "/Volumes/$pkgUnixName/Readme.rtf"
# Package:
cp -a "/tmp/$pkgUnixName.pkg" "/Volumes/$pkgUnixName/"

# Now set Finder options, window size and position and Finder options:
# Note:
# Window bounds is {topLeftX, topLeftY, bottomRightX, bottomRightY} in flipped coordinates
# Icon posistions are icon center, measured from top (flipped coordinates)
echo "Starting AppleScript"
osascript <<EOF
    tell application "Finder"
        tell disk "$pkgUnixName"
            open
            set current view of container window to icon view
            set toolbar visible of container window to false
            set statusbar visible of container window to false
            set the bounds of container window to {400, 200, 900, 550}
            set theViewOptions to the icon view options of container window
            set arrangement of theViewOptions to not arranged
            set icon size of theViewOptions to 180
            set position of item "Readme.rtf" of container window to {140, 170}
            set position of item "$pkgUnixName.pkg" of container window to {350, 170}
            close
            open
            update without registering applications
            delay 2
            eject
        end tell
    end tell
EOF
echo "AppleScript done"

# Ensure images is ejected (should be done by AppleScript above anyway)
hdiutil eject "$mountpoint" 2>/dev/null

# And convert it to a compressed read-only image (zlib is smaller than bzip2):
rm -f "$dmg"
#hdiutil convert -format UDBZ -o "$dmg" "$rwImage"
hdiutil convert -format UDZO -imagekey zlib-level=9 -o "$dmg" "$rwImage"

# Remove read-write version of image because it opens automatically when we
# double-click the read-only image.
rm -f "$rwImage"
open $(dirname "$dmg")


#########################################################################
# Cleanup
# MARK: Cleanup
#########################################################################

echo "=== cleaning up..."
rm -rf "$osxpkgtmp"
if ! "$debug"; then
    rm -f "/tmp/$pkgUnixName.pkg"
    rm -rf compile  # source and objects are HUGE
fi
echo "... done"

echo "Finished at $(date +"%Y-%m-%d %H:%M:%S")"
