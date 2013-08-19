#!/bin/sh
#
# by hongbo.yang.me
# 2013-Aug-16th
#

#
# build ffmpeg libs for iOS
#

ROOT=`pwd`
PREFIX="$ROOT/build"

if [ -d "$PREFIX" ]; then
    rm -rf "$PREFIX"
fi

if [ ! -d "$PREFIX" ]; then
    mkdir -p $PREFIX
fi

MODULES_FLAGS="
--disable-programs 
"

echo "Building for MacOSX ..."
cd ffmpeg
./configure \
    --prefix="$PREFIX/macosx" \
    --extra-ldflags=-L/opt/local/lib \
    --extra-cflags=-I/opt/local/include \
    $MODULES_FLAGS \
    --enable-ffmpeg
    make clean && make && make install
cd $ROOT


# configure uses PATH to find gas-preprocessor.pl
export PATH="$ROOT/gas-preprocessor:$PATH"

patch -Np0 <configure.patch ffmpeg/configure

ARCHS=(i386 armv7 armv7s)

for ARCH in ${ARCHS[@]}
do
    . environment.sh
    cd ffmpeg

    ARM_FLAGS=" --arch=arm --enable-thumb --enable-neon --disable-armv5te"
    # --as=\"$ROOT/gas-preprocessor/gas-preprocessor.pl $CC\"" # not work and useless ( configure just uses path to find gas-preprocesor.pl

    X86_FLAGS=" --disable-asm "
    ADD_FLAGS=""
    EXTRA_CFLAGS=""
    if [ "armv7s" == $ARCH ]; then
        ARCH_FLAGS="--cpu=cortex-a9 $ARM_FLAGS"
        EXTRA_CFLAGS="-mfpu=neon"
    elif [ "armv7" == $ARCH ]; then
        ARCH_FLAGS="--cpu=cortex-a8 $ARM_FLAGS"
        EXTRA_CFLAGS="-mfpu=neon"
    elif [ "i386" == $ARCH ]; then
        ARCH_FLAGS="--cpu=core2 --arch=x86 $X86_FLAGS"
    fi
    PREFIX_DIR="$PREFIX/$ARCH"
    if [ ! -d "$PREFIX_DIR" ]; then
        mkdir -p "$PREFIX_DIR"
    fi
    ./configure --enable-cross-compile \
        --enable-static \
        --disable-shared \
        --target-os=darwin \
        --prefix=$PREFIX_DIR  \
        --arch=$ARCH --disable-debug   --enable-pic \
        --disable-doc \
        --cc=$CC  --extra-cflags="$CFLAGS $EXTRA_CFLAGS" \
        --cxx=$CXX --extra-cxxflags="$CXXFLAGS" \
        --ld=$LD --extra-ldflags="$LDFLAGS -lc" \
        $ARCH_FLAGS \
        $MODULES_FLAGS


    if [ "0" == "$?" ]; then
        make clean && make && make install
    fi
    cd "$ROOT"
done

mkdir -p $PREFIX/universal/{include,lib}

for file in $PREFIX/$ARCHS/lib/*.a
do
    files=""
    file=`basename $file`
    for ARCH in ${ARCHS[@]}
    do
       files+=" $PREFIX/$ARCH/lib/$file " 
    done
    echo "Creating universal $file"
    lipo $files -create -output "$PREFIX/universal/lib/$file"
done

cp -r $PREFIX/$ARCHS/include/* $PREFIX/universal/include/
