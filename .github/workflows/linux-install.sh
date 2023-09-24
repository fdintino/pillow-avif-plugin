#!/bin/bash

set -eo pipefail

aptget()
{
    if [ $(id -u) == 0 ]; then
        apt-get "$@"
    else
        sudo apt-get "$@"
    fi
}

aptget_update()
{
    if [ ! -z $1 ]; then
        echo ""
        echo "Retrying apt-get update..."
        echo ""
    fi
    output=`aptget update 2>&1`
    echo "$output"
    if [[ $output == *[WE]:\ * ]]; then
        return 1
    fi
}
aptget_update || aptget_update retry || aptget_update retry

set -e

aptget -qq install zlib1g-dev libpng-dev libjpeg-dev sudo \
    libxml2-dev libffi-dev libxslt-dev cmake ninja-build nasm

if [ "$GHA_PYTHON_VERSION" == "2.7" ]; then
    python2 -m pip install tox tox-gh-actions
    aptget install -y python3-pip
else
    python3 -m pip install 'tox<4' tox-gh-actions
fi

python3 -m pip install -U pip
python3 -m pip install -U wheel
python3 -m pip install setuptools wheel

export PATH="$HOME/.local/bin:$PATH"

# libavif
if [ ! -d depends/libavif-$LIBAVIF_VERSION ]; then
    pushd depends && ./install_libavif.sh && popd
fi
pushd depends/libavif-$LIBAVIF_VERSION/build
sudo make install
popd
