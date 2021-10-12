#!/bin/bash

set -e

brew install dav1d aom rav1e

if [ "$GHA_PYTHON_VERSION" == "2.7" ]; then
    python2 -m pip install -U tox tox-gh-actions
else
    python3 -m pip install -U tox tox-gh-actions
fi

# libavif
if [ ! -d depends/libavif-$LIBAVIF_VERSION ]; then
    pushd depends && ./install_libavif.sh && popd
fi
pushd depends/libavif-$LIBAVIF_VERSION/build
make install
popd
