#!/usr/bin/env bash
set -eo pipefail

if [ $(uname) != "Darwin" ]; then
    TRAVIS_OS_NAME="manylinux$MB_ML_VER"
fi
    
SVT_AV1_VERSION=0.8.6
LIBAVIF_CMAKE_FLAGS=()

if uname -s | grep -q Darwin; then
    PREFIX=/usr/local
else
    PREFIX=/usr
fi

export CFLAGS="-fPIC -O3 $CFLAGS"
export CXXFLAGS="-fPIC -O3 $CXXFLAGS"

echo "::group::Fetching libavif"
mkdir -p libavif-$LIBAVIF_SHA
curl -sLo - \
    https://github.com/AOMediaCodec/libavif/archive/$LIBAVIF_SHA.tar.gz \
    | tar --strip-components=1 -C libavif-$LIBAVIF_SHA -zxf -
pushd libavif-$LIBAVIF_SHA
echo "::endgroup::"

pushd ext > /dev/null

echo "::group::Building aom"
if [ "$TRAVIS_OS_NAME" == "manylinux1" ]; then
    # Patch for old perl and gcc on manylinux1
    if [ ! -e aom ]; then
        git clone -b v2.0.1 --depth 1 https://aomedia.googlesource.com/aom
    fi
    (cd aom && patch -p1 < ../../../aom-fixes-for-building-on-manylinux1.patch)
fi
bash aom.cmd
LIBAVIF_CMAKE_FLAGS+=(-DAVIF_CODEC_AOM=ON -DAVIF_LOCAL_AOM=ON)
echo "::endgroup::"

if which cargo 1>/dev/null 2>/dev/null; then
    echo "::group::Installing rav1e"
    bash rav1e.cmd
    LIBAVIF_CMAKE_FLAGS+=(-DAVIF_CODEC_RAV1E=ON -DAVIF_LOCAL_RAV1E=ON)
    echo "::endgroup::"
fi

if [ "$TRAVIS_OS_NAME" != "manylinux1" ]; then
    echo "::group::Building libgav1"
    bash libgav1.cmd
    LIBAVIF_CMAKE_FLAGS+=(-DAVIF_CODEC_LIBGAV1=ON -DAVIF_LOCAL_LIBGAV1=ON)
    echo "::endgroup::"
fi

echo "::group::Building dav1d"
bash dav1d.cmd
LIBAVIF_CMAKE_FLAGS+=(-DAVIF_CODEC_DAV1D=ON -DAVIF_LOCAL_DAV1D=ON)
echo "::endgroup::"

if [ "$TRAVIS_OS_NAME" != "manylinux1" ] && [ "$PLAT" != "i686" ]; then
    echo "::group::Building SVT-AV1"
    if [ ! -e SVT-AV1 ]; then
        curl -sLo - \
            https://github.com/AOMediaCodec/SVT-AV1/archive/v$SVT_AV1_VERSION.tar.gz \
            | tar Czxf . -
        mv SVT-AV1-$SVT_AV1_VERSION SVT-AV1
    fi

    pushd SVT-AV1
    pushd Build/linux

    sed -i.backup 's/check_executable \-p sudo/check_executable \-p sudo || true/' build.sh

    echo "Applying patch for older bash versions"
    perl -p0i -e 's/(?<=\n)(\s*?)toolchain=\*\)\n.*?\n\1    ;;\n//sm' build.sh

    if [ "$TRAVIS_OS_NAME" == "manylinux2010" ]; then
        LDFLAGS=-lrt ./build.sh release static
        LIBAVIF_CMAKE_FLAGS+=(-DCMAKE_EXE_LINKER_FLAGS=-lrt)
    else
        ./build.sh release static
    fi
    popd  # SVT-AV1
    mkdir -p include/svt-av1
    cp Source/API/*.h include/svt-av1
    LIBAVIF_CMAKE_FLAGS+=(-DAVIF_CODEC_SVT=ON -DAVIF_LOCAL_SVT=ON)
    popd  # ext
    echo "::endgroup::"
fi

popd > /dev/null # root

if [ "$TRAVIS_OS_NAME" == "osx" ]; then
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
