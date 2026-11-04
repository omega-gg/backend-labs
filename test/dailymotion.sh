#!/bin/sh
# NOTE: We don't want to quit this script when a test is failing.
#set -e

. "$(dirname "$(readlink -f "$0")")/common.sh"

#--------------------------------------------------------------------------------------------------
# Requests
#--------------------------------------------------------------------------------------------------

begin dailymotion "$@"

test "TRACK" "https://www.dailymotion.com/video/x83nkms"

test "FEED" "https://www.dailymotion.com/TechnoOverlfload"

test "RELATED" "vbml:run?backend=dailymotion&method=related&label=tracks&q=x83nkms"

test "SEARCH TRACKS" "vbml:run?backend=dailymotion&method=search&label=tracks&q=chillwave"

# NOTE: No result for 'chillwave'.
test "SEARCH CHANNELS" "vbml:run?backend=dailymotion&method=search&label=channels&q=synthwave"

play "TRACK" "https://www.dailymotion.com/video/x83nkms" 720

finish
