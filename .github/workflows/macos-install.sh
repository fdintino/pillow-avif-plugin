#!/bin/bash

set -e

brew install dav1d aom rav1e

if [ "$GHA_PYTHON_VERSION" == "2.7" ]; then
    python2 -m pip install -U tox tox-gh-actions
else
    python3 -m pip install -U tox tox-gh-actions
fi

# TODO Remove when 3.8 / 3.9 includes setuptools 49.3.2+:
if [ "$GHA_PYTHON_VERSION" == "3.8" ]; then python3 -m pip install -U "setuptools>=49.3.2" ; fi
if [ "$GHA_PYTHON_VERSION" == "3.9" ]; then python3 -m pip install -U "setuptools>=49.3.2" ; fi

# libavif
if [ ! -d depends/libavif-$LIBAVIF_VERSION ]; then
    pushd depends && ./install_libavif.sh && popd
fi
pushd depends/libavif-$LIBAVIF_VERSION/build
make install
popd
