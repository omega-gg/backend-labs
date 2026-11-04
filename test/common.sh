#!/bin/sh
# NOTE: This file is sourced by the backend scripts and all.sh.

#--------------------------------------------------------------------------------------------------
# Settings
#--------------------------------------------------------------------------------------------------

directory=$(dirname "$(readlink -f "$0")")

root=$(dirname "$directory")

# NOTE: Set these when your builds are somewhere else.
CLIENT_BIN=${CLIENT_BIN:-$root/../clientVBML/bin}
SKY_BIN=${SKY_BIN:-$root/../Sky-runtime/bin}

# NOTE: Applications load ../../backend from their folder, so these two read build/backend.
client="$root/build/clientVBML/bin"
sky="$root/build/Sky-runtime/bin"
backend="$root/build/backend"

results="$root/build/results"

# NOTE: Sites can answer differently from another network, the CI has its own baseline.
baseline=${BASELINE:-$directory/baseline.tsv}

# NOTE: A query usually takes a few seconds, so this fails fast on a site that's unreachable.
timeout_client=20

timeouts=0
passed=0

# NOTE: Set this to play for longer when you suspect that playback is not smooth.
PLAY_SECONDS=${PLAY_SECONDS:-5}

# NOTE: Git Bash rewrites the arguments that look like paths, and that would alter our queries.
export MSYS_NO_PATHCONV=1

#--------------------------------------------------------------------------------------------------
# Functions
#--------------------------------------------------------------------------------------------------

# Copies the applications and the backends in the build folder. Only the newer files get copied,
# so a rebuild gets picked up and the next runs are quick.
#
# 1: level, 2: labs for the vbml folder, master for the public backend repository.
setup()
{
    mkdir -p "$client" "$backend" "$results"

    cp -ru "$CLIENT_BIN"/. "$client"

    rm -f "$backend"/*.vbml

    if [ "$2" = "master" ]; then

        # NOTE: We use a relative path, because MSYS_NO_PATHCONV applies to git as well.
        (
            cd "$root/build" || exit 1

            rm -rf public

            git clone --quiet --depth 1 https://github.com/omega-gg/backend public
        )

        cp "$root"/build/public/*.vbml "$backend"
    else
        cp "$root"/vbml/*.vbml "$backend"
    fi

    if [ "$1" = "play" ]; then

        mkdir -p "$sky"

        cp -ru "$SKY_BIN"/. "$sky"
    fi

    sh "$directory/lint.sh" "$backend"
}

# Starts a backend. When all.sh is not running we do the setup and print a summary at the end.
begin()
{
    name=$1

    level=${2:-extract}

    if [ -z "$TEST_RESULTS" ]; then

        setup "$level" "${3:-labs}"

        TEST_RESULTS="$results/$name.tsv"

        : > "$TEST_RESULTS"

        alone=1
    fi

    # NOTE: clientVBML works in the current folder, and all.sh runs the backends at the same time.
    work="$results/$name"

    mkdir -p "$work"

    echo "--- $name ---"
    echo ""
}

finish()
{
    if [ -n "$alone" ]; then

        summary

        exit $?
    fi
}

summary()
{
    echo "--- summary ---"
    echo ""

    cut -f6 "$TEST_RESULTS" | sort | uniq -c

    echo ""

    awk -F'\t' '$6 != "OK" { print $6, $1, $2 ":", $7 }' "$TEST_RESULTS"

    echo ""
    echo "results: $TEST_RESULTS"

    ! cut -f6 "$TEST_RESULTS" | grep -qE 'REGRESSION|FAIL'
}

# Fails the case right away when nothing works on this site, so a dead site stays quick. One
# timeout can be a slow response, so it takes two before anything has answered.
skip()
{
    if [ "$timeouts" -lt 2 ] || [ "$passed" = "1" ]; then

        return 1
    fi

    result "$1" "FAIL" "" "" "skipped, the site is not responding"

    echo ""
}

# Prints a value of the baseline for this case. 1: case, 2: column.
was()
{
    if [ -f "$baseline" ]; then

        awk -F'\t' -v b="$name" -v c="$1" -v n="$2" \
            '$1 == b && $2 == c { print $n; exit }' "$baseline"
    fi
}

# Records and prints a result. 1: case, 2: OK or FAIL, 3: time, 4: requests, 5: details.
result()
{
    was_status=$(was "$1" 3)
    was_time=$(was "$1" 4)
    was_requests=$(was "$1" 5)

    verdict=$2

    if [ "$2" != "OK" ]; then

        case "$was_status" in
            OK)   verdict="REGRESSION";;
            FAIL) verdict="KNOWN";;
        esac

    elif [ -n "$4" ] && [ -n "$was_requests" ] && [ "$4" -gt "$was_requests" ]; then

        verdict="REGRESSION"

        set -- "$1" "$2" "$3" "$4" "$4 requests, was $was_requests"
    fi

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
           "$name" "$1" "$2" "$3" "$4" "$verdict" "$5" >> "$TEST_RESULTS"

    line="[$verdict]"

    if [ -n "$3" ]; then

        line="$line $3 ms"
    fi

    if [ -n "$4" ]; then

        line="$line, $4 requests"
    fi

    if [ -n "$was_time" ] && [ -n "$was_requests" ]; then

        line="$line (baseline $was_time ms, $was_requests requests)"
    fi

    echo "$line $5"
}

# Runs clientVBML. Sets code, time and requests.
run()
{
    log="$work/$(echo "$1" | tr ' ' '-')"

    rm -f "$work/output.vbml" "$log.vbml"
    rm -rf "$work/storage"

    start=$(date +%s%N)

    (cd "$work" && timeout "$timeout_client" "$client/clientVBML" "$2") > "$log.log" 2>&1

    code=$?

    if [ "$code" = "124" ]; then

        timeouts=$((timeouts + 1))
    else
        passed=1
    fi

    time=$((($(date +%s%N) - start) / 1000000))

    # NOTE: On the CI this is the only way to see where it crashed without getting the artifact.
    if [ "$code" = "139" ]; then

        echo "CRASH, the end of the log:"

        tail -8 "$log.log" | cut -c1-200
    fi

    # NOTE: Every download gets logged as "Get <url>", POST requests included.
    requests=$(grep -ac '^Get http' "$log.log")

    # NOTE: Then we are not testing the local backends, so the results would be misleading.
    if grep -aq '^Get https://raw.githubusercontent.com/omega-gg/backend' "$log.log"; then

        result "$1" "FAIL" "" "" "stopped, clientVBML downloaded its backends from GitHub"

        echo "Check that it's not a deploy build, and that the versions match: sh test/lint.sh"

        finish

        exit 0
    fi

    if [ -f "$work/output.vbml" ]; then

        cp "$work/output.vbml" "$log.vbml"
    fi
}

has()
{
    grep -aq "$1" "$work/output.vbml" 2> /dev/null
}

# Prints the url for the highest quality of a block in the output, like 'medias:'.
highest()
{
    tr -d '\r' < "$work/output.vbml" | awk -v block="$1:" '
        $0 == block       { inside = 1; next }
        inside && /^[^ ]/ { inside = 0 }
        inside && NF      { sub(":", "", $1); print $1 + 0, $2 }' | sort -n | tail -1
}

# Checks that a stream is valid with a short download. 1: case, 2: url.
#
# At the throttle level we request 10 MB like the player does, and compare with the playback rate.
# NOTE: ffprobe is optional, it tells us the codec and the playback rate.
stream()
{
    status="OK"
    details=""

    if command -v ffprobe > /dev/null; then

        probe=$(ffprobe -v error -select_streams 0 -of default=noprint_wrappers=1 \
                -show_entries stream=codec_name:format=duration,size "$2" 2> /dev/null \
                | tr -d '\r')

        codec=$(echo "$probe" | sed -n 's/^codec_name=//p' | head -1)
        size=$(echo "$probe" | sed -n 's/^size=//p' | head -1)
        duration=$(echo "$probe" | sed -n 's/^duration=//p' | head -1)

        if [ -z "$codec" ]; then

            status="FAIL"
        fi

        details="$codec"
    fi

    case "$2" in
    *m3u8*)
        lines=$(curl -sL --ssl-no-revoke --max-time 10 "$2" | grep -c '#EXT')

        if [ "$lines" = "0" ]; then

            status="FAIL"
        fi

        details="$details HLS"

        result "$1" "$status" "" "" "$details"

        return;;
    esac

    if [ "$level" = "throttle" ]; then

        last=10485759
    else
        last=1048575
    fi

    set -- "$1" "$2" $(curl -sL --ssl-no-revoke --max-time 60 -r "0-$last" -o /dev/null \
                       -w '%{http_code} %{speed_download} %{time_starttransfer}' "$2")

    speed=$(awk -v s="$4" 'BEGIN { printf "%d", s / 1000 }')

    first=$(awk -v t="$5" 'BEGIN { printf "%d", t * 1000 }')

    if [ "$3" != "206" ] && [ "$3" != "200" ]; then

        status="FAIL"

        details="$details http $3"

    elif [ "$level" = "throttle" ] && [ -n "$size" ] && [ "$size" != "N/A" ] \
         && [ -n "$duration" ] && [ "$duration" != "N/A" ]; then

        rate=$(awk -v s="$4" -v b="$size" -v d="$duration" 'BEGIN { printf "%.1f", s / (b / d) }')

        details="$details $speed kB/s ${rate}x"

        if [ "$(awk -v r="$rate" 'BEGIN { print (r < 3) }')" = "1" ]; then

            status="FAIL"
        fi
    else
        details="$details $speed kB/s"
    fi

    result "$1" "$status" "$first" "" "$details"
}

#--------------------------------------------------------------------------------------------------
# Tests
#--------------------------------------------------------------------------------------------------

# A query. The label tells what we expect: TRACK needs sources and a title, COVER needs a cover,
# and the rest needs at least one entry.
test()
{
    if [ "$level" = "play" ]; then

        return 0
    fi

    echo "$1 $2"

    if skip "$1"; then

        return 0
    fi

    run "$1" "$2"

    status="OK"
    details=""

    case "$1" in
    TRACK*)
        if ! has '^medias:'; then

            status="FAIL"

            details="no sources"

        elif ! has '^title: .'; then

            status="FAIL"

            details="no title"

        # NOTE: A backend can pick up raw JSON from a page it did not expect.
        elif has '^\(title\|author\): "[^"]*":'; then

            status="FAIL"

            details="broken metadata"
        fi;;
    COVER\ NO\ MATCH*)
        if has '^cover: .'; then

            status="FAIL"

            details="wrong cover"
        fi;;
    COVER*)
        if ! has '^cover: .'; then

            status="FAIL"

            details="no cover"
        fi;;
    *)
        if ! has '^ *\(track\|folder\|playlist\|item\):'; then

            status="FAIL"

            details="no entries"
        fi;;
    esac

    if [ "$status" = "FAIL" ]; then

        details="$details, exit code $code"
    fi

    result "$1" "$status" "$time" "$requests" "$details"

    if [ "$level" != "extract" ] && [ "$status" = "OK" ]; then

        video=$(highest medias)
        audio=$(highest audios)

        if [ -n "$video" ]; then

            stream "$1 video ${video%% *}" "${video#* }"
        fi

        if [ -n "$audio" ]; then

            stream "$1 audio" "${audio#* }"
        fi
    fi

    echo ""
}

# A track from a backend that gives metadata and no sources.
test_info()
{
    if [ "$level" = "play" ]; then

        return 0
    fi

    echo "$1 $2"

    if skip "$1"; then

        return 0
    fi

    run "$1" "$2"

    if has '^title: .'; then

        result "$1" "OK" "$time" "$requests" ""
    else
        result "$1" "FAIL" "$time" "$requests" "no title, exit code $code"
    fi

    echo ""
}

# A request that has to fail cleanly, without a crash or a hang.
test_failure()
{
    if [ "$level" = "play" ]; then

        return 0
    fi

    echo "$1 $2"

    run "$1" "$2"

    if [ "$code" = "1" ]; then

        result "$1" "OK" "$time" "" ""
    else
        result "$1" "FAIL" "$time" "" "exit code $code, expected 1"
    fi

    echo ""
}

# Plays a source in Sky-runtime for a few seconds, only at the play level. This opens a window.
# 1: label, 2: source, 3: quality.
play()
{
    if [ "$level" != "play" ]; then

        return 0
    fi

    echo "PLAY $1 $2 $3"

    folder="$results/$name/play-$(echo "$1" | tr ' ' '-')"

    mkdir -p "$folder"

    rm -f "$folder/result.txt"
    rm -rf "$sky/storage"

    # NOTE: On Windows we need a real path, because this one ends up in a QML string.
    path=$(cd "$folder" && { pwd -W 2> /dev/null || pwd; })

    sed -e "s|@DIR@|$path/|" -e "s|@SOURCE@|$2|" -e "s|@QUALITY@|$3|" \
        -e "s|@SECONDS@|$PLAY_SECONDS|" "$directory/play.sky" > "$folder/player.sky"

    (cd "$sky" && timeout $((PLAY_SECONDS + 90)) ./sky "$path/player.sky") > "$folder/log.txt" 2>&1

    error=""
    playing=""
    played=0
    wall=1
    buffering=""
    seek=""

    # NOTE: The script writes shell variables.
    if [ -f "$folder/result.txt" ]; then

        . "$folder/result.txt"
    else
        error="no result, see $folder/log.txt"
    fi

    speed=$(awk -v p="$played" -v w="$wall" 'BEGIN { printf "%.2f", p / w }')

    details="speed ${speed}x, buffering $buffering, seek $seek ms $error"

    if [ -n "$error" ] || [ "$buffering" != "0" ] \
       || [ "$(awk -v s="$speed" 'BEGIN { print (s < 0.98) }')" = "1" ]; then

        result "$1 play $3" "FAIL" "$playing" "" "$details"
    else
        result "$1 play $3" "OK" "$playing" "" "$details"
    fi

    echo ""
}
