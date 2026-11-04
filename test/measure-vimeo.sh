#!/bin/sh
set -e

# Compares the ways of getting the sources of a Vimeo video: the API, and the player config.
#
# Usage: sh measure-vimeo.sh [video id]

#--------------------------------------------------------------------------------------------------
# Settings
#--------------------------------------------------------------------------------------------------

id=${1:-370892294}

# NOTE: The default user agent of the Sky engine.
agent="Mozilla/5.0 AppleWebKit/537 Chrome/90 Safari/537"

fields='%{http_code}, %{size_download} bytes, %{time_total} s\n'

#--------------------------------------------------------------------------------------------------
# Functions
#--------------------------------------------------------------------------------------------------

get()
{
    curl -s --ssl-no-revoke --compressed -A "$agent" "$@"
}

#--------------------------------------------------------------------------------------------------
# API
#--------------------------------------------------------------------------------------------------

printf 'viewer: '
get -H "accept: text/html" -o /dev/null -w "$fields" https://vimeo.com/_next/viewer

jwt=$(get -H "accept: text/html" https://vimeo.com/_next/viewer \
      | sed -n 's/.*"jwt":"\([^"]*\)".*/\1/p')

for field in download play files config_url embed; do

    printf 'api %s: ' "$field"
    get -H "Authorization: jwt $jwt" -w ' [%{http_code}]\n' \
        "https://api.vimeo.com/videos/$id?fields=$field" | cut -c1-200
done

#--------------------------------------------------------------------------------------------------
# Page
#--------------------------------------------------------------------------------------------------

printf 'page: '
get -o /dev/null -w "$fields" "https://vimeo.com/$id"

signed=$(get "https://vimeo.com/$id" | grep -o 'config_url[^,]*' | head -1 | cut -c1-40)

echo "page config_url: ${signed:-none}"

#--------------------------------------------------------------------------------------------------
# Player
#--------------------------------------------------------------------------------------------------

config="https://player.vimeo.com/video/$id/config"

printf 'player config: '
get -o /dev/null -w "$fields" "$config"

printf 'player config with a referer: '
get -e "https://vimeo.com/$id" -o /dev/null -w "$fields" "$config"

response=$(get -e "https://vimeo.com/$id" "$config")

echo "progressive: $(echo "$response" | grep -o '"progressive":\[[^]]\{0,60\}' | cut -c1-90)"
echo "hls: $(echo "$response" | grep -o '"hls":{.\{0,100\}' | cut -c1-120)"
echo "dash: $(echo "$response" | grep -o '"dash":{.\{0,60\}' | cut -c1-80)"

url=$(echo "$response" | sed -n 's/.*"hls":{.*"url":"\(https[^"]*\)".*/\1/p' | sed 's/\\u0026/\&/g')

if [ -n "$url" ]; then

    printf 'hls manifest: '
    get -o /dev/null -w "$fields" "$url"

    echo "qualities: $(get -L "$url" | tr -d '\r' \
                       | sed -n 's/.*RESOLUTION=[0-9]*x\([0-9]*\).*/\1/p' | sort -un | tr '\n' ' ')"
fi
