#!/bin/bash

# Project: avr-gcc-build
# Author: Zak Kemble, contact@zakkemble.net
# Copyright: (C) 2022 by Zak Kemble
# Web: https://blog.zakkemble.net/avr-gcc-builds/

# License:
# Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
# http://creativecommons.org/licenses/by-sa/4.0/


# http://www.nongnu.org/avr-libc/user-manual/install_tools.html

# For optimum compile time this should generally be set to the number of CPU cores your machine has.
# Some systems with not much RAM may fail with "collect2: fatal error: ld terminated with signal 9 [Killed]", if this happens try reducing the JOBCOUNT value.
# In my case Debian 10 builds GCC 10.1.0 fine with 4 cores and 2GB RAM, but Debian 11 needs 5.5GB?
JOBCOUNT=$(getconf _NPROCESSORS_ONLN)

# Build for Linux
# A Linux AVR-GCC toolchain is required to build a Windows toolchain
# If the Linux toolchain has already been built then you can set this to 0
FOR_LINUX=1

# Build for 32 bit Windows
FOR_WINX86=1

# Build for 64 bit Windows
FOR_WINX64=1

# Build Binutils for selected OSs
BUILD_BINUTILS=1

# Build GCC for selected OSs (requires AVR-Binutils)
BUILD_GCC=1

# Build GDB for selected OSs
BUILD_GDB=1

# Build AVR-LibC (requires AVR-GCC)
BUILD_LIBC=1

NAME_BINUTILS="binutils-2.36.1"
NAME_GCC="gcc-11.1.0"
NAME_GDB="gdb-10.2"
NAME_LIBC="avr-libc3.git" # https://github.com/stevenj/avr-libc3
COMMIT_LIBC="d09c2a61764aced3274b6dde4399e11b0aee4a87"

# Output locations for built toolchains
BASE=/omgwtfbbq/
PREFIX_GCC_LINUX=${BASE}avr-${NAME_GCC}-x64-linux
PREFIX_GCC_WINX86=${BASE}avr-${NAME_GCC}-x86-windows
PREFIX_GCC_WINX64=${BASE}avr-${NAME_GCC}-x64-windows
PREFIX_LIBC=${BASE}avr-libc # The contents of the avr-libc directory will need to be copied/merged with each of the target toolchain directories

HOST_WINX86="i686-w64-mingw32"
HOST_WINX64="x86_64-w64-mingw32"

OPTS_BINUTILS="
	--target=avr
	--disable-nls
	--disable-werror
"

OPTS_GCC="
	--target=avr
	--enable-languages=c,c++
	--disable-nls
	--disable-libssp
	--disable-libada
	--with-dwarf2
	--disable-shared
	--enable-static
	--enable-mingw-wildcard
	--enable-plugin
	--with-gnu-as
"

OPTS_GDB="
	--target=avr
	--with-static-standard-libraries
"

OPTS_LIBC=""

# Install packages
if hash apt-get 2>/dev/null; then

	# This works for Debian 8 and Ubuntu 16.04
	apt-get install wget make mingw-w64 gcc g++ bzip2 git autoconf texinfo

elif hash yum 2>/dev/null; then

	# This works for CentOS 7
	yum install wget git texinfo

	rpm -q epel-release-7-6.noarch >/dev/null
	if [ $? -ne 0 ]; then
		# EPEL is for the MinGW stuff
		rm -f epel-release-7-6.noarch.rpm
		wget https://www.mirrorservice.org/sites/dl.fedoraproject.org/pub/epel//7/x86_64/e/epel-release-7-6.noarch.rpm
		rpm -Uvh epel-release-7-6.noarch.rpm
	fi

	yum install make mingw64-gcc mingw64-gcc-c++ mingw32-gcc mingw32-gcc-c++ gcc gcc-c++ bzip2 autoconf

elif hash pacman 2>/dev/null; then

	# Things have changed with Arch and this is now broken :/
	pacman -S --needed wget make mingw-w64-binutils mingw-w64-gcc mingw-w64-crt mingw-w64-headers mingw-w64-winpthreads gcc bzip2 git autoconf texinfo

fi

# Stop on errors
set -e

TIME_START=$(date +%s)

LOG_DIR=$(pwd)
log()
{
	echo "$1"
	echo "[$(date +"%d %b %y %H:%M:%S")]: $1" >> "$LOG_DIR/avr-gcc-build.log"
}

makeDir()
{
	rm -rf "$1/"
	mkdir -p "$1"
}

fixGCCAVR()
{
	# In GCC 7.1.0 there seems to be an issue with INT8_MAX and some other things being undefined in /gcc/config/avr/avr.c when building for Windows.
	# Adding '#include <stdint.h>' doesn't fix it, but manually defining the values does the trick.

	echo "Fixing missing defines..."

	DEFSFIX="
		#if (defined _WIN32 || defined __CYGWIN__)
		#define INT8_MIN (-128)
		#define INT16_MIN (-32768)
		#define INT8_MAX 127
		#define INT16_MAX 32767
		#define UINT8_MAX 0xff
		#define UINT16_MAX 0xffff
		#endif
	"

	ORIGINAL=$(cat ../gcc/config/avr/avr.c)
	echo "$DEFSFIX" > ../gcc/config/avr/avr.c
	echo "$ORIGINAL" >> ../gcc/config/avr/avr.c
}

log "Start"

log "Clearing output directories..."
[ $FOR_LINUX -eq 1 ] && makeDir "$PREFIX_GCC_LINUX"
[ $FOR_WINX86 -eq 1 ] && makeDir "$PREFIX_GCC_WINX86"
[ $FOR_WINX64 -eq 1 ] && makeDir "$PREFIX_GCC_WINX64"
[ $BUILD_LIBC -eq 1 ] && makeDir "$PREFIX_LIBC"

log "Clearing old downloads..."
rm -f $NAME_BINUTILS.tar.xz
rm -rf $NAME_BINUTILS/
rm -f $NAME_GCC.tar.xz
rm -rf $NAME_GCC/
rm -f $NAME_GDB.tar.xz
rm -rf $NAME_GDB/
rm -f $NAME_LIBC.tar.bz2
rm -rf $NAME_LIBC/

log "Downloading sources..."
[ $BUILD_BINUTILS -eq 1 ] && wget https://ftpmirror.gnu.org/binutils/$NAME_BINUTILS.tar.xz
[ $BUILD_GCC -eq 1 ] && wget https://ftpmirror.gnu.org/gcc/$NAME_GCC/$NAME_GCC.tar.xz
[ $BUILD_GDB -eq 1 ] && wget https://ftpmirror.gnu.org/gdb/$NAME_GDB.tar.xz
if [ $BUILD_LIBC -eq 1 ]; then
	if [ "$NAME_LIBC" = "avr-libc3.git" ]; then
		git clone https://github.com/stevenj/$NAME_LIBC "$NAME_LIBC"
	else
		wget http://download.savannah.gnu.org/releases/avr-libc/$NAME_LIBC.tar.bz2
	fi
fi

PATH="$PREFIX_GCC_LINUX"/bin:"$PATH"
export PATH

CC=""
export CC

confMake()
{
	../configure --prefix=$1 $2 $3 $4
	make -j $JOBCOUNT
	make install-strip
	rm -rf *
}

confMakeGDB()
{
	# install-strip doesn't work properly with GDB, so we have to manually strip the massive 100MB+ executable down to ~5MB then do a normal install
	../configure --prefix=$2 $3 $4 $5
	make -j $JOBCOUNT
	$1
	make install
	rm -rf *
}

# Make AVR-Binutils
if [ $BUILD_BINUTILS -eq 1 ]; then
	log "***Binutils***"
	log "Extracting..."
	tar xf $NAME_BINUTILS.tar.xz
	mkdir -p $NAME_BINUTILS/obj-avr
	cd $NAME_BINUTILS/obj-avr

	log "Making for Linux..."
	[ $FOR_LINUX -eq 1 ] && confMake "$PREFIX_GCC_LINUX" "$OPTS_BINUTILS"
	log "Making for Windows x86..."
	[ $FOR_WINX86 -eq 1 ] && confMake "$PREFIX_GCC_WINX86" "$OPTS_BINUTILS" --host=$HOST_WINX86 --build=`../config.guess`
	log "Making for Windows x64..."
	[ $FOR_WINX64 -eq 1 ] && confMake "$PREFIX_GCC_WINX64" "$OPTS_BINUTILS" --host=$HOST_WINX64 --build=`../config.guess`

	cd ../../
else
	log "Skipping Binutils..."
fi

# Make AVR-GCC
if [ $BUILD_GCC -eq 1 ]; then
	log "***GCC***"
	log "Extracting..."
	tar xf $NAME_GCC.tar.xz
	mkdir -p $NAME_GCC/obj-avr
	cd $NAME_GCC
	
	log "Getting prerequisites..."
	chmod +x ./contrib/download_prerequisites
	./contrib/download_prerequisites

	cd obj-avr
	# fixGCCAVR

	log "Making for Linux..."
	[ $FOR_LINUX -eq 1 ] && confMake "$PREFIX_GCC_LINUX" "$OPTS_GCC"
	log "Making for Windows x86..."
	[ $FOR_WINX86 -eq 1 ] && confMake "$PREFIX_GCC_WINX86" "$OPTS_GCC" --host=$HOST_WINX86 --build=`../config.guess`
	log "Making for Windows x64..."
	[ $FOR_WINX64 -eq 1 ] && confMake "$PREFIX_GCC_WINX64" "$OPTS_GCC" --host=$HOST_WINX64 --build=`../config.guess`

	cd ../../
else
	log "Skipping GCC..."
fi

# Make GDB
if [ $BUILD_GDB -eq 1 ]; then
	log "***GDB***"
	log "Extracting..."
	tar xf $NAME_GDB.tar.xz
	mkdir -p $NAME_GDB/obj-avr
	cd $NAME_GDB/obj-avr
	
	log "Making for Linux..."
	[ $FOR_LINUX -eq 1 ] && confMakeGDB "strip gdb/gdb" "$PREFIX_GCC_LINUX" "$OPTS_GDB"
	log "Making for Windows x86..."
	[ $FOR_WINX86 -eq 1 ] && confMakeGDB "$HOST_WINX86-strip gdb/gdb.exe" "$PREFIX_GCC_WINX86" "$OPTS_GDB" --host=$HOST_WINX86 --build=`../config.guess`
	log "Making for Windows x64..."
	[ $FOR_WINX64 -eq 1 ] && confMakeGDB "$HOST_WINX64-strip gdb/gdb.exe" "$PREFIX_GCC_WINX64" "$OPTS_GDB" --host=$HOST_WINX64 --build=`../config.guess`

	cd ../../
else
	log "Skipping GDB..."
fi

# Make AVR-LibC
if [ $BUILD_LIBC -eq 1 ]; then
	log "***AVR-LibC***"
	if [ "$NAME_LIBC" = "avr-libc3.git" ]; then
		log "Preparing..."
		cd $NAME_LIBC
		git checkout $COMMIT_LIBC
		./bootstrap
		cd ..
	else
		log "Extracting..."
		bunzip2 -c $NAME_LIBC.tar.bz2 | tar xf -
	fi
	mkdir -p $NAME_LIBC/obj-avr
	cd $NAME_LIBC/obj-avr
	
	log "Making..."
	confMake "$PREFIX_LIBC" "$OPTS_LIBC" --host=avr --build=`../config.guess`

	cd ../../
else
	log "Skipping AVR-LibC..."
fi

TIME_END=$(date +%s)
TIME_RUN=$(($TIME_END - $TIME_START))

log ""
log "Done in $TIME_RUN seconds"

exit 0
