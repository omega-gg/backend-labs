#!/bin/sh
set -e

# Clones the reference projects, you only need them to read the public extractors.

#--------------------------------------------------------------------------------------------------
# Settings
#--------------------------------------------------------------------------------------------------

root=$(dirname "$(readlink -f "$0")")

#--------------------------------------------------------------------------------------------------
# Functions
#--------------------------------------------------------------------------------------------------

clone()
{
    if [ -e "$root/reference/$1" ]; then

        echo "$1: already there"
    else
        echo "$1: cloning"

        git clone --quiet "$2" "$root/reference/$1"
    fi
}

#--------------------------------------------------------------------------------------------------
# Clone
#--------------------------------------------------------------------------------------------------

clone yt-dlp https://github.com/yt-dlp/yt-dlp
clone NewPipeExtractor https://github.com/TeamNewPipe/NewPipeExtractor
clone YoutubeExplode https://github.com/Tyrrrz/YoutubeExplode
