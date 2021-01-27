#!/bin/bash
set -eo pipefail

if uname -s | grep -q Darwin; then
    $(dirname $0)/macos-install.sh
else
    $(dirname $0)/linux-install.sh
fi
