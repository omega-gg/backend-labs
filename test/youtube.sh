#!/bin/sh
# NOTE: We don't want to quit this script when a test is failing.
#set -e

. "$(dirname "$(readlink -f "$0")")/common.sh"

#--------------------------------------------------------------------------------------------------
# Requests
#--------------------------------------------------------------------------------------------------

begin youtube "$@"

test "TRACK" "https://www.youtube.com/watch?v=wOMwO5T3yT4"

# NOTE: 4K60, this is our main reference for the streams.
test "TRACK 4K" "https://www.youtube.com/watch?v=aqz-KE-bpKQ"

# NOTE: 1080p60, with no 4K.
test "TRACK 1080" "https://www.youtube.com/watch?v=qWbhCFDdhzM"

test "TRACK HDR" "https://www.youtube.com/watch?v=LXb3EKWsInQ"

test "TRACK DISNEY" "https://www.youtube.com/watch?v=lKt-gEQUir4"

test "TRACK LIVE" "https://www.youtube.com/watch?v=UedTcufyrHc"

test "FEED" "https://www.youtube.com/channel/UCZyXa4H06Ws3Pwom9cYEdDA"

test "FEED WEIRD" "https://www.youtube.com/@the.drum.thing."

test "RELATED" "vbml:run?backend=youtube&method=related&label=tracks&q=wOMwO5T3yT4"

test "SEARCH TRACKS" "vbml:run?backend=youtube&method=search&label=tracks&q=chillwave"

test "SEARCH CHANNELS" "vbml:run?backend=youtube&method=search&label=channels&q=chillwave"

test "SEARCH PLAYLISTS" "vbml:run?backend=youtube&method=search&label=playlists&q=chillwave"

# NOTE: This one might break more often so we put it at the end.
test "TRACK LOCKED" "https://www.youtube.com/watch?v=tQ0yjYUFKAE"

play "TRACK 4K" "https://www.youtube.com/watch?v=aqz-KE-bpKQ" 2160

play "TRACK 1080" "https://www.youtube.com/watch?v=qWbhCFDdhzM" 1080

play "TRACK LIVE" "https://www.youtube.com/watch?v=UedTcufyrHc" 720

finish
