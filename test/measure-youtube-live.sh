#!/bin/sh
set -e

# Compares the live manifests of the VISIONOS and ANDROID clients: the backend asks for both today,
# and if the first one is good enough it could skip the second request.
#
# Usage: sh measure-youtube-live.sh [video id]

#--------------------------------------------------------------------------------------------------
# Settings
#--------------------------------------------------------------------------------------------------

id=${1:-UedTcufyrHc}

player="https://www.youtube.com/youtubei/v1/player?prettyPrint=false"

safari="Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7_3) AppleWebKit/605.1.15 (KHTML, like Gecko) \
Version/26.0 Safari/605.1.15"

android="com.google.android.youtube/20.10.38 (Linux; U; Android 11)"

#--------------------------------------------------------------------------------------------------
# Functions
#--------------------------------------------------------------------------------------------------

# Prints what a client gives for the live video. 1: name, 2: user agent, 3: client fields.
check()
{
    response=$(curl -s --ssl-no-revoke --compressed -X POST "$player" -H "User-Agent: $2" \
               -H "Content-Type: application/json" -H "X-Goog-Visitor-Id: $visitor" \
               -d "{\"context\": {\"client\": {$3, \"hl\": \"en\"}}, \"videoId\": \"$id\",
                    \"contentCheckOk\": true, \"racyCheckOk\": true}")

    echo "--- $1 ---"

    echo "$response" | grep -o '"status":"[A-Z_]*"' | head -1

    url=$(echo "$response" | sed -n 's/.*"hlsManifestUrl":"\([^"]*\)".*/\1/p')

    if [ -z "$url" ]; then

        echo "no manifest"

        return 0
    fi

    manifest=$(curl -s --ssl-no-revoke "$url" | tr -d '\r')

    echo "qualities: $(echo "$manifest" | grep '^#EXT-X-STREAM-INF' \
                       | sed -n 's/.*RESOLUTION=[0-9]*x\([0-9]*\).*/\1/p' | sort -n | uniq | tr '\n' ' ')"

    echo "separate audio tracks: $(echo "$manifest" | grep -c 'TYPE=AUDIO' || true)"

    echo "codecs: $(echo "$manifest" | sed -n 's/.*CODECS="\([^"]*\)".*/\1/p' | sort -u \
                    | head -4 | tr '\n' ' ')"

    variant=$(echo "$manifest" | grep '^http' | tail -1)

    if command -v ffprobe > /dev/null; then

        echo "last quality has: $(ffprobe -v error -show_entries stream=codec_type -of csv=p=0 \
                                  "$variant" < /dev/null 2>&1 | tr -d '\r' | sort -u | tr '\n' ' ')"
    fi

    echo "manifest: $(echo "$url" | sed -n 's/.*\/\(demuxed\/[01]\).*/\1/p')"
}

#--------------------------------------------------------------------------------------------------
# Requests
#--------------------------------------------------------------------------------------------------

visitor=$(curl -s --ssl-no-revoke --compressed "https://www.youtube.com/sw.js_data" \
          | grep -o '"Cg[^"]*"' | head -1 | tr -d '"')

check "VISIONOS" "$safari" '"clientName": "VISIONOS", "clientVersion": "1.02",
                            "deviceMake": "Apple", "deviceModel": "RealityDevice17,1",
                            "osName": "visionOS", "osVersion": "26.5.23O471"'

check "ANDROID" "$android" '"clientName": "ANDROID", "clientVersion": "20.10.38",
                            "androidSdkVersion": 30, "osName": "Android", "osVersion": "11"'
