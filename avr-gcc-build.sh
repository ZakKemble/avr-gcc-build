#!/bin/bash

# avr-gcc-build
# https://blog.zakkemble.net/avr-gcc-builds/
# https://github.com/ZakKemble/avr-gcc-build
# Copyright (C) 2024, Zak Kemble
# Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
# http://creativecommons.org/licenses/by-sa/4.0/

CWD=$(pwd)

# ++++ Error Handling and Backtracing ++++
set -eE -o functrace

backtrace()
{
    local deptn=${#FUNCNAME[@]}
    local start=${1:-1}
    for ((i=$start; i<$deptn; i++)); do
        local func="${FUNCNAME[$i]}"
        local line="${BASH_LINENO[$((i-1))]}"
        local src="${BASH_SOURCE[$((i-1))]}"
        printf '%*s' $i '' # indent
        echo "at: $func(), $src, line $line"
    done
}

suppressError=0

failure()
{
	[[ $suppressError -ne 0 ]] && return 0
	local lineno=$1
	local msg=$2
	echo "Failed at $lineno: $msg"
	echo "  pwd: $CWD"
	backtrace 2
}

trap 'failure ${LINENO} "$BASH_COMMAND"' ERR
# ---- Erorr Handling and Backtracing ----


# http://www.nongnu.org/avr-libc/user-manual/install_tools.html

# VM with 4x AMD Ryzen 5 5600X cores & 5.5GB RAM
# Debian 11 & GCC 10.2.1
# AVR-GCC 12.1.0 compile time: Around 1 hour for all 3 hosts

# For optimum compile time this should generally be set to the number of CPU cores your machine has.
# Some systems with not much RAM may fail with "collect2: fatal error: ld terminated with signal 9 [Killed]", if this happens try reducing the JOBCOUNT value or add more RAM.
# In my case using GCC 8.3.0 on Debian 10 with 2GB RAM was fine, but Debian 11 and GCC 10.2.1 needed 5.5GB
JOBCOUNT=${JOBCOUNT:-$(getconf _NPROCESSORS_ONLN)}

# Build for Linux
# A Linux AVR-GCC toolchain is required to build a Windows toolchain
# If the Linux toolchain has already been built then you can set this to 0
FOR_LINUX=${FOR_LINUX:-1}

# Build for 32 bit Windows
FOR_WINX86=${FOR_WINX86:-0}

# Build for 64 bit Windows
FOR_WINX64=${FOR_WINX64:-1}

# Build Binutils for selected OSs
BUILD_BINUTILS=${BUILD_BINUTILS:-1}

# Build GCC for selected OSs (requires AVR-Binutils)
BUILD_GCC=${BUILD_GCC:-1}

# Build GDB for selected OSs
BUILD_GDB=${BUILD_GDB:-1}

# Build AVR-LibC (requires AVR-GCC)
BUILD_LIBC=${BUILD_LIBC:-1}

# TODO sometime maybe
#BUILD_SIMULAVR=1
#BUILD_MAKE=1
#BUILD_COREUTILS=1

NAME_BINUTILS="binutils-${VER_BINUTILS:-2.42}"
NAME_GCC="gcc-${VER_GCC:-14.1.0}"
NAME_GDB="gdb-${VER_GDB:-14.2}"
NAME_GMP="gmp-6.3.0" # GDB 11+ needs libgmp
NAME_MPFR="mpfr-4.2.1" # GDB 14+ needs libmpfr
#NAME_MAKE="make-4.4.1"
#NAME_COREUTILS="coreutils-9.6"
NAME_LIBC=("avr-libc-2_2_0-release" "avr-libc-2.2.0")

# Output locations for built toolchains
BASE=${BASE:-${CWD}/build/}
PREFIX_GCC_LINUX=${BASE}avr-${NAME_GCC}-x64-linux
PREFIX_GCC_WINX86=${BASE}avr-${NAME_GCC}-x86-windows
PREFIX_GCC_WINX64=${BASE}avr-${NAME_GCC}-x64-windows

HOST_WINX86="i686-w64-mingw32"
HOST_WINX64="x86_64-w64-mingw32"

# Uncomment the next 2 export lines and replace "--enable-plugin"
# with "--disable-plugin" in OPTS_GCC for a fully static linux build.
# NOTE: Plugin support is probably needed for LTO and some other stuff
#export CFLAGS="-static --static"
#export CXXFLAGS="${CFLAGS}"

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
	--with-gnu-ld
	--without-zstd
"

OPTS_GDB="
	--target=avr
	--with-static-standard-libraries
"
# --disable-source-highlight

OPTS_LIBC=""

TMP_DIR=${CWD}/tmp
LOG_DIR=${CWD}

log()
{
	echo "$1"
	echo "[$(date +"%d %b %y %H:%M:%S")]: $1" >> "$LOG_DIR/avr-gcc-build.log"
}

installPackages()
{
	local requiredPackages=("wget" "make" "mingw-w64" "gcc" "g++" "bzip2" "xz-utils" "autoconf" "texinfo" "libgmp-dev" "libmpfr-dev")

	if [[ $EUID -ne 0 ]]; then
		log "Not running as root user. Checking whether all required packages are installed..."
		local packageMissing=0
		for package in "${requiredPackages[@]}"
		do
			if ! dpkg -s "$package" > /dev/null 2>&1; then
				echo "ERROR: Package \"$package\" is not installed. But it is required." 1>&2
				packageMissing=1
			fi
		done

		if [[ $packageMissing -ne 0 ]]; then
			echo "Not all required packages are installed. You need to install them manually or run the script with root (sudo)" 1>&2
			exit 2
		fi

		echo "All required packages are installed. Continuing..."
	else
		log "Running as root user. Installing required packages via apt..."
		apt install "${requiredPackages[@]}"
	fi
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

cleanup()
{
	log "Clearing output directories..."
	[[ $FOR_LINUX -eq 1 ]] && makeDir "$PREFIX_GCC_LINUX"
	[[ $FOR_WINX86 -eq 1 ]] && makeDir "$PREFIX_GCC_WINX86"
	[[ $FOR_WINX64 -eq 1 ]] && makeDir "$PREFIX_GCC_WINX64"

	log "Clearing old downloads..."
	rm -f $NAME_BINUTILS.tar.xz
	rm -rf $NAME_BINUTILS
	rm -f $NAME_GCC.tar.xz
	rm -rf $NAME_GCC
	rm -f $NAME_GDB.tar.xz
	rm -rf $NAME_GDB
	rm -f $NAME_GMP.tar.xz
	rm -rf $NAME_GMP
	rm -f $NAME_MPFR.tar.xz
	rm -rf $NAME_MPFR
	rm -f ${NAME_LIBC[1]}.tar.bz2
	rm -rf ${NAME_LIBC[1]}
}

downloadSources()
{
	log "Downloading sources..."
	[[ $BUILD_BINUTILS -eq 1 ]] && log "$NAME_BINUTILS" && wget https://ftpmirror.gnu.org/binutils/$NAME_BINUTILS.tar.xz
	[[ $BUILD_GCC -eq 1 ]] && log "$NAME_GCC" && wget https://ftpmirror.gnu.org/gcc/$NAME_GCC/$NAME_GCC.tar.xz
	if [[ $BUILD_GDB -eq 1 ]]; then
		log "$NAME_GDB"
		wget https://ftpmirror.gnu.org/gdb/$NAME_GDB.tar.xz
		if [[ $FOR_WINX86 -eq 1 ]] || [[ $FOR_WINX64 -eq 1 ]]; then
			log "$NAME_GMP"
			wget https://ftpmirror.gnu.org/gmp/$NAME_GMP.tar.xz
			log "$NAME_MPFR"
			wget https://ftpmirror.gnu.org/mpfr/$NAME_MPFR.tar.xz
		fi
	fi
	if [[ $BUILD_LIBC -eq 1 ]]; then
		log "${NAME_LIBC[1]}"
		wget https://github.com/avrdudes/avr-libc/releases/download/${NAME_LIBC[0]}/${NAME_LIBC[1]}.tar.bz2
	fi

#	[[ $BUILD_MAKE -eq 1 ]] && wget http://ftp.gnu.org/gnu/make/$NAME_MAKE.tar.gz
#	[[ $BUILD_COREUTILS -eq 1 ]] && wget https://ftp.gnu.org/gnu/coreutils/$NAME_COREUTILS.tar.xz
}

confMake()
{
	../configure --prefix=$1 $2 $3 --build=`../config.guess`
	make -j $JOBCOUNT
	make install-strip
	rm -rf *
}

buildBinutils()
{
	log "***Binutils***"
	[[ $BUILD_BINUTILS -ne 1 ]] && log "(Skipping)" && return 0

	log "Extracting..."
	tar xf $NAME_BINUTILS.tar.xz
	mkdir -p $NAME_BINUTILS/obj-avr
	cd $NAME_BINUTILS/obj-avr

	[[ $FOR_LINUX -eq 1 ]] && log "Making for Linux..." && confMake "$PREFIX_GCC_LINUX" "$OPTS_BINUTILS"
	[[ $FOR_WINX86 -eq 1 ]] && log "Making for Windows x86..." && confMake "$PREFIX_GCC_WINX86" "$OPTS_BINUTILS" --host=$HOST_WINX86
	[[ $FOR_WINX64 -eq 1 ]] && log "Making for Windows x64..." && confMake "$PREFIX_GCC_WINX64" "$OPTS_BINUTILS" --host=$HOST_WINX64

	cd ../../
}

buildGCC()
{
	log "***GCC***"
	[[ $BUILD_GCC -ne 1 ]] && log "(Skipping)" && return 0

	log "Extracting..."
	tar xf $NAME_GCC.tar.xz
	mkdir -p $NAME_GCC/obj-avr
	cd $NAME_GCC
	
	log "Getting prerequisites..."
	chmod +x ./contrib/download_prerequisites
	./contrib/download_prerequisites

	cd obj-avr
	# fixGCCAVR

	[[ $FOR_LINUX -eq 1 ]] && log "Making for Linux..." && confMake "$PREFIX_GCC_LINUX" "$OPTS_GCC"
	[[ $FOR_WINX86 -eq 1 ]] && log "Making for Windows x86..." && confMake "$PREFIX_GCC_WINX86" "$OPTS_GCC" --host=$HOST_WINX86
	[[ $FOR_WINX64 -eq 1 ]] && log "Making for Windows x64..." && confMake "$PREFIX_GCC_WINX64" "$OPTS_GCC" --host=$HOST_WINX64

	cd ../../
}

buildGDB()
{
	log "***GDB (and GMP, MPFR for Windows)***"
	[[ $BUILD_GDB -ne 1 ]] && log "(Skipping)" && return 0

	log "Extracting..."
	tar xf $NAME_GDB.tar.xz
	mkdir -p $NAME_GDB/obj-avr
	if [[ $FOR_WINX86 -eq 1 ]] || [[ $FOR_WINX64 -eq 1 ]]; then
		tar xf $NAME_GMP.tar.xz
		mkdir -p $NAME_GMP/obj
		tar xf $NAME_MPFR.tar.xz
		mkdir -p $NAME_MPFR/obj
	fi

	if [[ $FOR_LINUX -eq 1 ]]; then
		log "Making for Linux..."
		cd $NAME_GDB/obj-avr
		confMake "$PREFIX_GCC_LINUX" "$OPTS_GDB"
		cd ../../
	fi

	buildGDBWin()
	{
		log "GMP..."
		cd $NAME_GMP/obj
		confMake $TMP_DIR/$2 --host=$2
		cd ../../
		
		log "MPFR..."
		cd $NAME_MPFR/obj
		confMake $TMP_DIR/$2 "--with-gmp=$TMP_DIR/$2 --disable-shared --enable-static" --host=$2
		cd ../../

		log "GDB..."
		cd $NAME_GDB/obj-avr
		confMake "$1" "--with-gmp=$TMP_DIR/$2 --with-mpfr=$TMP_DIR/$2 $OPTS_GDB" --host=$2
		cd ../../
	}

	[[ $FOR_WINX86 -eq 1 ]] && log "Making for Windows x86..." && buildGDBWin "$PREFIX_GCC_WINX86" $HOST_WINX86
	[[ $FOR_WINX64 -eq 1 ]] && log "Making for Windows x64..." && buildGDBWin "$PREFIX_GCC_WINX64" $HOST_WINX64

	# For some reason we need some random command here otherwise
	# the script exits with no error when FOR_WINX64=0
	echo "" > /dev/null
}

buildAVRLIBC()
{
	log "***AVR-LibC***"
	[[ $BUILD_LIBC -ne 1 ]] && log "(Skipping)" && return 0

	log "Extracting..."
	bunzip2 -c ${NAME_LIBC[1]}.tar.bz2 | tar xf -
	mkdir -p ${NAME_LIBC[1]}/obj-avr
	cd ${NAME_LIBC[1]}/obj-avr
	
	log "Making..."
	../configure "$OPTS_LIBC" --host=avr --build=`../config.guess`
	make -j $JOBCOUNT

	log "Installing into toolchains..."
	[[ $FOR_LINUX -eq 1 ]] && log "Linux" && make install prefix="${PREFIX_GCC_LINUX}"
	[[ $FOR_WINX86 -eq 1 ]] && log "Windows x86" && make install prefix="${PREFIX_GCC_WINX86}"
	[[ $FOR_WINX64 -eq 1 ]] && log "Windows x64" && make install prefix="${PREFIX_GCC_WINX64}"

	cd ../../
}

installPackages

log "Start"

TIME_START=$(date +%s)

export PATH="$PREFIX_GCC_LINUX"/bin:"$PATH"
export CC=""

cleanup
downloadSources
buildBinutils
buildGCC
buildGDB
buildAVRLIBC

TIME_END=$(date +%s)
TIME_RUN=$(($TIME_END - $TIME_START))

echo ""
log "Done in $TIME_RUN seconds"
log "Toolchains are in $BASE"

exit 0
