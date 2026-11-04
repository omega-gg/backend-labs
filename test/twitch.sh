#!/bin/sh
# NOTE: We don't want to quit this script when a test is failing.
#set -e

. "$(dirname "$(readlink -f "$0")")/common.sh"

#--------------------------------------------------------------------------------------------------
# Requests
#--------------------------------------------------------------------------------------------------

begin twitch "$@"

test "TRACK" "https://www.twitch.tv/videos/1171797190"

test "TRACK LIVE" "https://www.twitch.tv/esl_sc2"

test_info "TRACK OFFLINE" "https://www.twitch.tv/twitch"

test "RELATED" "vbml:run?backend=twitch&method=related&label=tracks&q=esl_sc2"

test "PLAYLIST A" "https://www.twitch.tv/directory/all"

test "PLAYLIST B" "https://www.twitch.tv/directory/collection/recently-released-games-streams"

test "SEARCH CHANNELS" "vbml:run?backend=twitch&method=search&label=tracks&q=starcraft"

test "SEARCH VIDEOS" "vbml:run?backend=twitch&method=search&label=videos&q=starcraft"

play "TRACK" "https://www.twitch.tv/videos/1171797190" 720

play "TRACK LIVE" "https://www.twitch.tv/esl_sc2" 720

finish
