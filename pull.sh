#!/bin/sh
set -e

# Updates the reference projects, and reports the changes to the files that define the YouTube
# clients. A change there often means a client stopped working.

#--------------------------------------------------------------------------------------------------
# Settings
#--------------------------------------------------------------------------------------------------

root=$(dirname "$(readlink -f "$0")")

#--------------------------------------------------------------------------------------------------
# Functions
#--------------------------------------------------------------------------------------------------

pull()
{
    repository="$root/reference/$1"

    shift

    echo "--- $(basename "$repository") ---"

    old=$(git -C "$repository" rev-parse HEAD)

    git -C "$repository" pull --quiet --ff-only

    echo "$(git -C "$repository" rev-list --count "$old..HEAD") new commits"

    git -C "$repository" --no-pager log --oneline "$old..HEAD" -- "$@"
}

#--------------------------------------------------------------------------------------------------
# Pull
#--------------------------------------------------------------------------------------------------

pull yt-dlp yt_dlp/extractor/youtube/_base.py yt_dlp/extractor/youtube/_video.py

pull NewPipeExtractor \
     extractor/src/main/java/org/schabi/newpipe/extractor/services/youtube/ClientsConstants.java

pull YoutubeExplode YoutubeExplode/Videos/VideoController.cs
