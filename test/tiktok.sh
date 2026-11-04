#!/bin/sh
# NOTE: We don't want to quit this script when a test is failing.
#set -e

. "$(dirname "$(readlink -f "$0")")/common.sh"

#--------------------------------------------------------------------------------------------------
# Requests
#--------------------------------------------------------------------------------------------------

begin tiktok "$@"

test "TRACK" "https://www.tiktok.com/@astroshooter__/video/7196395432459636010"

finish
