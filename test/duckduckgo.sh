#!/bin/sh
# NOTE: We don't want to quit this script when a test is failing.
#set -e

. "$(dirname "$(readlink -f "$0")")/common.sh"

#--------------------------------------------------------------------------------------------------
# Requests
#--------------------------------------------------------------------------------------------------

begin duckduckgo "$@"

test "SEARCH URLS" "vbml:run?backend=duckduckgo&method=search&label=urls&q=chillwave"

# NOTE DuckDuckGo: We wait to avoid being blocked.
sleep 5

test "SEARCH SITE" \
     "vbml:run?backend=duckduckgo&method=search&label=site&q=site:https://youtube.com chillwave"

# NOTE DuckDuckGo: We wait to avoid being blocked.
sleep 5

test "SEARCH TRACKS A" "vbml:run?backend=duckduckgo&method=search&label=tracks&q=chillwave"
test "SEARCH TRACKS B" "vbml:run?backend=duckduckgo&method=search&label=tracks&q=disney+"
test "SEARCH TRACKS C" "vbml:run?backend=duckduckgo&method=search&label=tracks&q=chillwave !"

# NOTE DuckDuckGo: We wait to avoid being blocked.
sleep 5

test "SEARCH PLAYLISTS" "vbml:run?backend=duckduckgo&method=search&label=playlists&q=chillwave"

finish
