#!/usr/bin/env bash
#
# build-dev.sh calls build.sh's build method for the dev environment
source build.sh
build dev "${1:-}"
