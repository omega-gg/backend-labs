#!/bin/sh
# NOTE: We don't want to quit this script when a test is failing.
#set -e

. "$(dirname "$(readlink -f "$0")")/common.sh"

#--------------------------------------------------------------------------------------------------
# Requests
#--------------------------------------------------------------------------------------------------

begin peertube "$@"

test "TRACK" "https://peertube.dsmouse.net/w/719666f2-0fb6-489c-8339-038f902aa55c"

test "TRACK SHORT" "https://peertube.fr/w/kkGMgK9ZtnKfYAgnEtQxbv"

test "FEED" "https://peertube.fr/c/joinpeertube@framatube.org"

test "RELATED" \
     "vbml:run?backend=peertube&method=related&label=tracks&q=peertube.fr/w/kkGMgK9ZtnKfYAgnEtQxbv"

test "TRENDING" "vbml:run?backend=peertube&method=view&q=peertube.fr/trending"

test "SEARCH TRACKS" \
     "vbml:run?backend=peertube&method=search&label=tracks&q=peertube.fr?search=peertube"

finish
