#!/bin/sh
# NOTE: We don't want to quit this script when a test is failing.
#set -e

. "$(dirname "$(readlink -f "$0")")/common.sh"

#--------------------------------------------------------------------------------------------------
# Requests
#--------------------------------------------------------------------------------------------------

begin iptv "$@"

test "SEARCH TRACKS" "vbml:run?backend=iptv&method=search&label=tracks&q=cnn"

finish
