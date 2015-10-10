#!/bin/sh

lnk=`readlink $0`
base=`dirname $lnk`

exec perl -I${base}/lib ${base}/bin/check_raid.pl "$@"
