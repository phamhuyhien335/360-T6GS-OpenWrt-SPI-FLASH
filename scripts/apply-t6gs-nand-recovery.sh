#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 /path/to/openwrt-or-immortalwrt-source"
  exit 1
fi

ROOT="$1"
MK_FILE="$ROOT/target/linux/ramips/image/mt7621.mk"
DTS_DST="$ROOT/target/linux/ramips/dts/mt7621_qihoo_360t6gs.dts"
DTS_SRC="$(cd "$(dirname "$0")/.." && pwd)/mt7621_qihoo_360t6gs-nand-recovery.dts"

if [ ! -f "$MK_FILE" ]; then
  echo "Missing file: $MK_FILE"
  exit 1
fi

if [ ! -f "$DTS_SRC" ]; then
  echo "Missing file: $DTS_SRC"
  exit 1
fi

cp "$DTS_SRC" "$DTS_DST"

tmp_file="$(mktemp)"
awk '
BEGIN { inblock=0; seen=0 }
/^define Device\/qihoo_360t6gs$/ {
  inblock=1
  seen=1
  print "define Device/qihoo_360t6gs"
  print "  $(Device/nand)"
  print "  $(Device/uimage-lzma-loader)"
  print "  DEVICE_VENDOR := Qihoo"
  print "  DEVICE_MODEL := 360T6GS"
  print "  IMAGE_SIZE := 125000k"
  print "  KERNEL_IN_UBI := 1"
  print "  IMAGES += firmware.bin"
  print "  IMAGE/firmware.bin := append-kernel | pad-to $$(KERNEL_SIZE) | append-ubi | check-size"
  print "  DEVICE_PACKAGES += kmod-mt7915-firmware luci luci-app-sqm sqm-scripts ttyd"
  print "endef"
  print "TARGET_DEVICES += qihoo_360t6gs"
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
    print "define Device/qihoo_360t6gs"
    print "  $(Device/nand)"
    print "  $(Device/uimage-lzma-loader)"
    print "  DEVICE_VENDOR := Qihoo"
    print "  DEVICE_MODEL := 360T6GS"
    print "  IMAGE_SIZE := 125000k"
    print "  KERNEL_IN_UBI := 1"
    print "  IMAGES += firmware.bin"
    print "  IMAGE/firmware.bin := append-kernel | pad-to $$(KERNEL_SIZE) | append-ubi | check-size"
    print "  DEVICE_PACKAGES += kmod-mt7915-firmware luci luci-app-sqm sqm-scripts ttyd"
    print "endef"
    print "TARGET_DEVICES += qihoo_360t6gs"
  }
}
' "$MK_FILE" > "$tmp_file"
mv "$tmp_file" "$MK_FILE"

echo "Applied NAND RECOVERY patch to: $ROOT"
