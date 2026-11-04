#!/bin/sh
# NOTE: We don't want to quit this script when a test is failing.
#set -e

. "$(dirname "$(readlink -f "$0")")/common.sh"

#--------------------------------------------------------------------------------------------------
# Requests
#--------------------------------------------------------------------------------------------------

# NOTE: Nothing listens on this port, so these never leave the machine. A failed request has to end
#       with exit code 1. It used to crash clientVBML, see implementation.md.
begin failure "$@"

test_failure "FEED" "https://127.0.0.1:9/c/vox"

test_failure "TRACK" "https://127.0.0.1:9/w/abc"

test_failure "TRENDING" "vbml:run?backend=peertube&method=view&q=127.0.0.1:9/trending"

finish
