#!/bin/sh

lnk=`readlink -f $0`
base=`dirname $lnk`

exec perl -I${base}/lib ${base}/bin/check_raid.pl "$@"
