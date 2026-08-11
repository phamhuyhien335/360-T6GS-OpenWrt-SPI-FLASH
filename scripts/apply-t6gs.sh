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

MK_FILE="$ROOT/target/linux/ramips/image/mt7621.mk"
DTS_DST="$ROOT/target/linux/ramips/dts/mt7621_qihoo_360t6gs.dts"
DTS_SRC="$(cd "$(dirname "$0")/.." && pwd)/mt7621_qihoo_360t6gs.dts"

if [ ! -f "$MK_FILE" ]; then
  echo "Missing file: $MK_FILE"
  exit 1
fi

if [ ! -f "$DTS_SRC" ]; then
  echo "Missing file: $DTS_SRC"
  exit 1
fi

PKGS="kmod-mt7915-firmware wpad-openssl luci luci-app-sqm luci-app-ttyd luci-app-filebrowser luci-app-easymesh luci-app-client-manager"

cp "$DTS_SRC" "$DTS_DST"

tmp_file="$(mktemp)"
awk -v pkgs="$PKGS" '
function emit() {
  print "define Device/qihoo_360t6gs"
  print "  $(Device/nand)"
  print "  $(Device/uimage-lzma-loader)"
  print "  DEVICE_VENDOR := Qihoo"
  print "  DEVICE_MODEL := 360T6GS"
  print "  IMAGE_SIZE := 121520k"
  print "  IMAGES += firmware.bin"
  print "  IMAGE/firmware.bin := append-kernel | pad-to $$(KERNEL_SIZE) | append-ubi | check-size"
  print "  DEVICE_PACKAGES := " pkgs
  print "endef"
  print "TARGET_DEVICES += qihoo_360t6gs"
}
BEGIN { inblock=0; seen=0 }
/^define Device\/qihoo_360t6gs$/ {
  inblock=1
  seen=1
  emit()
  next
}
inblock && /^TARGET_DEVICES \+= qihoo_360t6gs$/ {
  inblock=0
  next
}
inblock { next }
{ print }
END {
  if (seen == 0) {
    print ""
    emit()
  }
}
' "$MK_FILE" > "$tmp_file"
mv "$tmp_file" "$MK_FILE"

echo "Applied NAND patch to: $ROOT"
