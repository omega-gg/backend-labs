#!/bin/sh
set -e

# Compares the ways of getting a TikTok video: the app API the backend uses, and the web page.
#
# Usage: sh measure-tiktok.sh [video url] [number of tries]

#--------------------------------------------------------------------------------------------------
# Settings
#--------------------------------------------------------------------------------------------------

url=${1:-https://www.tiktok.com/@tiktok/video/7106594312292453675}

tries=${2:-5}

id=${url##*/}

# NOTE: The default user agent of the Sky engine.
agent="Mozilla/5.0 AppleWebKit/537 Chrome/90 Safari/537"

api="https://api16-normal-c-useast1a.tiktokv.com/aweme/v1/feed/?aweme_id=$id\
&iid=7318518857994389254&device_id=7318517321748022790&channel=googleplay\
&app_name=musical_ly&version_code=300904&device_platform=android\
&device_type=ASUS_Z01QD&version=9&carrier_region=US&sys_region=US&region=US&language=en"

cookies="$(mktemp)"

#--------------------------------------------------------------------------------------------------
# App API
#--------------------------------------------------------------------------------------------------

ok=0

i=0

while [ $i -lt "$tries" ]; do

    code=$(curl -s --ssl-no-revoke --compressed -A "$agent" -X OPTIONS -o /dev/null \
           -w '%{http_code}' "$api")

    echo "api try $i: http $code"

    if [ "$code" = "200" ]; then

        ok=$((ok + 1))
    fi

    i=$((i + 1))
done

echo "api: $ok of $tries"

#--------------------------------------------------------------------------------------------------
# Web page
#--------------------------------------------------------------------------------------------------

page=$(curl -s --ssl-no-revoke --compressed -L -A "$agent" -c "$cookies" "$url")

echo "page: $(echo "$page" | wc -c) bytes"

echo "status: $(echo "$page" | grep -o '"statusCode":[0-9]*' | head -1)"

echo "desc: $(echo "$page" | grep -oE '"desc":"[^"]{0,50}' | head -1)"

echo "duration: $(echo "$page" | grep -oE '"duration":[0-9]+' | head -1)"

video=$(echo "$page" | grep -oE '"playAddr":"[^"]*"' | head -1 | cut -d'"' -f4 | sed 's/\\u002F/\//g')

if [ -z "$video" ]; then

    echo "no playAddr"

    rm -f "$cookies"

    exit 0
fi

fields='%{http_code}, %{size_download} bytes\n'

printf 'video, alone: '
curl -s --ssl-no-revoke -A "$agent" -r 0-1048575 -o /dev/null -w "$fields" "$video"

printf 'video, with a referer: '
curl -s --ssl-no-revoke -A "$agent" -e "$url" -r 0-1048575 -o /dev/null -w "$fields" "$video"

printf 'video, with the cookies: '
curl -s --ssl-no-revoke -A "$agent" -e "$url" -b "$cookies" -r 0-1048575 -o /dev/null \
     -w "$fields" "$video"

rm -f "$cookies"
