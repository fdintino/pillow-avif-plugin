#!/bin/bash
# Define custom utilities
# Test for macOS with [ -n "$IS_MACOS" ]
if [ -z "$IS_MACOS" ]; then
    export MB_ML_LIBC=${AUDITWHEEL_POLICY::9}
    export MB_ML_VER=${AUDITWHEEL_POLICY:9}
fi
export PLAT=$CIBW_ARCHS
source multibuild/common_utils.sh
source multibuild/library_builders.sh
if [ -z "$IS_MACOS" ]; then
    source multibuild/manylinux_utils.sh
fi

source wheelbuild/config.sh

function build {
    if [[ -n "$IS_MACOS" ]] && [[ "$CIBW_ARCHS" == "arm64" ]]; then
        sudo chown -R runner /usr/local
    fi
    pre_build
}

wrap_wheel_builder build
