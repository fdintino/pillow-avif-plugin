#!/usr/bin/env bash
set -eo pipefail

SVT_AV1_VERSION=0.8.6

if uname -s | grep -q Darwin; then
    PREFIX=/usr/local
else
    PREFIX=/usr
fi

export CFLAGS="-fPIC -O3 $CFLAGS"
export CXXFLAGS="-fPIC -O3 $CXXFLAGS"

mkdir -p libavif-$LIBAVIF_SHA
curl -sLo - \
    https://github.com/AOMediaCodec/libavif/archive/$LIBAVIF_SHA.tar.gz \
    | tar --strip-components=1 -C libavif-$LIBAVIF_SHA -zxf -
pushd libavif-$LIBAVIF_SHA

pushd ext

echo "Installing libyuv"
bash libyuv.cmd

echo "Installing aom"
bash aom.cmd

echo "Installing rav1e"
perl -pi -e 's/cargo install /cargo install --locked /g' rav1e.cmd
bash rav1e.cmd

echo "Installing libgav1"
bash libgav1.cmd

echo "Installing dav1d"
bash dav1d.cmd

echo "Installing SVT-AV1"
curl -sLo - \
    https://github.com/AOMediaCodec/SVT-AV1/archive/v$SVT_AV1_VERSION.tar.gz \
    | tar Czxf . -
mv SVT-AV1-$SVT_AV1_VERSION SVT-AV1

pushd SVT-AV1
pushd Build/linux

sed -i.backup 's/check_executable \-p sudo/check_executable \-p sudo || true/' build.sh

if [[ "$OSTYPE" == "darwin"* ]]; then
	echo "Applying Darwin patch"
	perl -p0i -e 's/(?<=\n)(\s*?)toolchain=\*\)\n.*?\n\1    ;;\n//sm' build.sh
fi

./build.sh release static
popd  # SVT-AV1
mkdir -p include/svt-av1
cp Source/API/*.h include/svt-av1

popd  # ext
popd  # root

mkdir build
pushd build
cmake .. \
    -DCMAKE_INSTALL_PREFIX=$PREFIX \
    -DCMAKE_BUILD_TYPE=Release \
    -DAVIF_CODEC_AOM=ON \
    -DAVIF_LOCAL_AOM=ON \
    -DAVIF_CODEC_RAV1E=ON \
    -DAVIF_LOCAL_RAV1E=ON \
    -DAVIF_CODEC_LIBGAV1=ON \
    -DAVIF_LOCAL_LIBGAV1=ON \
    -DAVIF_CODEC_SVT=ON \
    -DAVIF_LOCAL_SVT=ON \
    -DAVIF_CODEC_DAV1D=ON \
    -DAVIF_LOCAL_DAV1D=ON \
    -DAVIF_LOCAL_LIBYUV=ON
make
popd

popd
