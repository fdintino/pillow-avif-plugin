#!/bin/bash

set -e

# See https://github.com/actions/runner-images/issues/9471 for why we have
# brew unlink and brew link commands here
brew unlink cmake || true
brew reinstall cmake || true
brew link --overwrite cmake

brew install dav1d aom rav1e

if [ "$GHA_PYTHON_VERSION" == "2.7" ]; then
    python2 -m pip install -U tox tox-gh-actions
else
    python3 -m pip install -U 'tox<4' tox-gh-actions
fi

# libavif
if [ ! -d depends/libavif-$LIBAVIF_VERSION ]; then
    pushd depends && ./install_libavif.sh && popd
fi
pushd depends/libavif-$LIBAVIF_VERSION/build
make install
popd
