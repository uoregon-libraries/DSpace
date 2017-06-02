#!/usr/bin/env bash
#
# deploy.sh assumes this repo is self-contained and doesn't need to sync the UI
# elements from elsewhere.  The production.properties file is copied over
# build.properties and the build is run as per DSpace instructions.
#
# This doesn't rely on build.sh at all because production deployment needs to
# avoid copying theme files around, and needs to be more precise about maven
# and ant commands.
set -eux

dt=$(date +"%Y%m%d-%H%M")

run_maven() {
  local cmd="mvn package -Dmirage2.on=true -X"
  local log="/var/log/dspace-build-mvn-$dt"
  local dest=$(pwd)

  echo "Running $cmd - logging output to $log"
  su -l dspace -c "cd $dest && $cmd" > $log
}

run_ant() {
  local cmd="ant update"
  local log="/var/log/dspace-build-ant-$dt"
  local dest=$(pwd)

  echo "Running $cmd - logging output to $log"
  su -l dspace -c "cd $dest/dspace/target/dspace-installer && $cmd" > $log
}

if [ "$EUID" != "0" ]; then
  echo "This script must be run as root"
  exit 1
fi

for dir in $(find $(pwd) -type d -name "target"); do rm -rf $dir; done

propfile=./production.properties
if [ ! -e $propfile ]; then
  echo "ERROR: Missing production.properties"
  echo
  echo "Copy the sample file (cp ./build.properties.sample $propfile) and edit"
  echo "as necessary, then run deploy.sh again"
fi
cp $propfile ./build.properties

run_maven
systemctl stop tomcat
run_ant
systemctl start tomcat

echo "Deploy complete"
