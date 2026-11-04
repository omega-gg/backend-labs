#!/bin/sh
# NOTE: We don't want to quit this script when a test is failing.
#set -e

. "$(dirname "$(readlink -f "$0")")/common.sh"

#--------------------------------------------------------------------------------------------------
# Requests
#--------------------------------------------------------------------------------------------------

begin youtubemusic "$@"

test "SEARCH TRACKS" "vbml:run?backend=youtubemusic&method=search&label=tracks&q=Daft Punk"

test "SEARCH ALBUMS" "vbml:run?backend=youtubemusic&method=search&label=albums&q=Daft Punk"

test "SEARCH ARTISTS" "vbml:run?backend=youtubemusic&method=search&label=artists&q=Daft Punk"

test "ALBUM" "https://music.youtube.com/browse/MPREb_K8qWMWVqXGi"

test "ARTIST" "https://music.youtube.com/channel/UCRr1xG_2WIDs18a6cIiCxeA"

# NOTE: This artist has no playlist with all its songs, so we get the songs of its page.
test "ARTIST TOP SONGS" "https://music.youtube.com/channel/UCNtvR79soaVgZnemtlsQmEw"

test "COVER" "vbml:run?backend=youtubemusic&method=cover&label=Daft Punk&q=One More Time.mp3"

test "COVER NO MATCH" \
     "vbml:run?backend=youtubemusic&method=cover&label=zzqqxxvv&q=One More Time.mp3"

finish
