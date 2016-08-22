#!/usr/bin/env bash
#
# build.sh rsyncs from a given source mirage2 dev location to this repo, then
# builds dspace packages.  This must be run as root.

set -eu

# Verify build.properties
if [ ! -f ./build.properties ]; then
  echo "You need to create and customize your build.properties file"
  echo
  echo "    cp ./build.properties.sample ./build.properties"
  echo "    vim ./build.properties"
  exit 1
fi

# Verify superuser
if [ "$EUID" != "0" ]; then
  echo "This script must be run as root"
  exit 1
fi

# Verify command-line usage
dspace_source=${1:-}
if [ "$dspace_source" == "" ]; then
  echo "Usage: ./build.sh [path to development webapps directory]"
  echo
  echo "Example:"
  echo "    sudo -E ./build.sh /usr/local/dspace/webapps"
  exit 1
fi

# Set up theme directory vars
theme_source=$dspace_source/xmlui/themes/Mirage2
dest=$(pwd)
repo_dest=$dest/dspace-xmlui-mirage2/src/main/webapp
theme_dest=$dest/dspace/modules/xmlui-mirage2/src/main/webapp/themes/Mirage2

if [ ! -d $theme_source ]; then
  echo "Unable to find theme source directory $theme_source"
  exit 1
fi
if [ ! -d $repo_dest ]; then
  echo "Unable to find repo destination directory $repo_dest"
  exit 1
fi
if [ ! -d $theme_dest ]; then
  echo "Unable to find theme destination directory $theme_dest"
  exit 1
fi

echo "Pulling theme files from $theme_source to $repo_dest"

# Make sure all rsyncs do the same stuff
commonargs="-rltD --delete"
rsync $commonargs $theme_source/styles/  $repo_dest/styles/
rsync $commonargs $theme_source/xsl/     $repo_dest/xsl/
rsync $commonargs $theme_source/images/  $repo_dest/images/

# Copy all theme files into the theme's empty directory
rsync $commonargs $theme_source/styles/  $theme_dest/styles/
rsync $commonargs $theme_source/xsl/     $theme_dest/xsl/
rsync $commonargs $theme_source/images/  $theme_dest/images/

cmd="mvn package -Dmirage2.on=true -Dmirage2.deps.included=false"
log="/var/log/dspace-build-mvn-$(date +"%s")"

echo "Running $cmd - logging output to $log"
su -l dspace -c "cd $dest && source /etc/profile.d/rvm.sh && $cmd" > $log

cmd="ant update"
log="/var/log/dspace-build-ant-$(date +"%s")"

echo "Running $cmd - logging output to $log"
su -l dspace -c "cd $dest/dspace/target/dspace-installer && $cmd" > $log

echo "Restarting tomcat"
systemctl stop tomcat
systemctl start tomcat
