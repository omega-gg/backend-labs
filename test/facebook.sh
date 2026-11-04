#!/bin/sh
# NOTE: We don't want to quit this script when a test is failing.
#set -e

. "$(dirname "$(readlink -f "$0")")/common.sh"

#--------------------------------------------------------------------------------------------------
# Requests
#--------------------------------------------------------------------------------------------------

begin facebook "$@"

test "TRACK" "https://www.facebook.com/watch/?v=1839090492859799"

test "FEED" "https://www.facebook.com/starcraftremasterizado/videos"

test "RELATED" "vbml:run?backend=facebook&method=related&label=tracks&q=1839090492859799"

finish
