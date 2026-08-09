#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 /path/to/openwrt-or-immortalwrt-source"
  exit 1
fi

ROOT="$1"
MK_FILE="$ROOT/target/linux/mediatek/image/filogic.mk"

if [ ! -f "$MK_FILE" ]; then
  echo "Missing file: $MK_FILE"
  exit 1
fi

MESH_PKGS="wpad-mesh-mbedtls luci-app-sqm luci-app-ttyd"

tmp_file="$(mktemp)"

awk -v mesh="$MESH_PKGS" '
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
    if (line !~ /wpad-mesh-mbedtls/) {
      sub(/[[:space:]]*$/, "", line)
      print line " " mesh
    } else { print }
    done=1
    inblock=0
    next
  }
  if (inblock && line ~ /^endef[[:space:]]*$/) {
    if (done == 0) {
      print "\tDEVICE_PACKAGES := " mesh
      done=1
    }
    inblock=0
    next
  }
  print
}
' "$MK_FILE" > "$tmp_file"

mv "$tmp_file" "$MK_FILE"

echo "Applied 360T7 mesh patch to: $ROOT"
