#!/usr/bin/env bash
set -eu

dspacedir=${1:-}

if [[ $dspacedir == "" ]]; then
  echo "You must specify the DSpace directory; e.g., ./makejar.sh /usr/local/dspace"
fi

mvn compile
pushd >/dev/null
cd target/classes
sudo -l dspace -c "jar uf /usr/local/dspace-staging/lib/dspace-api-5.4.jar org/"
popd
