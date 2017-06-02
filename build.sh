#!/usr/bin/env bash
#
# build.sh holds all the common functions needed for build-[env].sh scripts to
# rsync from a given source mirage2 dev location to this repo's theme
# destination, copies [env].properties (which is kept out of the repository),
# then builds dspace. This must be run as root.  [env] can be anything for
# which a properties file exists.

set -eu

usage() {
  echo "Usage: $0 [path to development webapps directory]"
  echo
  echo "Example:"
  echo "    sudo -E $0 /usr/local/dspace/webapps"
  exit 1
}

verify_root() {
  if [ "$EUID" != "0" ]; then
    echo "This script must be run as root"
    echo
    usage
  fi
}

get_dspace_source() {
  dspace_source=${1:-}
  if [ "$dspace_source" == "" ]; then
    echo "No DSpace source specified"
    echo
    usage
  fi
}

copy_properties_file() {
  local propfile="./${target_env}.properties"
  if [ ! -e $propfile ]; then
    echo "ERROR: Missing environment properties file ($propfile):"
    echo
    echo "    cp ./build.properties.sample $propfile"
    echo "    vim $propfile"
    exit 1
  fi
  cp $propfile ./build.properties
}

get_dir_args() {
  theme_source=$dspace_source/xmlui/themes/Mirage2
  dest=$(pwd)
  theme_dest=$dest/dspace/modules/xmlui-mirage2/src/main/webapp/themes/Mirage2
  rm -rf $theme_dest
  mkdir -p $theme_dest

  if [ ! -d $theme_source ]; then
    echo "Unable to find theme source directory $theme_source"
    exit 1
  fi
  if [ ! -d $theme_dest ]; then
    echo "Unable to find theme destination directory $theme_dest"
    exit 1
  fi
}

copy_theme_files() {
  # Make sure all rsyncs do the same stuff
  local commonargs="-rltD --delete"
  rsync $commonargs $theme_source/styles/  $theme_dest/styles/
  rsync $commonargs $theme_source/xsl/     $theme_dest/xsl/
  rsync $commonargs $theme_source/images/  $theme_dest/images/
}

run_maven() {
  local cmd="mvn package -X -Dmirage2.on=true"
  local log="/var/log/dspace-build-mvn-$(date +"%Y%m%d-%H%M%S")"

  echo "Running $cmd - logging output to $log"
  su -l dspace -c "cd $dest && $cmd" > $log
}

run_ant() {
  local cmd="ant update"
  local log="/var/log/dspace-build-ant-$(date +"%Y%m%d-%H%M%S")"

  echo "Running $cmd - logging output to $log"
  su -l dspace -c "cd $dest/dspace/target/dspace-installer && $cmd" > $log
}

build() {
  target_env=$1
  verify_root
  get_dspace_source "${2:-}"
  for dir in $(find $(pwd) -type d -name "target"); do rm -rf $dir; done
  copy_properties_file
  get_dir_args

  echo "Pulling theme files from $theme_source to $theme_dest"
  copy_theme_files

  run_maven

  echo "Stopping tomcat"
  systemctl stop tomcat

  run_ant

  echo "Starting tomcat"
  systemctl start tomcat
}
