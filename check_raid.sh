#!/bin/sh
base=$(dirname $(readlink -f "$0"))

exec "${PERL:-perl}" -I"$base/lib" "$base/bin/check_raid.pl" "$@"
