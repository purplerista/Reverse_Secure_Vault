#!/bin/sh
if [ $# -lt 1 ]
then
  echo "Usage $0 bin_file"
  exit 0
fi
qltool run -f $1 --rootfs ./rootfs --verbose off
