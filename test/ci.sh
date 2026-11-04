#!/bin/sh
set -e

# Runs what the CI runs, on Windows. It builds clientVBML when clientVBML or Sky changed, and
# compares the results with the CI baseline.
#
# Usage: sh ci.sh [extract | stream | throttle] [branch of the backend repository]
#        sh ci.sh measure

#--------------------------------------------------------------------------------------------------
# Settings
#--------------------------------------------------------------------------------------------------

root=$(dirname "$(dirname "$(readlink -f "$0")")")

level=${1:-extract}

branch=${2:-master}

source="https://github.com/omega-gg"

cd "$root"

#--------------------------------------------------------------------------------------------------
# Measure
#--------------------------------------------------------------------------------------------------

# NOTE: This tells how YouTube treats the network we are on, it needs no build.
if [ "$level" = "measure" ]; then

    sh test/measure-youtube.sh

    exit 0
fi

#--------------------------------------------------------------------------------------------------
# clientVBML
#--------------------------------------------------------------------------------------------------

version="$(git ls-remote $source/clientVBML HEAD | cut -f1) $(git ls-remote $source/Sky HEAD | cut -f1)"

if [ "$(cat build/ci/bin/version 2> /dev/null)" != "$version" ]; then

    sh test/build-client.sh

    echo "$version" > build/ci/bin/version
fi

#--------------------------------------------------------------------------------------------------
# Backends
#--------------------------------------------------------------------------------------------------

if [ ! -d vbml ]; then

    git clone --depth 1 --branch "$branch" $source/backend vbml
fi

#--------------------------------------------------------------------------------------------------
# ffprobe
#--------------------------------------------------------------------------------------------------

if [ "$level" != "extract" ] && ! command -v ffprobe > /dev/null; then

    choco install ffmpeg --no-progress -y

    PATH="$PATH:/c/ProgramData/chocolatey/bin"
fi

#--------------------------------------------------------------------------------------------------
# Tests
#--------------------------------------------------------------------------------------------------

CLIENT_BIN="$root/build/ci/bin" BASELINE="$root/test/baseline-ci.tsv" sh test/all.sh "$level"
