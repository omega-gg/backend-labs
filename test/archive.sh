#!/bin/sh
# NOTE: We don't want to quit this script when a test is failing.
#set -e

. "$(dirname "$(readlink -f "$0")")/common.sh"

#--------------------------------------------------------------------------------------------------
# Requests
#--------------------------------------------------------------------------------------------------

begin archive "$@"

test "TRACK" "https://archive.org/details/TheGeneral"

# NOTE: An item with a video in a folder, and a name that has nothing to do with the item.
test "TRACK FOLDER" "https://archive.org/details/BigBuckBunny_124"

test "TRACK AUDIO" "https://archive.org/details/gd1977-05-08.shure57.stevenson.29303.flac16"

test "ALBUM" "https://archive.org/download/gd1977-05-08.shure57.stevenson.29303.flac16"

# NOTE: An album with an artwork.
test "ALBUM COVER" "https://archive.org/download/mdsw_20240622"

# NOTE: An album of 104 files, each of them in several MP3 qualities.
test "ALBUM SEVERAL" "https://archive.org/download/OTRR_Box_13_Singles"

test "SEARCH TRACKS" "vbml:run?backend=archive&method=search&label=tracks&q=buster keaton"

test "SEARCH ALBUMS" "vbml:run?backend=archive&method=search&label=albums&q=miles davis"

play "TRACK" "https://archive.org/details/TheGeneral" 480

finish
