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
theme_dest=$dest/dspace-xmlui-mirage2/src/main/webapp

if [ ! -d $theme_source ]; then
  echo "Unable to find theme source directory $theme_source"
  exit 1
fi
if [ ! -d $theme_dest ]; then
  echo "Unable to find theme destination directory $theme_dest"
  exit 1
fi

echo "Pulling theme files from $theme_source to $theme_dest"
rsync -a --delete $theme_source/styles/  $theme_dest/styles/
rsync -a --delete $theme_source/xsl/     $theme_dest/xsl/
rsync -a --delete $theme_source/images/  $theme_dest/images/

cmd="mvn package -Dmirage2.on=true -Dmirage2.deps.included=false"
echo "Running: $cmd"
su -l dspace -c "cd $dest && source /etc/profile.d/rvm.sh && $cmd"
