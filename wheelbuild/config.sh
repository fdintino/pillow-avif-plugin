# Used by multibuild for building wheels
set -eo pipefail

CONFIG_DIR=$(abspath $(dirname "${BASH_SOURCE[0]}"))

ARCHIVE_SDIR=pillow-avif-plugin-depends
LIBAVIF_VERSION=1.2.1
RAV1E_VERSION=0.7.1
CCACHE_VERSION=4.10.2
SCCACHE_VERSION=0.10.0
export PERLBREWURL=https://raw.githubusercontent.com/gugod/App-perlbrew/release-0.92/perlbrew
export GITHUB_ACTIONS=1
export PYTHON_EXE="${PYTHON_EXE:-python}"
export REPO_DIR=$(dirname $CONFIG_DIR)

export PLAT="${AUDITWHEEL_ARCH:-${CIBW_ARCHS:-${PLAT}}}"

# Convenience functions to run shell commands suppressed from "set -x" tracing
shopt -s expand_aliases
alias trace_on='{ set -x; } 2>/dev/null'
alias trace_off='{ set +x; } 2>/dev/null'
alias trace_suppress='{ [[ $- =~ .*x.* ]] && trace_enabled=1 || trace_enabled=0; set +x; } 2>/dev/null'
alias trace_restore='{ [ $trace_enabled -eq 1 ] && trace_on || trace_off; } 2>/dev/null'

if [ -n "$IS_MACOS" ] && [ -n "$MACOSX_DEPLOYMENT_TARGET" ]; then
    CFLAGS="${CFLAGS} -mmacosx-version-min=$MACOSX_DEPLOYMENT_TARGET"
    LDFLAGS="${LDFLAGS} -mmacosx-version-min=$MACOSX_DEPLOYMENT_TARGET"
fi

# Temporarily use old linker on macOS arm64. This fixes a bizarre bug where
# an invalid instruction is being inserted into the middle of the libaom
# function compute_stats_win5_neon
if [ -n "$IS_MACOS" ] && [ "$PLAT" == "arm64" ]; then
    export LDFLAGS="${LDFLAGS} -ld64"
fi

mkdir -p "$BUILD_PREFIX/bin"
export PATH="$PATH:$BUILD_PREFIX/bin"

call_and_restore_trace() {
    local rc
    local force_trace
    if [[ "$1" == "-x" ]]; then
      force_trace=1
      shift
    fi
    "$@"
    rc=$?
    [ -n "$force_trace" ] && trace_on || trace_restore
    { return $rc; } 2>/dev/null
}
alias echo='trace_suppress; call_and_restore_trace builtin echo'

function echo_if_gha() {
  [ -n "$GITHUB_ACTIONS" ] && builtin echo "$@" || true
}

GHA_ACTIVE_GROUP=""
function __group_start_ {
  local was_active_group="$GHA_ACTIVE_GROUP"
  [ -n "$GHA_ACTIVE_GROUP" ] && echo_if_gha "::endgroup::" ||:
  GHA_ACTIVE_GROUP="1"
  echo_if_gha -n "::group::"
}

alias group_start='trace_suppress; __group_start_; call_and_restore_trace -x echo_if_gha'

function __group_end_ {
  ACTIVE_GROUP=""
  echo_if_gha "::endgroup::"
  trace_off
}

alias group_end='trace_suppress; __group_end_'


# If we're running in GitHub Actions, then send redirect stderr to
# stdout to ensure that they are interleaved correctly
if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
  exec 2>&1
fi

function require_package {
    local pkg=$1
    local pkgconfig=${PKGCONFIG:-pkg-config}
    if ! $pkgconfig --exists $pkg; then
        echo "$pkg failed to build"
        exit 1
    fi
}

function install_ccache {
    if [[ $(type -P ccache) ]]; then
        return
    fi
    mkdir -p $PWD/ccache
    if [ -e /parent-home ]; then
        ln -s $PWD/ccache /parent-home/.ccache
    fi
    if [ ! -e $HOME/.ccache ]; then
        ln -s $PWD/ccache $HOME/.ccache
    fi

    group_start "Install ccache"
    if [ -n "$IS_MACOS" ]; then
        local base_url="https://github.com/ccache/ccache/releases/download/v$CCACHE_VERSION"
        local archive_name="ccache-${CCACHE_VERSION}-darwin"
        fetch_unpack "${base_url}/${archive_name}.tar.gz"
        if [ -e "$archive_name/ccache" ]; then
            sudo cp "$archive_name/ccache" "/usr/local/bin/ccache"
            sudo chmod +x /usr/local/bin/ccache
        fi
        export CCACHE_CPP2=1
    elif [[ "$PLAT" == "x86_64" ]] && [[ $MB_ML_VER == "2014" ]]; then
        local base_url="https://github.com/ccache/ccache/releases/download/v$CCACHE_VERSION"
        local archive_name="ccache-${CCACHE_VERSION}-linux-x86_64"
        fetch_unpack "${base_url}/${archive_name}.tar.xz"
        if [ -e "$archive_name/ccache" ]; then
            cp "$archive_name/ccache" "/usr/local/bin/ccache"
            chmod +x /usr/local/bin/ccache
        fi
    elif [ -n "$IS_ALPINE" ]; then
        suppress apk add ccache
    else
        if [[ $MB_ML_VER == "_2_24" ]]; then
            # debian:9 based distro
            suppress apt-get install -y ccache
        elif [[ $MB_ML_VER == "2014" ]] && [[ "$PLAT" == "i686" ]]; then
            # There is no ccache rpm for el7.i686, but the one from EPEL 6 works fine
            yum install -y https://archives.fedoraproject.org/pub/archive/epel/6/i386/Packages/c/ccache-3.1.6-2.el6.i686.rpm
        else
            # centos based distro
            suppress yum_install epel-release
            suppress yum_install ccache
        fi
    fi
    group_end
}

function install_sccache {
    if [[ $(type -P sccache) ]]; then
        return
    fi
    group_start "Install sccache"
    local base_url="https://github.com/mozilla/sccache/releases/download/v$SCCACHE_VERSION"

    if [ -n "$IS_MACOS" ] && [ ! -e /usr/local/bin/sccache ]; then
        if [ "$PLAT" == "arm64" ]; then
            local archive_name="sccache-v${SCCACHE_VERSION}-aarch64-apple-darwin"
        else
            local archive_name="sccache-v${SCCACHE_VERSION}-x86_64-apple-darwin"
        fi
        fetch_unpack "${base_url}/${archive_name}.tar.gz"
        if [ -e "$archive_name/sccache" ]; then
            mkdir -p "$BUILD_PREFIX/bin"
            cp "$archive_name/sccache" "$BUILD_PREFIX/bin/sccache"
            chmod +x $BUILD_PREFIX/bin/sccache
            export USE_SCCACHE=1
            export SCCACHE_DIR=$PWD/sccache
        fi

    elif [ ! -e $BUILD_PREFIX/bin/sccache ]; then
        local archive_name="sccache-v${SCCACHE_VERSION}-${PLAT}-unknown-linux-musl"
        fetch_unpack "${base_url}/${archive_name}.tar.gz"
        if [ -e "$archive_name/sccache" ]; then
            mkdir -p "$BUILD_PREFIX/bin"
            cp "$archive_name/sccache" "$BUILD_PREFIX/bin/sccache"
            chmod +x $BUILD_PREFIX/bin/sccache
            export USE_SCCACHE=1
            export SCCACHE_DIR=$PWD/sccache
        fi
    fi
    group_end
}

function install_meson {
    if [ -e meson-stamp ]; then return; fi

    install_ninja

    group_start "Install meson"

    if [ -n "$IS_MACOS" ] && [ "$MB_PYTHON_VERSION" == "2.7" ]; then
        if [[ "$(uname -m)" == "x86_64" ]]; then
            HOMEBREW_PREFIX=/usr/local
        else
            HOMEBREW_PREFIX=/opt/homebrew
        fi
        $HOMEBREW_PREFIX/bin/brew install meson
        if [ ! -e $BUILD_PREFIX/bin/meson ]; then
            ln -s $HOMEBREW_PREFIX/bin/meson $BUILD_PREFIX/bin
        fi
    elif [ "$MB_PYTHON_VERSION" == "2.7" ]; then
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
    group_end

    touch meson-stamp
}

function install_ninja {
    if [ -e ninja-stamp ]; then return; fi

    group_start "Install ninja"

    if [ -n "$IS_MACOS" ]; then
        if [[ "$(uname -m)" == "x86_64" ]]; then
            HOMEBREW_PREFIX=/usr/local
        else
            HOMEBREW_PREFIX=/opt/homebrew
        fi
        $HOMEBREW_PREFIX/bin/brew install ninja
        if [ ! -e $BUILD_PREFIX/bin/ninja ]; then
            ln -s $HOMEBREW_PREFIX/bin/ninja $BUILD_PREFIX/bin
        fi
    else
        $PYTHON_EXE -m pip install ninja==1.11.1
        local ninja_exe=$(dirname $PYTHON_EXE)/ninja
        ln -s $ninja_exe /usr/local/bin/ninja-build
    fi

    group_end
    touch ninja-stamp
}

function build_rav1e {
    if [ -n "$IS_MACOS" ] && [ "$PLAT" == "arm64" ]; then
        librav1e_tgz=librav1e-${RAV1E_VERSION}-macos-aarch64.tar.gz
    elif [ -n "$IS_MACOS" ]; then
        librav1e_tgz=librav1e-${RAV1E_VERSION}-macos.tar.gz
    elif [ "$PLAT" == "aarch64" ]; then
        librav1e_tgz=librav1e-${RAV1E_VERSION}-linux-aarch64.tar.gz
    elif [ "$PLAT" == "i686" ]; then
        librav1e_tgz=librav1e-${RAV1E_VERSION}-linux-i686.tar.gz
    elif [ "$PLAT" == "x86_64" ]; then
        librav1e_tgz=librav1e-${RAV1E_VERSION}-linux-generic.tar.gz
    else
        return
    fi

    group_start "Build rav1e"

    curl -sLo - \
        https://github.com/xiph/rav1e/releases/download/v$RAV1E_VERSION/$librav1e_tgz \
        | tar -C $BUILD_PREFIX --exclude LICENSE -zxf -

    if [ ! -n "$IS_MACOS" ]; then
        sed -i 's/-lgcc_s/-lgcc_eh/g' "${BUILD_PREFIX}/lib/pkgconfig/rav1e.pc"
        rm -rf $BUILD_PREFIX/lib/librav1e*.so
    else
        rm -rf $BUILD_PREFIX/lib/librav1e*.dylib
    fi

    require_package rav1e

    group_end
}

function build_libavif {
    LIBAVIF_CMAKE_FLAGS=()

    if [ -n "$IS_MACOS" ]; then
        for pkg in webp jpeg-xl aom composer gd imagemagick libavif libheif php; do
            brew remove --ignore-dependencies $pkg ||:
        done
    fi
    which cmake
    cmake --version
    if [ -n "$IS_MACOS" ] && [ "$PLAT" == "arm64" ]; then
        # SVT-AV1 NEON intrinsics require macOS 14
        local macos_ver=$(sw_vers --productVersion | sed 's/\.[.0-9]*//')
        if [ "$macos_ver" -gt "13" ]; then
            LIBAVIF_CMAKE_FLAGS+=(-DAVIF_CODEC_SVT=LOCAL)
        fi
    elif [ "$MB_ML_VER" != "1" ]; then
        LIBAVIF_CMAKE_FLAGS+=(-DAVIF_CODEC_SVT=LOCAL)
    fi

    build_rav1e

    # Force libavif to treat system rav1e as if it were local
    if [ -e $BUILD_PREFIX/lib/librav1e.a ]; then
        mkdir -p /tmp/cmake/Modules
        cat <<EOF > /tmp/cmake/Modules/Findrav1e.cmake
        add_library(rav1e::rav1e STATIC IMPORTED GLOBAL)
        set_target_properties(rav1e::rav1e PROPERTIES
            IMPORTED_LOCATION "$BUILD_PREFIX/lib/librav1e.a"
            AVIF_LOCAL ON
            INTERFACE_INCLUDE_DIRECTORIES "$BUILD_PREFIX/include/rav1e"
        )
EOF
        LIBAVIF_CMAKE_FLAGS+=(-DAVIF_CODEC_RAV1E=ON -DCMAKE_MODULE_PATH=/tmp/cmake/Modules)
    else
        curl https://sh.rustup.rs -sSf | sh -s -- -y
        . "$HOME/.cargo/env"

        if [ -n "$IS_MACOS" ] && [ "$PLAT" == "arm64" ] && [[ "$(uname -m)" != "arm64" ]]; then
            # When cross-compiling to arm64 on macOS, install rust aarch64 target
            rustup target add --toolchain stable-x86_64-apple-darwin aarch64-apple-darwin
        fi

        if [ -z "$IS_ALPINE" ] && [ -z "$SANITIZER" ] && [ -z "$IS_MACOS" ]; then
            yum install -y perl
            if [[ "$MB_ML_VER" == 2014 ]]; then
                yum install -y perl-IPC-Cmd
            fi
        fi
        LIBAVIF_CMAKE_FLAGS+=(-DAVIF_CODEC_RAV1E=LOCAL)
    fi

    if [ -n "$IS_MACOS" ]; then
        # Prevent cmake from using @rpath in install id, so that delocate can
        # find and bundle the libavif dylib
        LIBAVIF_CMAKE_FLAGS+=(\
            "-DCMAKE_INSTALL_NAME_DIR=$BUILD_PREFIX/lib" \
            -DCMAKE_MACOSX_RPATH=OFF)
        if [ "$PLAT" == "arm64" ]; then
            LIBAVIF_CMAKE_FLAGS+=(-DCMAKE_TOOLCHAIN_FILE=$CONFIG_DIR/toolchain-arm64-macos.cmake)
        fi
    fi
    if [[ $(type -P ccache) ]]; then
        LIBAVIF_CMAKE_FLAGS+=(\
            -DCMAKE_C_COMPILER_LAUNCHER=$(type -P ccache) \
            -DCMAKE_CXX_COMPILER_LAUNCHER=$(type -P ccache))
    fi

    group_start "Download libavif source"

    local libavif_archive="${LIBAVIF_VERSION}.tar.gz"
    if [[ "$LIBAVIF_VERSION" == *"."* ]]; then
        libavif_archive="v${libavif_archive}"
    fi

    local out_dir=$(fetch_unpack \
        "https://github.com/AOMediaCodec/libavif/archive/$libavif_archive" \
        "libavif-$LIBAVIF_VERSION.tar.gz")

    group_end

    if [[ $MB_ML_VER == "2010" ]]; then
        fetch_unpack https://storage.googleapis.com/aom-releases/libaom-3.8.1.tar.gz
        mv libaom-3.8.1 $out_dir/ext/aom
    fi

    group_start "Build libavif"

    mkdir -p $out_dir/build

    local build_type=MinSizeRel
    local lto=ON

    if [ -n "$IS_MACOS" ]; then
        lto=OFF
    elif [[ "$MB_ML_VER" == 2014 ]] && [[ "$PLAT" == "x86_64" ]]; then
        build_type=Release
    fi

    (cd $out_dir/build \
        && cmake .. \
            -G "Ninja" \
            -DCMAKE_INSTALL_PREFIX=$BUILD_PREFIX \
            -DCMAKE_INSTALL_LIBDIR=$BUILD_PREFIX/lib \
            -DCMAKE_INSTALL_NAME_DIR=$BUILD_PREFIX/lib \
            -DBUILD_SHARED_LIBS=ON \
            -DAVIF_LIBSHARPYUV=LOCAL \
            -DAVIF_LIBYUV=LOCAL \
            -DAVIF_CODEC_AOM=LOCAL \
            -DAVIF_CODEC_DAV1D=LOCAL \
            -DAVIF_CODEC_AOM_DECODE=OFF \
            -DCONFIG_AV1_HIGHBITDEPTH=0 \
            -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=$lto \
            -DCMAKE_BUILD_TYPE=$build_type \
            "${LIBAVIF_CMAKE_FLAGS[@]}" \
        && ninja -v install/strip)

    group_end
}

function build_nasm {
    group_start "Build nasm"
    local CC=$(type -P "${CC:-gcc}")
    local CXX=$(type -P "${CXX:-g++}")
    if [[ $(type -P ccache) ]]; then
        CC="$(type -P ccache) $CC"
        CXX="$(type -P ccache) $CXX"
    fi
    SCCACHE_DIR="$SCCACHE_DIR" CC="$CC" CXX="$CXX" build_simple nasm 2.16.01 https://gstreamer.freedesktop.org/src/mirror/ tar.xz
    group_end
}

function install_cmake {
    group_start "Install cmake"
    if [[ "$MB_ML_VER" == "1" ]]; then
        $PYTHON_EXE -m pip install 'cmake<3.23'
    elif [ "$MB_PYTHON_VERSION" == "2.7" ]; then
        $PYTHON_EXE -m pip install 'cmake==3.27.7'
    else
        $PYTHON_EXE -m pip install cmake
    fi
    group_end
}

function install_zlib {
    if [ ! -n "$IS_MACOS" ]; then
        group_start "Install zlib"
        build_zlib
        group_end
    fi
}

function build_openssl {
    if [ -e openssl-stamp ]; then return; fi
    group_start "Building openssl"
    if [[ "$MB_ML_VER" == "1" ]]; then
        # Install new Perl because OpenSSL configure scripts require > 5.10.0.
        curl -L http://cpanmin.us | perl - App::cpanminus
        cpanm File::Path
        cpanm parent
        curl -L https://install.perlbrew.pl | bash
        source $HOME/perl5/perlbrew/etc/bashrc
        perlbrew install -j 3 --notest perl-5.16.0
        perlbrew use perl-5.16.0
    fi
    fetch_unpack ${OPENSSL_DOWNLOAD_URL}/${OPENSSL_ROOT}.tar.gz
    check_sha256sum $ARCHIVE_SDIR/${OPENSSL_ROOT}.tar.gz ${OPENSSL_HASH}
    local CC=$(type -P "${CC:-gcc}")
    local CXX=$(type -P "${CXX:-g++}")
    if [[ $(type -P ccache) ]]; then
        CC="$(type -P ccache) $CC"
        CXX="$(type -P ccache) $CXX"
    fi
    (cd ${OPENSSL_ROOT} \
        && CC="$CC" CXX="$CXX" ./config no-ssl2 no-shared no-tests -fPIC --prefix=$BUILD_PREFIX \
        && SCCACHE_DIR="$SCCACHE_DIR" make -j4 \
        && make install_sw)
    touch openssl-stamp
    group_end
}

function ensure_openssl {
    if [ ! -n "$IS_MACOS" ]; then
        group_start "Install openssl"
        if [ -n "$IS_ALPINE" ]; then
            apk add openssl-dev
        elif [[ $MB_ML_VER == "_2_24" ]]; then
            apt-get install -y libssl-dev
        else
            yum_install openssl-devel
        fi
        group_end
    fi
}

function ensure_sudo {
    if [ ! -e /usr/bin/sudo ]; then
        group_start "Install sudo"
        if [ -n "$IS_ALPINE" ]; then
            apk add sudo
        elif [[ $MB_ML_VER == "_2_24" ]]; then
            apt-get install -y sudo
        else
            yum_install sudo
        fi
        group_end
    fi
}

function append_licenses {
    group_start "Append licenses"
    local prefix=""
    if [ -e "$REPO_DIR" ]; then
        pushd $REPO_DIR
    fi
    for filename in wheelbuild/dependency_licenses/*.txt; do
      echo -e "\n\n----\n\n$(basename $filename | cut -f 1 -d '.')\n" | cat >> LICENSE
      cat $filename >> LICENSE
    done
    echo -e "\n\n" | cat >> LICENSE
    cat wheelbuild/dependency_licenses/PATENTS >> LICENSE
    if [ -e "$REPO_DIR" ]; then
        popd
    fi
    group_end
}

function pre_build {
    echo "::endgroup::"

    if [ -e /etc/yum.repos.d/CentOS-Base.repo ]; then
        sed -i -e '/^mirrorlist=http:\/\/mirrorlist.centos.org\// { s/^/#/ ; T }' \
            -e '{ s/#baseurl=/baseurl=/ ; s/mirror\.centos\.org/vault.centos.org/ }' \
            /etc/yum.repos.d/CentOS-*.repo
        if [ "$PLAT" == "aarch64" ]; then
            sed -i -e '{ s/vault\.centos\.org\/centos/vault.centos.org\/altarch/ }' \
                /etc/yum.repos.d/CentOS-*.repo
        fi
    fi

    if [ "$MB_ML_VER" == "2010" ]; then
        yum install -y devtoolset-9-gcc-gfortran yum install devtoolset-9-gcc-c++
        export PATH=/opt/rh/devtoolset-9/root/usr/bin:$PATH
    fi

    if [ -n "$IS_MACOS" ]; then
        sudo mkdir -p /usr/local/lib
        sudo mkdir -p /usr/local/bin
        sudo chown -R $(id -u):$(id -g) /usr/local ||:
    fi

    append_licenses
    ensure_sudo
    ensure_openssl
    install_zlib
    install_sccache
    install_ccache

    if [ "$PLAT" == "x86_64" ] || [ "$PLAT" == "i686" ]; then
        build_nasm
    fi
    install_cmake
    install_ninja
    install_meson

    if [[ -n "$IS_MACOS" ]]; then
        # clear bash path cache for curl
        hash -d curl ||:
    fi

    if [ -e $HOME/.cargo/env ]; then
        source $HOME/.cargo/env
    fi

    build_libavif

    if [ -z "$CIBW_ARCHS" ]; then
        echo "::group::Build wheel"
    fi
}

function run_tests {
    if ! $PYTHON_EXE -m unittest.mock 2>&1 2>/dev/null; then
        $PYTHON_EXE -m pip install mock
    fi
    # Runs tests on installed distribution from an empty directory
    (cd ../pillow-avif-plugin && pytest -v)
}

# Work around flakiness of pip install with python 2.7
if [ "$MB_PYTHON_VERSION" == "2.7" ]; then
    function pip_install {
        if [ "$1" == "retry" ]; then
            shift
            echo ""
            echo Retrying pip install $@
        else
            echo Running pip install $@
        fi
        echo ""
        $PIP_CMD install $(pip_opts) $@
    }

    function install_run {
        if [ -n "$TEST_DEPENDS" ]; then
            while read TEST_DEPENDENCY; do
                pip_install $TEST_DEPENDENCY \
                    || pip_install retry $TEST_DEPENDENCY \
                    || pip_install retry $TEST_DEPENDENCY \
                    || pip_install retry $TEST_DEPENDENCY
            done <<< "$TEST_DEPENDS"
            TEST_DEPENDS=""
        fi

        install_wheel
        mkdir tmp_for_test
        (cd tmp_for_test && run_tests)
        rmdir tmp_for_test  2>/dev/null || echo "Cannot remove tmp_for_test"
    }
fi
