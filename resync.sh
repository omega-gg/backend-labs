#!/bin/sh
set -e

# Lists what we changed in the vbml folder and still have to apply to the public backend repository.
# This changes nothing, see resync.md for how to apply it.

#--------------------------------------------------------------------------------------------------
# Settings
#--------------------------------------------------------------------------------------------------

root=$(dirname "$(readlink -f "$0")")

cd "$root"

mkdir -p build

#--------------------------------------------------------------------------------------------------
# Public backend
#--------------------------------------------------------------------------------------------------

rm -rf build/public

git clone --quiet --depth 1 https://github.com/omega-gg/backend build/public

public=$(git -C build/public rev-parse --short HEAD)

rm -rf build/public/.git

# NOTE: The last resync: our commit, then the public commit it matches.
labs=""
synced=""

if [ -f resync.lock ]; then

    labs=$(sed -n 1p resync.lock)
    synced=$(sed -n 2p resync.lock)
fi

if [ "$public" != "$synced" ]; then

    echo "The public backend moved, it is at $public and we last synced with ${synced:-nothing}."
    echo "Bring those changes in first, see resync.md."
    echo ""
fi

#--------------------------------------------------------------------------------------------------
# Changes
#--------------------------------------------------------------------------------------------------

echo "--- commits since the last resync ---"

if [ -n "$labs" ]; then

    git --no-pager log --oneline "$labs..HEAD" -- vbml
else
    git --no-pager log --oneline -- vbml
fi

echo ""
echo "--- files that differ from the public backend ---"

# NOTE: This exits with an error code when there are differences, and that's fine here.
git --no-pager -c core.safecrlf=false diff --no-index --ignore-cr-at-eol --stat \
    build/public vbml || true
