#!/usr/bin/env bash
#
# build-staging.sh calls build.sh's build method for the staging environment
source build.sh
build staging "${1:-}"
