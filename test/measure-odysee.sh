#!/bin/sh
set -e

# Compares the ways of getting the sources of an Odysee video: the URLs the backend builds, and the
# one the API gives, each with and without a referer.
#
# Usage: sh measure-odysee.sh [lbry uri]

#--------------------------------------------------------------------------------------------------
# Settings
#--------------------------------------------------------------------------------------------------

uri=${1:-lbry://coldplay#e}

api="https://api.na-backend.odysee.com/api/v1/proxy"

# NOTE: The default user agent of the Sky engine.
agent="Mozilla/5.0 AppleWebKit/537 Chrome/90 Safari/537"

fields='%{http_code}, %{size_download} bytes, %{content_type}, %{redirect_url}\n'

#--------------------------------------------------------------------------------------------------
# Functions
#--------------------------------------------------------------------------------------------------

post()
{
    curl -s --ssl-no-revoke --compressed -A "$agent" -H "Content-Type: application/json" \
         -d "$1" "$api"
}

extract()
{
    sed -n "s/.*\"$1\": *\"\([^\"]*\)\".*/\1/p" | head -1
}

check()
{
    printf '  %s\n' "$2"

    printf '    no referer: '
    curl -s --ssl-no-revoke -A "$agent" -r 0-1023 -o /dev/null -w "$fields" "$2"

    printf '    referer:    '
    curl -s --ssl-no-revoke -A "$agent" -e https://odysee.com/ -r 0-1023 -o /dev/null -w "$fields" \
         "$2"
}

#--------------------------------------------------------------------------------------------------
# Resolve
#--------------------------------------------------------------------------------------------------

data=$(post "{ \"method\": \"resolve\", \"params\": { \"urls\": [ \"$uri\" ] }}")

id=$(echo "$data" | extract claim_id)
name=$(echo "$data" | extract normalized_name)
hash=$(echo "$data" | extract sd_hash)
type=$(echo "$data" | extract stream_type)

echo "claim $id, name $name, type $type"

#--------------------------------------------------------------------------------------------------
# Sources
#--------------------------------------------------------------------------------------------------

echo "built by the backend:"

check "m3u8" "https://player.odycdn.com/v6/streams/$id/$hash/master.m3u8"

check "file" "https://player.odycdn.com/v6/streams/$id/$(echo "$hash" | cut -c1-6).mp4"

check "old file" \
      "https://player.odycdn.com/api/v3/streams/free/$name/$id/$(echo "$hash" | cut -c1-6)"

echo "from the API:"

streaming=$(post "{ \"method\": \"get\", \"params\": { \"uri\": \"$uri\" }}" | extract streaming_url)

echo "  streaming_url: $streaming"

[ -n "$streaming" ] && check "stream" "$streaming"
