#!/bin/sh
set -e

# Measures what each YouTube request costs and how the streams get throttled, without VBML. This is
# where the YouTube numbers in implementation.md come from.
#
# Usage: sh measure-youtube.sh [video id]

#--------------------------------------------------------------------------------------------------
# Settings
#--------------------------------------------------------------------------------------------------

id=${1:-aqz-KE-bpKQ}

player="https://www.youtube.com/youtubei/v1/player?prettyPrint=false"

fields='%{http_code}, %{size_download} bytes, %{time_total} s\n'

agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7_3) AppleWebKit/605.1.15 (KHTML, like Gecko) \
Version/26.0 Safari/605.1.15"

#--------------------------------------------------------------------------------------------------
# Functions
#--------------------------------------------------------------------------------------------------

post()
{
    curl -s --compressed -X POST "$player$1" -H "User-Agent: $agent" \
         -H "Content-Type: application/json" -d "$2" "$3" "$4" "$5" "$6"
}

# Prints the rate of a download compared to the playback. 1: url, 2: seconds, 3: range or empty.
rate()
{
    speed=$(curl -sL --max-time "$2" ${3:+-r "$3"} -o /dev/null -w '%{speed_download}' "$1" || true)

    awk -v s="$speed" -v n="$need" 'BEGIN { printf "%d kB/s, %.1fx\n", s / 1000, s / n }'
}

#--------------------------------------------------------------------------------------------------
# Requests
#--------------------------------------------------------------------------------------------------

printf 'watch page: '
curl -s --compressed -o /dev/null -w "$fields" "https://www.youtube.com/watch?v=$id"

printf 'sw.js_data: '
curl -s --compressed -o /dev/null -w "$fields" "https://www.youtube.com/sw.js_data"

visitor=$(curl -s --compressed "https://www.youtube.com/sw.js_data" | grep -o '"Cg[^"]*"' | head -1 | tr -d '"')

client='"clientName": "VISIONOS", "clientVersion": "1.04", "deviceMake": "Apple",
        "deviceModel": "RealityDevice17,1", "osName": "visionOS", "osVersion": "26.6.0.23O770",
        "hl": "en", "gl": "US"'

body="{\"context\": {\"client\": {$client, \"visitorData\": \"$visitor\"}},
       \"videoId\": \"$id\", \"contentCheckOk\": true, \"racyCheckOk\": true}"

printf 'player without visitorData: '
post "" "$(echo "$body" | sed "s/$visitor//")" | grep -o '"status":"[A-Z_]*"' | head -1

printf 'player: '
post "" "$body" -o /dev/null -w "$fields"

printf 'player with fields: '
post '&$fields=playabilityStatus,streamingData,videoDetails' "$body" -o /dev/null -w "$fields"

web="{\"context\": {\"client\": {\"clientName\": \"WEB\", \"clientVersion\": \"2.20261019.01.00\",
      \"hl\": \"en\", \"gl\": \"US\"}}, \"videoId\": \"$id\",
      \"contentCheckOk\": true, \"racyCheckOk\": true}"

printf 'metadata with fields: '
post '&$fields=playabilityStatus.status,microformat.playerMicroformatRenderer(uploadDate,publishDate),videoDetails(videoId,title,author,channelId,lengthSeconds,isLiveContent,thumbnail)' \
     "$web" -o /dev/null -w "$fields"

#--------------------------------------------------------------------------------------------------
# Streams
#--------------------------------------------------------------------------------------------------

# NOTE: We read the first AVC format and the first AAC audio, each of them on a single line.
formats=$(post "" "$body" | sed 's/},{"itag"/}\n{"itag"/g')

for itag in 299 137 140; do

    format=$(echo "$formats" | grep "\"itag\":$itag," | head -1)

    if [ -z "$format" ]; then

        continue
    fi

    url=$(echo "$format" | sed -n 's/.*"url":"\([^"]*\)".*/\1/p' | sed 's/\\u0026/\&/g')

    size=$(echo "$format" | sed -n 's/.*"contentLength":"\([0-9]*\)".*/\1/p')
    length=$(echo "$format" | sed -n 's/.*"approxDurationMs":"\([0-9]*\)".*/\1/p')

    need=$((size * 1000 / length))

    echo "itag $itag needs $((need / 1000)) kB/s"

    printf '  open-ended, 15 s: '
    rate "$url" 15

    printf '  10 MB range: '
    rate "$url" 60 0-10485759
done
