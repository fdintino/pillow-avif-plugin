#!/usr/bin/env bash
set -eo pipefail

LIBAVIF_VERSION=0.8.4

if uname -s | grep -q Darwin; then
    PREFIX=/usr/local
    MAKE_INSTALL=(make install)
else
    PREFIX=/usr
    MAKE_INSTALL=(sudo make install)
fi

export CFLAGS="-fPIC -O3 $CFLAGS"
export CXXFLAGS="-fPIC -O3 $CXXFLAGS"

curl -sLo - \
    https://github.com/AOMediaCodec/libavif/archive/v$LIBAVIF_VERSION.tar.gz \
    | tar Czxf . -
pushd libavif-$LIBAVIF_VERSION

cd ext
bash libyuv.cmd
bash aom.cmd
# dav1d needs to be compiled with -Denable_avx512=false to accomodate
# older nasm on some systems
perl -pi -e 's/^meson /meson -Denable_avx512=false /g' dav1d.cmd
bash dav1d.cmd
cd ..

mkdir build
cd build
cmake .. \
    -DCMAKE_INSTALL_PREFIX=$PREFIX \
    -DAVIF_CODEC_AOM=ON \
    -DAVIF_LOCAL_AOM=ON \
    -DAVIF_CODEC_DAV1D=ON \
    -DAVIF_LOCAL_DAV1D=ON \
    -DAVIF_LOCAL_LIBYUV=ON
make && "${MAKE_INSTALL[@]}"
cd ..

popd
