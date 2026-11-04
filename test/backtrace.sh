#!/bin/sh
set -e

# Runs a query in gdb and prints where clientVBML crashes. Needs gdb in your PATH, and a clientVBML
# built with symbols for a readable result, by adding CONFIG+=force_debug_info to its qmake call.
#
# Usage: sh backtrace.sh <url | query>

#--------------------------------------------------------------------------------------------------
# Settings
#--------------------------------------------------------------------------------------------------

root=$(dirname "$(dirname "$(readlink -f "$0")")")

CLIENT_BIN=${CLIENT_BIN:-$root/../clientVBML/bin}

export MSYS_NO_PATHCONV=1

#--------------------------------------------------------------------------------------------------
# Syntax
#--------------------------------------------------------------------------------------------------

if [ $# != 1 ]; then

    echo "Usage: sh backtrace.sh <url | query>"

    exit 1
fi

#--------------------------------------------------------------------------------------------------
# Run
#--------------------------------------------------------------------------------------------------

client="$root/build/clientVBML/bin"

mkdir -p "$client"

cp -r "$CLIENT_BIN"/. "$client"

cd "$client"

rm -rf storage

gdb -q -batch -ex run -ex "bt 20" --args ./clientVBML "$1"
