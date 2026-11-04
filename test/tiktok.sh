#!/bin/sh
# NOTE: We don't want to quit this script when a test is failing.
#set -e

. "$(dirname "$(readlink -f "$0")")/common.sh"

#--------------------------------------------------------------------------------------------------
# Requests
#--------------------------------------------------------------------------------------------------

begin tiktok "$@"

test "TRACK" "https://www.tiktok.com/@tiktok/video/7106594312292453675"

finish
