# Used by multibuild for building wheels
set -eo pipefail

ARCHIVE_SDIR=pillow-avif-plugin-depends
LIBAVIF_SHA=e86e59f

function install_meson {
    echo "::group::Install meson"
    if [ -n "$IS_MACOS" ]; then
        brew install meson
    else
        if [ "$PYTHON_VERSION" == "2.7" ]; then
            local python39_exe=$(cpython_path 3.9)/bin/python
            $python39_exe -m pip install meson
            local meson_exe=$(dirname $python39_exe)/meson
            if [ "$(id -u)" != "0" ]; then
                sudo ln -s $meson_exe /usr/local/bin
            else
                ln -s $meson_exe /usr/local/bin
            fi
        else
            $PYTHON_EXE -m pip install meson
        fi
    fi
    echo "::endgroup::"
}

function install_ninja {
    echo "::group::Install ninja"
    $PYTHON_EXE -m pip install ninja
    local ninja_exe=$(dirname $PYTHON_EXE)/ninja
    ln -s $ninja_exe /usr/local/bin/ninja-build
    echo "::endgroup::"
}

function install_rust {
    echo "::group::Install rust"
    curl https://sh.rustup.rs -sSf | /bin/sh -s -- -y
    echo "::endgroup::"
}

function build_libavif {
    local depends_dir="$REPO_DIR/depends"
    local libavif_dir="$depends_dir/libavif-$LIBAVIF_SHA"
    local libavif_build_dir="$libavif_dir/build"
    if [ ! -d $libavif_build_dir ]; then
        echo "::group::Setup libavif build"
        set -x
        if [ -e $ARCHIVE_SDIR/libavif-ext-$LIBAVIF_SHA.tar.gz ]; then
            mkdir -p $libavif_dir/ext
            tar -C $libavif_dir/ext -zxf $ARCHIVE_SDIR/libavif-ext-$LIBAVIF_SHA.tar.gz
        fi
        LIBAVIF_CARGO_VENDOR_TGZ=$ARCHIVE_SDIR/libavif-rav1e-cargo-vendor-$LIBAVIF_SHA.tar.gz
        if [ -e $LIBAVIF_CARGO_VENDOR_TGZ ] && [ -e "$HOME/.cargo" ]; then
            tar -C $ARCHIVE_SDIR -zxf $LIBAVIF_CARGO_VENDOR_TGZ
            VENDOR_DIR=$(pwd -P)/$ARCHIVE_SDIR/vendor
            cat > ~/.cargo/config <<EOF
[source.crates-io]
replace-with = "vendored-sources"

[source.vendored-sources]
directory = "$VENDOR_DIR"
EOF
        fi
        pushd $depends_dir
        ./install_libavif.sh
        popd > /dev/null
        set +x
        echo "::endgroup::"
    fi
    echo "::group::Install libavif"
    pushd $libavif_build_dir
    make install
    popd
    echo "::endgroup::"
}

function build_nasm {
    echo "::group::Build nasm"
    build_simple nasm 2.15.05 https://www.nasm.us/pub/nasm/releasebuilds/2.15.05/
    echo "::endgroup::"
}

function install_cmake {
    echo "::group::Install cmake"
    if [ -n "$IS_MACOS" ]; then
        brew install cmake
    else
        $PYTHON_EXE -m pip install cmake
    fi
    echo "::endgroup::"
}

function install_zlib {
    if [ ! -n "$IS_MACOS" ]; then
        echo "::group::Install zlib"
        build_zlib
        echo "::endgroup::"
    fi
}

function ensure_openssl {
    if [ ! -n "$IS_MACOS" ]; then
        echo "::group::Install openssl"
        yum_install openssl-devel
        echo "::endgroup::"
    fi
}

function ensure_sudo {
    if [ ! -e /usr/bin/sudo ]; then
        echo "::group::Install sudo"
        yum_install sudo
        echo "::endgroup::"
    fi
}

function append_licenses {
    echo "::group::Append licenses"
    for filename in $REPO_DIR/wheelbuild/dependency_licenses/*.txt; do
      echo -e "\n\n----\n\n$(basename $filename | cut -f 1 -d '.')\n" | cat >> $REPO_DIR/LICENSE
      cat $filename >> $REPO_DIR/LICENSE
    done
    echo -e "\n\n" | cat >> $REPO_DIR/LICENSE
    cat $REPO_DIR/wheelbuild/dependency_licenses/PATENTS >> $REPO_DIR/LICENSE
    echo "::endgroup::"
}

function pre_build {
    echo "::endgroup::"

    append_licenses
    ensure_sudo
    ensure_openssl
    install_zlib

    local libavif_build_dir="$REPO_DIR/depends/libavif-$LIBAVIF_SHA/build"

    if [ ! -e "$libavif_build_dir" ]; then
        build_nasm
        install_cmake
        install_ninja
        install_meson

        # rustup is incompatible with the glibc on el5
        if [ "$MB_ML_VER" != "1" ]; then
            install_rust
            source $HOME/.cargo/env
        fi
    fi

    build_libavif

    echo "::group::Build wheel"
}

function run_tests {
    if [ "$PYTHON_VERSION" == "2.7" ]; then
        $PYTHON_EXE -m pip install mock
    fi
    # Runs tests on installed distribution from an empty directory
    (cd ../pillow-avif-plugin && pytest)
}
