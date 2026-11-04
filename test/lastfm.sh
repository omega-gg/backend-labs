#!/bin/sh
# NOTE: We don't want to quit this script when a test is failing.
#set -e

. "$(dirname "$(readlink -f "$0")")/common.sh"

#--------------------------------------------------------------------------------------------------
# Requests
#--------------------------------------------------------------------------------------------------

begin lastfm "$@"

test_info "TRACK" "https://www.last.fm/music/Stardust/_/Music+Sounds+Better+With+You"

test "FEED" "https://www.last.fm/music/Stardust"

test "RELATED" \
     "vbml:run?backend=lastfm&method=related&label=tracks&q=Stardust%2F_%2FMusic%2BSounds%2BBetter%2BWith%2BYou"

test "SEARCH TRACKS" "vbml:run?backend=lastfm&method=search&label=tracks&q=Daft Punk"

test "COVER" "vbml:run?backend=lastfm&method=cover&label=Daft Punk&q=One More Time.mp3"

finish
