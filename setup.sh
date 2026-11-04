#!/bin/sh
set -e

#--------------------------------------------------------------------------------------------------
# Settings
#--------------------------------------------------------------------------------------------------

root=$(dirname "$(readlink -f "$0")")

#--------------------------------------------------------------------------------------------------
# Clone
#--------------------------------------------------------------------------------------------------

# NOTE: We read from a dedicated descriptor because ssh consumes stdin.
while read -r path url branch hash <&3; do

    case "$path" in
        ""|\#*) continue;;
    esac

    if [ -e "$root/$path" ]; then

        echo "$path: already there"

        continue
    fi

    echo "$path: cloning"

    git clone --quiet --branch "$branch" "$url" "$root/$path"

    git -C "$root/$path" reset --quiet --hard "$hash"

done 3< "$root/reference.lock"
