#!/usr/bin/env bash
#
# sync-repo.sh rsyncs from a given source mirage2 dev location to this repo to
# prepare for a git commit

set -eu

# Verify command-line usage
dspace_source=${1:-}
if [ "$dspace_source" == "" ]; then
  echo "Usage: ./sync-repo.sh [path to development webapps directory]"
  echo
  echo "Example:"
  echo "    ./sync-repo.sh /usr/local/dspace/webapps"
  exit 1
fi

# Set up theme directory vars
theme_source=$dspace_source/xmlui/themes/Mirage2
dest=$(pwd)
repo_dest=$dest/dspace-xmlui-mirage2/src/main/webapp

if [ ! -d $theme_source ]; then
  echo "Unable to find theme source directory $theme_source"
  exit 1
fi
if [ ! -d $repo_dest ]; then
  echo "Unable to find repo destination directory $repo_dest"
  exit 1
fi

echo "Pulling theme files from $theme_source to $repo_dest"

# Make sure all rsyncs do the same stuff
commonargs="-rltD --delete"
rsync $commonargs $theme_source/styles/  $repo_dest/styles/
rsync $commonargs $theme_source/xsl/     $repo_dest/xsl/
rsync $commonargs $theme_source/images/  $repo_dest/images/
