#!/bin/sh
# NOTE: We don't want to quit this script when a test is failing.
#set -e

# Tests the Twitch channels that are live right now, and counts the ad markers in what the backend
# returns. The channels change all the time, so this has no baseline and all.sh does not run it.
#
# Usage: sh twitch-live.sh [number of channels] [extract | play]

. "$(dirname "$(readlink -f "$0")")/common.sh"

#--------------------------------------------------------------------------------------------------
# Settings
#--------------------------------------------------------------------------------------------------

count=${1:-5}

# NOTE: The results don't compare with the baseline of the other tests.
baseline=""

#--------------------------------------------------------------------------------------------------
# Channels
#--------------------------------------------------------------------------------------------------

channels=$(curl -s --ssl-no-revoke --compressed -X POST https://gql.twitch.tv/gql \
           -H "Content-Type: application/json" -H "Client-Id: kimne78kx3ncx6brgo4mv6wki5h1ko" \
           -d "{ \"query\": \"{ streams(first: $count) { edges { node { broadcaster { login } } } } }\" }" \
           | grep -o '"login":"[^"]*"' | cut -d'"' -f4 | tr -d '\r')

#--------------------------------------------------------------------------------------------------
# Requests
#--------------------------------------------------------------------------------------------------

begin twitch-live "${2:-extract}"

for channel in $channels; do

    test "TRACK $channel" "https://www.twitch.tv/$channel"

    url=$(highest medias | cut -d' ' -f2)

    if [ -n "$url" ]; then

        list=$(curl -s --ssl-no-revoke "$url" | tr -d '\r')

        echo "$(echo "$list" | grep -c '^#EXTINF') segments," \
             "$(echo "$list" | grep -ciE 'stitched-ad|X-TV-TWITCH-AD') ad markers"
        echo ""
    fi

    play "TRACK $channel" "https://www.twitch.tv/$channel" 720
done

finish
