#!/bin/sh
set -e

# Compares the two ways of getting the metadata of a Twitch video: its page, and the GraphQL API.
# This is where the Twitch numbers in implementation.md come from.
#
# Usage: sh measure-twitch.sh [video id] [number of tries]

#--------------------------------------------------------------------------------------------------
# Settings
#--------------------------------------------------------------------------------------------------

id=${1:-1171797190}

tries=${2:-10}

page="https://www.twitch.tv/videos/$id"

gql="https://gql.twitch.tv/gql"

# NOTE: The default user agent of the Sky engine.
agent="Mozilla/5.0 AppleWebKit/537 Chrome/90 Safari/537"

fields='%{http_code}, %{size_download} bytes, %{time_total} s\n'

body="{ \"query\": \"{ video(id: \\\"$id\\\") { title lengthSeconds createdAt \
previewThumbnailURL(width: 1920, height: 1080) owner { login displayName } } }\" }"

#--------------------------------------------------------------------------------------------------
# Functions
#--------------------------------------------------------------------------------------------------

post()
{
    curl -s --ssl-no-revoke --compressed -X POST "$gql" -H "Content-Type: application/json" \
         -H "Client-Id: kimne78kx3ncx6brgo4mv6wki5h1ko" -d "$body" "$@"
}

#--------------------------------------------------------------------------------------------------
# Size
#--------------------------------------------------------------------------------------------------

printf 'page: '
curl -s --ssl-no-revoke --compressed -A "$agent" -o /dev/null -w "$fields" "$page"

printf 'gql: '
post -o /dev/null -w "$fields"

post
echo ""

#--------------------------------------------------------------------------------------------------
# Reliability
#--------------------------------------------------------------------------------------------------

empty=0
failed=0

i=0

while [ $i -lt "$tries" ]; do

    if ! curl -s --ssl-no-revoke --compressed -A "$agent" "$page" | grep -q 'property="og:title"'; then

        empty=$((empty + 1))
    fi

    if ! post | grep -q '"title":"'; then

        failed=$((failed + 1))
    fi

    i=$((i + 1))
done

echo "page without a title: $empty of $tries"
echo "gql without a title: $failed of $tries"
