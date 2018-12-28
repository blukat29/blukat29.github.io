#!/bin/sh

# Please run:
#   curl -L blukat.me/config.sh | sh

set -ex

cd $HOME
git clone https://github.com/blukat29/blukat-config .blukat
cd .blukat

set +ex

echo 'Now run below command to finish.'
echo '  sh ~/.blukat/basic.sh'
