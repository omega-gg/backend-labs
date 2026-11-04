#!/bin/sh
# NOTE: We don't want to quit this script when a backend is failing.
#set -e

. "$(dirname "$(readlink -f "$0")")/common.sh"

#--------------------------------------------------------------------------------------------------
# Syntax
#--------------------------------------------------------------------------------------------------

case "${1:-extract}" in
    extract|stream|play|throttle|baseline) ;;
    *) echo "Usage: sh all.sh [extract | stream | play | throttle | baseline] [labs | master]"
       exit 1;;
esac

#--------------------------------------------------------------------------------------------------
# Baseline
#--------------------------------------------------------------------------------------------------

# NOTE: This records the results of the last run. Read them first.
if [ "$1" = "baseline" ]; then

    # NOTE: Sorted and without the details, so that an update only shows what really changed.
    cut -f1-5 "$results/all.tsv" | sort > "$baseline"

    echo "baseline updated"

    exit 0
fi

#--------------------------------------------------------------------------------------------------
# Requests
#--------------------------------------------------------------------------------------------------

setup "${1:-extract}" "${2:-labs}"

TEST_RESULTS="$results/all.tsv"

export TEST_RESULTS

: > "$TEST_RESULTS"

scripts="failure duckduckgo youtube youtubemusic dailymotion vimeo twitter facebook odysee peertube iptv
         twitch tiktok soundcloud tmdb opensubtitles"

# NOTE: The backends run at the same time, so this takes as long as the slowest one. Playback runs
#       one by one, so that the windows don't compete for the machine.
for script in $scripts; do

    if [ "$1" = "play" ]; then

        sh "$directory/$script.sh" "$@" > "$results/$script.txt" 2>&1
    else
        sh "$directory/$script.sh" "$@" > "$results/$script.txt" 2>&1 &
    fi
done

wait

for script in $scripts; do

    cat "$results/$script.txt"
done

summary
