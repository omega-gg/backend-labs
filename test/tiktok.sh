#!/bin/sh
# NOTE: We don't want to quit this script when a test is failing.
#set -e

. "$(dirname "$(readlink -f "$0")")/common.sh"

#--------------------------------------------------------------------------------------------------
# Requests
#--------------------------------------------------------------------------------------------------

begin tiktok "$@"

test "TRACK" "https://www.tiktok.com/@tiktok/video/7106594312292453675"

test "FEED" "https://www.tiktok.com/@tiktok"

# NOTE: Videos with hashtags, each hashtag comes with its own 'id' and 'desc'.
test "FEED HASHTAGS" "https://www.tiktok.com/@ciaoambino"

play "TRACK" "https://www.tiktok.com/@tiktok/video/7106594312292453675" 720

finish
