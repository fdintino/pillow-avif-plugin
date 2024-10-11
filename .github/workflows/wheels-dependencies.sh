#!/bin/bash
# Define custom utilities
# Setup that needs to be done before multibuild utils are invoked
PROJECTDIR=$(pwd)
if [[ "$(uname -s)" == "Darwin" ]]; then
    # Safety check - macOS builds require that CIBW_ARCHS is set, and that it
    # only contains a single value (even though cibuildwheel allows multiple
    # values in CIBW_ARCHS).
    if [[ -z "$CIBW_ARCHS" ]]; then
        echo "ERROR: Pillow macOS builds require CIBW_ARCHS be defined."
        exit 1
    fi
    if [[ "$CIBW_ARCHS" == *" "* ]]; then
        echo "ERROR: Pillow macOS builds only support a single architecture in CIBW_ARCHS."
        exit 1
    fi

    # Build macOS dependencies in `build/darwin`
    # Install them into `build/deps/darwin`
    export WORKDIR=$(pwd)/build/darwin
    export BUILD_PREFIX=$(pwd)/build/deps/darwin
else
    # Build prefix will default to /usr/local
    export WORKDIR=$(pwd)/build
    export MB_ML_LIBC=${AUDITWHEEL_POLICY::9}
    export MB_ML_VER=${AUDITWHEEL_POLICY:9}
fi
export PLAT="${CIBW_ARCHS:-$AUDITWHEEL_ARCH}"

source multibuild/common_utils.sh
source multibuild/library_builders.sh
if [ -z "$IS_MACOS" ]; then
    source multibuild/manylinux_utils.sh
fi

source wheelbuild/config.sh

function build_pkg_config {
    if [ -e pkg-config-stamp ]; then return; fi
    # This essentially duplicates the Homebrew recipe
    CFLAGS="$CFLAGS -Wno-int-conversion" build_simple pkg-config 0.29.2 https://pkg-config.freedesktop.org/releases tar.gz \
        --disable-debug --disable-host-tool --with-internal-glib \
        --with-pc-path=$BUILD_PREFIX/share/pkgconfig:$BUILD_PREFIX/lib/pkgconfig \
        --with-system-include-path=$(xcrun --show-sdk-path --sdk macosx)/usr/include
    export PKG_CONFIG=$BUILD_PREFIX/bin/pkg-config
    touch pkg-config-stamp
}

function build {
    if [[ -n "$IS_MACOS" ]] && [[ "$CIBW_ARCHS" == "arm64" ]]; then
        sudo chown -R runner /usr/local
    fi
    pre_build
}

if [[ -n "$IS_MACOS" ]]; then
    # Homebrew (or similar packaging environments) install can contain some of
    # the libraries that we're going to build. However, they may be compiled
    # with a MACOSX_DEPLOYMENT_TARGET that doesn't match what we want to use,
    # and they may bring in other dependencies that we don't want. The same will
    # be true of any other locations on the path. To avoid conflicts, strip the
    # path down to the bare minimum (which, on macOS, won't include any
    # development dependencies).
    export PATH="$BUILD_PREFIX/bin:$(dirname $(which python3)):/usr/bin:/bin:/usr/sbin:/sbin:/Library/Apple/usr/bin"
    export CMAKE_PREFIX_PATH=$BUILD_PREFIX

    # Ensure the basic structure of the build prefix directory exists.
    mkdir -p "$BUILD_PREFIX/bin"
    mkdir -p "$BUILD_PREFIX/lib"

    # Ensure pkg-config is available
    build_pkg_config
    # Ensure cmake is available
    python3 -m pip install cmake
fi

# Perform all dependency builds in the build subfolder.
mkdir -p $WORKDIR
pushd $WORKDIR > /dev/null

wrap_wheel_builder build

# Return to the project root to finish the build
popd > /dev/null
