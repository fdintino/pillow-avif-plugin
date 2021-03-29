#!/usr/bin/env bash
set -eo pipefail

if [ $(uname) != "Darwin" ]; then
    TRAVIS_OS_NAME="manylinux$MB_ML_VER"
fi

LIBAVIF_CMAKE_FLAGS=()

if uname -s | grep -q Darwin; then
    PREFIX=/usr/local
else
    PREFIX=/usr
fi

PKGCONFIG=${PKGCONFIG:-pkg-config}

export CFLAGS="-fPIC -O3 $CFLAGS"
export CXXFLAGS="-fPIC -O3 $CXXFLAGS"

echo "::group::Fetching libavif"
mkdir -p libavif-$LIBAVIF_VERSION
curl -sLo - \
    https://github.com/AOMediaCodec/libavif/archive/v$LIBAVIF_VERSION.tar.gz \
    | tar --strip-components=1 -C libavif-$LIBAVIF_VERSION -zxf -
pushd libavif-$LIBAVIF_VERSION
echo "::endgroup::"

HAS_DECODER=0
HAS_ENCODER=0

if $PKGCONFIG --exists dav1d; then
    LIBAVIF_CMAKE_FLAGS+=(-DAVIF_CODEC_DAV1D=ON)
    HAS_DECODER=1
fi

if $PKGCONFIG --exists rav1e; then
    LIBAVIF_CMAKE_FLAGS+=(-DAVIF_CODEC_RAV1E=ON)
    HAS_ENCODER=1
fi

if $PKGCONFIG --exists SvtAv1Enc; then
    LIBAVIF_CMAKE_FLAGS+=(-DAVIF_CODEC_SVT=ON)
    HAS_ENCODER=1
fi

if $PKGCONFIG --exists libgav1; then
    LIBAVIF_CMAKE_FLAGS+=(-DAVIF_CODEC_LIBGAV1=ON)
    HAS_DECODER=1
fi

if $PKGCONFIG --exists aom; then
    LIBAVIF_CMAKE_FLAGS+=(-DAVIF_CODEC_AOM=ON)
    HAS_ENCODER=1
    HAS_DECODER=1
fi

if [ "$HAS_ENCODER" != 1 ] || [ "$HAS_DECODER" != 1 ]; then
    echo "::group::Building aom"
    pushd ext > /dev/null
    bash aom.cmd
    popd > /dev/null
    LIBAVIF_CMAKE_FLAGS+=(-DAVIF_CODEC_AOM=ON -DAVIF_LOCAL_AOM=ON)
    echo "::endgroup::"
fi

if uname -s | grep -q Darwin; then
    # Prevent cmake from using @rpath in install id, so that delocate can
    # find and bundle the libavif dylib
    LIBAVIF_CMAKE_FLAGS+=("-DCMAKE_INSTALL_NAME_DIR=$PREFIX/lib" -DCMAKE_MACOSX_RPATH=OFF)
fi

echo "::group::Building libavif"
mkdir build
pushd build
cmake .. \
    -DCMAKE_INSTALL_PREFIX=$PREFIX \
    -DCMAKE_BUILD_TYPE=Release \
    "${LIBAVIF_CMAKE_FLAGS[@]}"
make
popd

popd
echo "::endgroup::"
