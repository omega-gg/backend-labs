#!/bin/sh
# NOTE: We don't want to quit this script when a test is failing.
#set -e

. "$(dirname "$(readlink -f "$0")")/common.sh"

#--------------------------------------------------------------------------------------------------
# Requests
#--------------------------------------------------------------------------------------------------

begin vox "$@"

test "TRACK" "https://vox.omega.gg/w/9d5fYXTcjLHReVUQabKRwB"

test "FEED" "https://vox.omega.gg/c/vox"

test "PLAYLIST" "https://vox.omega.gg/w/p/ehXUsZrq4TJZVBC8J7GWpN"

test "TRENDING" "vbml:run?backend=peertube&method=view&q=vox.omega.gg/trending"

test "RELATED" \
     "vbml:run?backend=peertube&method=related&label=tracks&q=vox.omega.gg/w/9d5fYXTcjLHReVUQabKRwB"

test "RELATED TIME" \
     "vbml:run?backend=peertube&method=related&label=tracks&q=vox.omega.gg/w/9d5fYXTcjLHReVUQabKRwB&t=1"

test "SEARCH TRACKS" \
     "vbml:run?backend=peertube&method=search&label=tracks&q=site:vox.omega.gg movie"

finish
