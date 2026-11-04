#!/bin/sh
# NOTE: We don't want to quit this script when a test is failing.
#set -e

. "$(dirname "$(readlink -f "$0")")/common.sh"

#--------------------------------------------------------------------------------------------------
# Requests
#--------------------------------------------------------------------------------------------------

begin opensubtitles "$@"

test "SEARCH SUBTITLES" \
     "vbml:run?backend=opensubtitles&method=subtitles&label=french&q=Modern Times"

finish
