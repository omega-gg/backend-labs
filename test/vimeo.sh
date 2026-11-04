#!/bin/sh
# NOTE: We don't want to quit this script when a test is failing.
#set -e

. "$(dirname "$(readlink -f "$0")")/common.sh"

#--------------------------------------------------------------------------------------------------
# Requests
#--------------------------------------------------------------------------------------------------

begin vimeo "$@"

test "TRACK" "https://vimeo.com/370892294"

test "FEED" "https://vimeo.com/dalz1el"

play "TRACK" "https://vimeo.com/370892294" 720

finish
