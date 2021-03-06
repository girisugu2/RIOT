#!/bin/sh

#
# Copyright (C) 2016 Eistec AB
#
# This file is subject to the terms and conditions of the GNU Lesser General
# Public License v2.1. See the file LICENSE in the top level directory for more
# details.
#

DEBUG=0
if [ "${QUIET}" != "1" ]; then
  DEBUG=1
fi

if [ $# -lt 1 ]; then
  echo "Usage: $0 <output.h> [CFLAGS]..."
  echo "Extract all macros from CFLAGS and generate a header file"
  exit 1
fi
OUTPUTFILE="$1"
shift

MD5SUM=md5sum
if [ "$(uname -s)" = "Darwin" -o "$(uname -s)" = "FreeBSD" ]; then
  MD5SUM="md5 -r"
fi

# atomically update the file
TMPFILE=
trap '[ -n "${TMPFILE}" ] && rm -f "${TMPFILE}"' EXIT
# Create temporary output file
TMPFILE=$(mktemp ${OUTPUTFILE}.XXXXXX)

if [ -z "${TMPFILE}" ]; then
  echo "Error creating temporary file, aborting"
  exit 1
fi

# exit on any errors below this line
set -e

echo "/* DO NOT edit this file, your changes will be overwritten and won't take any effect! */" > "${TMPFILE}"
echo "/* Generated from CFLAGS: $@ */" >> "${TMPFILE}"

[ -n "${LTOFLAGS}" ] && echo "/* LTOFLAGS=${LTOFLAGS} */" >> "${TMPFILE}"

for arg in "$@"; do
  case ${arg} in
    -D*)
      # Strip leading -D
      d=${arg#-D}
      if [ -z "${d##*=*}" ]; then
        # key=value pairs
        key=${d%%=*}
        value=${d#*=}
        echo "#define $key $value" >> "${TMPFILE}"
      else
        # simple #define
        echo "#define $d 1" >> "${TMPFILE}"
      fi
      ;;
    -U*)
      # Strip leading -U
      d=${arg#-U}
      echo "#undef $d" >> "${TMPFILE}"
      ;;
    *)
      continue
      ;;
  esac
done

# Only replace old file if the new file differs. This allows make to check the
# date of the config header for dependency calculations.
NEWMD5=$(${MD5SUM} ${TMPFILE} | cut -c -32)
OLDMD5=$(${MD5SUM} ${OUTPUTFILE} 2>/dev/null | cut -c -32)
if [ "${NEWMD5}" != "${OLDMD5}" ]; then
  if [ "${DEBUG}" -eq 1 ]; then echo "Replacing ${OUTPUTFILE} (${NEWMD5} != ${OLDMD5})"; fi
  # Set mode according to umask
  chmod +rw "${TMPFILE}"
  mv -f "${TMPFILE}" "${OUTPUTFILE}"
else
  if [ "${DEBUG}" -eq 1 ]; then echo "Keeping old ${OUTPUTFILE}"; fi
fi

# $TMPFILE will be deleted by the EXIT trap above if it still exists when we exit
