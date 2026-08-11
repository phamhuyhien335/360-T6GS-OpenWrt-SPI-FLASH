#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 /path/to/source"
  exit 1
}

if [ $# -ne 1 ]; then
  usage
fi

ROOT="$1"

MK_FILE="$ROOT/target/linux/mediatek/image/filogic.mk"

if [ ! -f "$MK_FILE" ]; then
  echo "Missing file: $MK_FILE"
  exit 1
fi

PKGS="wpad-openssl luci luci-app-sqm luci-app-ttyd luci-app-filebrowser luci-app-easymesh luci-app-client-manager"

tmp_file="$(mktemp)"

awk -v pkgs="$PKGS" '
BEGIN { inblock=0; done=0 }
{
  line=$0
  sub(/\r$/, "", line)
  if (line == "define Device/qihoo_360t7-common" || line == "define Device/qihoo_360t7") {
    if (done == 0) { inblock=1 }
    print
    next
  }
  if (inblock && line ~ /^[[:space:]]*DEVICE_PACKAGES[[:space:]]*:?=/) {
    if (line ~ /luci-app-sqm/) {
      print
    } else {
      sub(/[[:space:]]*$/, "", line)
      print line " " pkgs
    }
    done=1
    inblock=0
    next
  }
  if (inblock && line ~ /^endef[[:space:]]*$/) {
    if (done == 0) {
      print "\tDEVICE_PACKAGES := " pkgs
      done=1
    }
    inblock=0
    next
  }
  print
}
' "$MK_FILE" > "$tmp_file"

mv "$tmp_file" "$MK_FILE"

echo "Applied 360T7 patch to: $ROOT"
