#!/bin/sh

#--------------------------------------------------------------------------------------------------
# Settings
#--------------------------------------------------------------------------------------------------

# NOTE: Defaults to the vbml folder, or takes another folder of backends.
folder=${1:-$(dirname "$(dirname "$(readlink -f "$0")")")/vbml}

status=0

#--------------------------------------------------------------------------------------------------
# Check
#--------------------------------------------------------------------------------------------------

# NOTE: A row needs 4 values or the engine drops it. A version that differs from the file makes the
#       engine download the public backend over the local one, even in a dev build.
for index in index indexLite; do

    tr -d '\r' < "$folder/$index.vbml" | awk -v folder="$folder" -v index_name="$index" '
        /^backends: *\|/  { inside = 1; next }
        inside && /^[^ ]/ { inside = 0 }
        inside && NF {
            if (NF != 4) {
                print "LINT " index_name ": the " $1 " row has " NF " values"
                status = 1
                next
            }
            version = ""
            file = folder "/" $1 ".vbml"
            while (version == "" && (getline line < file) > 0) {
                sub(/\r$/, "", line)
                if (line ~ /^version: /) { version = line; sub(/^version: */, "", version) }
            }
            close(file)
            if (version != $3) {
                print "LINT " index_name ": " $1 " is " $3 " and its file is " version
                status = 1
            }
        }
        END { exit status }' || status=1
done

if [ $status = 0 ]; then

    echo "[OK] lint"
fi

exit $status
