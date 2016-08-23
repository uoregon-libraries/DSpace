#!/usr/bin/env bash
#
# build-staging.sh rsyncs from a given source mirage2 dev location to this
# repo's theme destination, copies staging.properties (which is kept out of the
# repository), then builds dspace. This must be run as root.

set -eu

# Verify staging.properties and copy it
if [ ! -e ./staging.properties ]; then
  echo "You must create and customize staging.properties before running this"
  echo
  echo "    cp ./build.properties.sample ./staging.properties"
  echo "    vim ./staging.properties"
  exit 1
fi

cp staging.properties build.properties

# Verify superuser
if [ "$EUID" != "0" ]; then
  echo "This script must be run as root"
  exit 1
fi

# Verify command-line usage
dspace_source=${1:-}
if [ "$dspace_source" == "" ]; then
  echo "Usage: ./build-staging.sh [path to development webapps directory]"
  echo
  echo "Example:"
  echo "    sudo -E ./build-staging.sh /usr/local/dspace/webapps"
  exit 1
fi

# Set up theme directory vars
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

echo "Pulling theme files from $theme_source to $theme_dest"

# Make sure all rsyncs do the same stuff
commonargs="-rltD --delete"
rsync $commonargs $theme_source/styles/  $theme_dest/styles/
rsync $commonargs $theme_source/xsl/     $theme_dest/xsl/
rsync $commonargs $theme_source/images/  $theme_dest/images/

echo "Stopping tomcat"
systemctl stop tomcat

cmd="mvn package -Dmirage2.on=true -Dmirage2.deps.included=false"
log="/var/log/dspace-build-mvn-$(date +"%s")"

echo "Running $cmd - logging output to $log"
su -l dspace -c "cd $dest && source /etc/profile.d/rvm.sh && $cmd" > $log

cmd="ant update"
log="/var/log/dspace-build-ant-$(date +"%s")"

echo "Running $cmd - logging output to $log"
su -l dspace -c "cd $dest/dspace/target/dspace-installer && $cmd" > $log

echo "Starting tomcat"
systemctl start tomcat
