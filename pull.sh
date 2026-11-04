#!/bin/sh
set -e

#--------------------------------------------------------------------------------------------------
# Settings
#--------------------------------------------------------------------------------------------------

root=$(dirname "$(readlink -f "$0")")

lock="# path url branch commit"

#--------------------------------------------------------------------------------------------------
# Functions
#--------------------------------------------------------------------------------------------------

# NOTE: The files that define the YouTube clients. A change here often means a client stopped
#       working, so we report it.
watched()
{
    case "$1" in
    reference/yt-dlp)
        echo "yt_dlp/extractor/youtube/_base.py yt_dlp/extractor/youtube/_video.py";;
    reference/NewPipeExtractor)
        echo "extractor/src/main/java/org/schabi/newpipe/extractor/services/youtube/ClientsConstants.java";;
    reference/YoutubeExplode)
        echo "YoutubeExplode/Videos/VideoController.cs";;
    esac
}

#--------------------------------------------------------------------------------------------------
# Pull
#--------------------------------------------------------------------------------------------------

# NOTE: We read from a dedicated descriptor because ssh consumes stdin.
while read -r path url branch hash <&3; do

    case "$path" in
        ""|\#*) continue;;
    esac

    repository="$root/$path"

    echo "--- $path ---"

    old=$(git -C "$repository" rev-parse "$branch")

    # NOTE: We only fast forward, so local work like the labs branch in vbml stays as it is.
    if [ "$(git -C "$repository" rev-parse --abbrev-ref HEAD)" = "$branch" ]; then

        git -C "$repository" pull --quiet --ff-only origin "$branch"
    else
        git -C "$repository" fetch --quiet origin "$branch:$branch"
    fi

    new=$(git -C "$repository" rev-parse "$branch")

    echo "$(git -C "$repository" rev-list --count "$old..$new") new commits"

    files=$(watched "$path")

    if [ -n "$files" ]; then

        git -C "$repository" --no-pager log --oneline "$old..$new" -- $files
    fi

    lock="$lock
$path $url $branch $new"

done 3< "$root/reference.lock"

echo "$lock" > "$root/reference.lock"
