#!/usr/bin/env bash
set -eu

usage() {
  echo "Usage: $0 <path to dspace>"
  echo
  echo "Builds the dspace-api module and replaces all classes in the JAR file"
  echo
  echo "Example:"
  echo "    sudo -E ./makejar.sh /usr/local/dspace"
  exit 1
}

verify_root() {
  if [[ $EUID != "0" ]]; then
    echo "This script must be run as root"
    echo
    usage
  fi
}

verify_dspacedir() {
  if [[ $dspacedir == "" ]]; then
    echo "You must specify the DSpace directory"
    echo
    usage
  fi

  if [[ ! -d $dspacedir ]]; then
    echo "ERROR: $dspacedir does not seem to be a valid directory"
    echo
    usage
  fi

  if [[ ! -f $jarfile ]]; then
    echo "ERROR: unable to find JAR file $jarfile"
    echo "You must already have DSpace installed for this to work!"
    echo
    usage
  fi
}

dspacedir=${1:-}
jarfile="$dspacedir/lib/dspace-api-5.4.jar"
cwd=$PWD

# Try to get the original user so this script can be run by anybody with sudo
# without mucking up permissions in their target/ dir
user=${SUDO_USER:-}
user=${user:-$USER}

verify_root
verify_dspacedir

su -l $user -c "cd $cwd && mvn compile"
su -l dspace -c "cd $cwd/target/classes && jar uf $dspacedir/lib/dspace-api-5.4.jar org/"
