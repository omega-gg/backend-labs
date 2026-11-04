#!/bin/sh
set -e

# Builds clientVBML in build/ci on Windows, and puts the result in build/ci/bin. It takes a while
# the first time, because it downloads Qt and the other dependencies.

#--------------------------------------------------------------------------------------------------
# Settings
#--------------------------------------------------------------------------------------------------

root=$(dirname "$(dirname "$(readlink -f "$0")")")

platform="win64"

#--------------------------------------------------------------------------------------------------
# Build
#--------------------------------------------------------------------------------------------------

mkdir -p "$root/build/ci"

cd "$root/build/ci"

if [ ! -d clientVBML ]; then

    git clone --depth 1 https://github.com/omega-gg/clientVBML
else
    git -C clientVBML pull

    git -C Sky pull
fi

cd clientVBML

# NOTE: This clones Sky and 3rdparty next to clientVBML.
sh 3rdparty.sh $platform all

cd ../Sky

sh configure.sh $platform

sh build.sh $platform tools

cd ../clientVBML

sh configure.sh $platform

# NOTE: We don't want 'all' or 'deploy' here, a deploy build gets its backends from GitHub.
sh build.sh $platform

#--------------------------------------------------------------------------------------------------
# Deploy
#--------------------------------------------------------------------------------------------------

# NOTE: This way the folder works on its own and can be cached.
Qt=$(ls -d ../3rdparty/$platform/Qt/*/ | tail -1)

bin=../bin

mkdir -p $bin/tls

cp bin/* $bin 2> /dev/null || true

cp "$Qt"bin/Qt6Core.dll        $bin
cp "$Qt"bin/Qt6Core5Compat.dll $bin
cp "$Qt"bin/Qt6Network.dll     $bin
cp "$Qt"bin/Qt6Qml.dll         $bin
cp "$Qt"bin/Qt6Xml.dll         $bin

cp "$Qt"plugins/tls/qopensslbackend.dll  $bin/tls
cp "$Qt"plugins/tls/qschannelbackend.dll $bin/tls
