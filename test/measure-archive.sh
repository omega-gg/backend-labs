#!/bin/sh

# What the Internet Archive answers for an item: its metadata, the files it has, a search, and the
# sources of a video and an audio item.
#
# Usage: sh measure-archive.sh [video item] [audio item]

#--------------------------------------------------------------------------------------------------
# Settings
#--------------------------------------------------------------------------------------------------

video=${1:-BigBuckBunny_124}
audio=${2:-gd1977-05-08.shure57.stevenson.29303.flac16}

# NOTE: The default user agent of the Sky engine.
agent="Mozilla/5.0 AppleWebKit/537 Chrome/90 Safari/537"

fields='%{http_code}, %{size_download} bytes, %{time_total} s, %{url_effective}\n'

file=$(mktemp)

#--------------------------------------------------------------------------------------------------
# Functions
#--------------------------------------------------------------------------------------------------

get()
{
    curl -s -L --ssl-no-revoke --compressed -A "$agent" "$@"
}

check()
{
    printf '  %s: ' "$1"

    get -r 0-1023 -o /dev/null -w "$fields" "$2" | cut -c1-110
}

item()
{
    echo "--- $1"

    get -o "$file" -w "  metadata: $fields" "https://archive.org/metadata/$1"

    # NOTE: One line per file, with the fields we would use.
    tr '{' '\n' < "$file" | grep '"format"' | grep -iE 'mpeg4|h\.264|matroska|ogg|mp3|flac|vbr' \
        | sed 's/"md5".*"format"/"format"/' | cut -c1-120 | head -"${2:-12}"

    echo "  files: $(tr '{' '\n' < "$file" | grep -c '"format"')"

    echo "  server: $(grep -o '"d1":"[^"]*"' "$file"), dir: $(grep -o '"dir":"[^"]*"' "$file")"

    echo "  mediatype: $(grep -o '"mediatype":"[^"]*"' "$file"), title: \
$(grep -o '"title":"[^"]*"' "$file" | head -1 | cut -c1-70)"
}

#--------------------------------------------------------------------------------------------------
# Items
#--------------------------------------------------------------------------------------------------

item "$video"

check "download mp4" "https://archive.org/download/$video/$video.mp4"

check "cover" "https://archive.org/services/img/$video"

item "$audio" 6

#--------------------------------------------------------------------------------------------------
# Search
#--------------------------------------------------------------------------------------------------

echo "--- search"

base="https://archive.org/advancedsearch.php?fl%5B%5D=identifier&fl%5B%5D=title&fl%5B%5D=mediatype"

base="$base&fl%5B%5D=creator&rows=5&output=json"

get -o "$file" -w "  $fields" "$base&q=title%3A%28buster+keaton%29+AND+mediatype%3Amovies"

cut -c1-300 "$file"

echo ""

rm -f "$file"
