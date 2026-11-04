#!/bin/sh
set -e

# Counts the ad markers in the live playlist of a Twitch channel for each player type, and lists the
# qualities it offers. Ads come and go, so run it a few times before drawing a conclusion.
#
# Usage: sh measure-twitch-ads.sh [channel] [number of tries]

#--------------------------------------------------------------------------------------------------
# Settings
#--------------------------------------------------------------------------------------------------

channel=${1:-}

tries=${2:-3}

gql="https://gql.twitch.tv/gql"

#--------------------------------------------------------------------------------------------------
# Functions
#--------------------------------------------------------------------------------------------------

post()
{
    curl -s --ssl-no-revoke --compressed -X POST "$gql" -H "Content-Type: application/json" \
         -H "Client-Id: kimne78kx3ncx6brgo4mv6wki5h1ko" -d "$1"
}

# Prints the list of qualities. 1: player type.
qualities()
{
    token=$(post "{ \"query\": \"{ streamPlaybackAccessToken(channelName: \\\"$channel\\\", \
params: { platform: \\\"web\\\", playerBackend: \\\"mediaplayer\\\", \
playerType: \\\"$1\\\"}) { value signature }}\" }")

    value=$(echo "$token" | sed -n 's/.*"value":"\(.*\)","signature".*/\1/p' | sed 's/\\"/"/g')
    signature=$(echo "$token" | sed -n 's/.*"signature":"\([^"]*\)".*/\1/p')

    curl -s --ssl-no-revoke -G "https://usher.ttvnw.net/api/channel/hls/$channel.m3u8" \
         --data-urlencode "token=$value" --data-urlencode "sig=$signature" \
         --data-urlencode "allow_source=true" | tr -d '\r'
}

#--------------------------------------------------------------------------------------------------
# Channel
#--------------------------------------------------------------------------------------------------

# NOTE: By default we take a channel that's live right now.
if [ -z "$channel" ]; then

    channel=$(post '{ "query": "{ streams(first: 1) { edges { node { broadcaster { login } } } } }" }' \
              | sed -n 's/.*"login":"\([^"]*\)".*/\1/p')
fi

echo "channel: $channel"

#--------------------------------------------------------------------------------------------------
# Count
#--------------------------------------------------------------------------------------------------

for type in site embed popout frontpage; do

    i=0

    while [ $i -lt "$tries" ]; do

        master=$(qualities "$type")

        names=$(echo "$master" | sed -n 's/.*VIDEO="\([^"]*\)".*/\1/p' | tr '\n' ' ')

        list=$(curl -s --ssl-no-revoke "$(echo "$master" | grep '^http' | head -1)" | tr -d '\r')

        segments=$(echo "$list" | grep -c '^#EXTINF' || true)

        ads=$(echo "$list" | grep -ciE 'stitched-ad|X-TV-TWITCH-AD' || true)

        echo "$type: $segments segments, $ads ad markers, qualities: $names"

        i=$((i + 1))
    done
done
