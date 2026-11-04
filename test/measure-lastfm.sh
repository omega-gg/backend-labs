#!/bin/sh

# The Last.fm pages answer a challenge now, so this checks the APIs meant for this kind of use: the
# official one, which needs a key, and free ones that give similar data.
#
# Usage: sh measure-lastfm.sh [API key]

#--------------------------------------------------------------------------------------------------
# Settings
#--------------------------------------------------------------------------------------------------

key=${1:-none}

fields='%{http_code}, %{size_download} bytes, %{time_total} s\n'

#--------------------------------------------------------------------------------------------------
# Functions
#--------------------------------------------------------------------------------------------------

# Prints the result of a request, and the start of its answer. 1: name, 2: url.
show()
{
    printf '%s: ' "$1"
    curl -s --ssl-no-revoke --compressed --max-time 20 -o /dev/null -w "$fields" "$2"

    curl -s --ssl-no-revoke --compressed --max-time 20 "$2" | tr -d '\r' | head -c 170

    echo ""
}

#--------------------------------------------------------------------------------------------------
# Requests
#--------------------------------------------------------------------------------------------------

show "last.fm api" "https://ws.audioscrobbler.com/2.0/?format=json&api_key=$key&method=track.getInfo&artist=Stardust&track=Music+Sounds+Better+With+You"

show "deezer" "https://api.deezer.com/search?limit=2&q=Daft+Punk+One+More+Time"

show "itunes" "https://itunes.apple.com/search?limit=2&entity=song&term=Daft+Punk+One+More+Time"
