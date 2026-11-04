#!/bin/sh
# NOTE: We don't want to quit this script when a test is failing.
#set -e

. "$(dirname "$(readlink -f "$0")")/common.sh"

#--------------------------------------------------------------------------------------------------
# Requests
#--------------------------------------------------------------------------------------------------

begin odysee "$@"

test "TRACK" "https://odysee.com/coldplay:e"

# NOTE: A video with HLS sources, its file is refused.
test "TRACK HLS" \
     "https://odysee.com/165---spiritual-war-1:a6acf6cf4330c44019005d72e291b6dcbdb445dc"

# NOTE: A video with its file only.
test "TRACK FILE" \
     "https://odysee.com/saturn-cult-world-order.-parts-1-to-5.-:5974d8395957f9c48a997b5d495ac6661443376e"

finish
