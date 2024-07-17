#!/bin/sh

set -e -x

. ./config.sh
OPENSSL_FILENAME=openssl-3.0.13.tar.gz
OPENSSL_FILE_PATH=$WORKDIR/$OPENSSL_FILENAME
OPENSSL_SRC_DIR=$WORKDIR/openssl-3.0.13
OPENSSL_SHA256="88525753f79d3bec27d2fa7c66aa0b92b3aa9498dafd93d7cfa4b3780cdae313"
ZLIB_DIR=$WORKDIR/zlib
ZLIB_TAG=v1.2.11
ZLIB_COMMIT_HASH="cacf7f1d4e3d44d871b605da3b647f07d718623f"

rm -rf $ZLIB_DIR
git clone -b $ZLIB_TAG --depth 1 https://github.com/madler/zlib $ZLIB_DIR
cd $ZLIB_DIR
git reset --hard $ZLIB_COMMIT_HASH
CC=clang CXX=clang++ ./configure --static
make

curl https://www.openssl.org/source/$OPENSSL_FILENAME -o $OPENSSL_FILE_PATH
echo $OPENSSL_SHA256 $OPENSSL_FILE_PATH | sha256sum -c - || exit 1

for arch in "aarch" "aarch64" "i686" "x86_64"
do
PREFIX=$WORKDIR/prefix_${arch}
TOOLCHAIN=${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64
PATH="${TOOLCHAIN}/bin:${ORIGINAL_PATH}"
case $arch in
	"aarch")   X_ARCH="android-arm";;
	"aarch64") X_ARCH="android-arm64";;
	"i686")    X_ARCH="android-x86";;
	"x86_64")  X_ARCH="android-x86_64";;
	*)	   X_ARCH="android-${arch}";;
esac

#Disable multithreading for i686, due to issues with atomic operations
case $arch in
	"i686")    THREADS_DISABLE_FLAG="-no-threads";;
	*)	       THREADS_DISABLE_FLAG="";;
esac


cd $WORKDIR
rm -rf $OPENSSL_SRC_DIR
tar -xzf $OPENSSL_FILE_PATH -C $WORKDIR
cd $OPENSSL_SRC_DIR

CC=clang ANDROID_NDK=$TOOLCHAIN \
	./Configure ${X_ARCH} \
	no-shared no-tests \
 	${THREADS_DISABLE_FLAG} \
	--with-zlib-include=${PREFIX}/include \
	--with-zlib-lib=${PREFIX}/lib \
	--prefix=${PREFIX} \
	--openssldir=${PREFIX} \
	-D__ANDROID_API__=$API 
make -j$THREADS
make -j$THREADS install_sw

done

