#!/bin/sh
# NOTE: We don't want to quit this script when a test is failing.
#set -e

. "$(dirname "$(readlink -f "$0")")/common.sh"

#--------------------------------------------------------------------------------------------------
# Requests
#--------------------------------------------------------------------------------------------------

begin soundcloud "$@"

test "TRACK" "https://soundcloud.com/bigwild/sylvan-esso-hey-mami-big-wild-remix"

test "FEED" "https://soundcloud.com/bigwild"

test "RELATED" \
     "vbml:run?backend=soundcloud&method=related&label=tracks&q=bigwild/sylvan-esso-hey-mami-big-wild-remix"

test "SEARCH TRACKS" "vbml:run?backend=soundcloud&method=search&label=tracks&q=chillwave"

test "SEARCH PEOPLE" "vbml:run?backend=soundcloud&method=search&label=people&q=chillwave"

test "SEARCH PLAYLISTS" "vbml:run?backend=soundcloud&method=search&label=playlists&q=chillwave"

finish
