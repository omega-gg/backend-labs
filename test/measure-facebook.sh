#!/bin/sh

# Compares the ways of getting the sources of a Facebook video: the DASH manifest the backend asks
# for, the video page, the embed pages and the mobile site.
#
# Usage: sh measure-facebook.sh [video id]

#--------------------------------------------------------------------------------------------------
# Settings
#--------------------------------------------------------------------------------------------------

id=${1:-1832812847552846}

# NOTE: The default user agent of the Sky engine.
agent="Mozilla/5.0 AppleWebKit/537 Chrome/90 Safari/537"

base="https://www.facebook.com"

file=$(mktemp)

fields='browser_native_hd_url browser_native_sd_url playable_url playable_url_quality_hd
progressive_url dash_manifest hd_src sd_src video_url'

#--------------------------------------------------------------------------------------------------
# Functions
#--------------------------------------------------------------------------------------------------

check()
{
    printf '%s\n' "$1"

    shift

    curl -s --ssl-no-revoke --compressed -A "$agent" -H "accept: text/html" -L --max-redirs 3 \
         -o "$file" -w '  %{http_code}, %{size_download} bytes, %{num_redirects} redirects, %{url_effective}\n' \
         "$@"

    found=""

    for field in $fields; do

        count=$(grep -o "\"$field\"" "$file" | wc -l)

        if [ "$count" -gt 0 ]; then

            found="$found $field=$count"
        fi
    done

    echo "  fields:${found:- none}"

    echo "  video id: $(grep -o "$id" "$file" | wc -l), og:video: $(grep -c 'og:video' "$file"), login: $(grep -c 'login_form\|/login/' "$file")"

    sleep 2
}

#--------------------------------------------------------------------------------------------------
# Routes
#--------------------------------------------------------------------------------------------------

check "manifest" -H "Sec-Fetch-Mode: navigate" \
      "$base/video/playback/dash_mpd_debug.mpd?v=$id&dummy=.mpd"

check "watch page" -H "Sec-Fetch-Mode: navigate" "$base/watch/?v=$id"

check "video.php" -H "Sec-Fetch-Mode: navigate" "$base/video.php?v=$id"

check "embed" "$base/video/embed?video_id=$id"

check "plugin" "$base/plugins/video.php?href=$base%2Fwatch%2F%3Fv%3D$id"

check "mobile" "https://m.facebook.com/watch/?v=$id"

rm -f "$file"
