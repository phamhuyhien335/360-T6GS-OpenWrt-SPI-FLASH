#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 /path/to/openwrt-or-immortalwrt-source"
  exit 1
fi

ROOT="$1"
REPO="$(cd "$(dirname "$0")/.." && pwd)"

MAC80211_DIR="$ROOT/package/kernel/mac80211/patches/subsys"
HOSTAPD_DIR="$ROOT/package/network/services/hostapd/patches"

if [ ! -d "$MAC80211_DIR" ]; then
  echo "Missing dir: $MAC80211_DIR"
  exit 1
fi

if [ ! -d "$HOSTAPD_DIR" ]; then
  echo "Missing dir: $HOSTAPD_DIR"
  exit 1
fi

cp "$REPO/patches/mac80211/400-mac80211-defer-ap-side-ft-key-upload.patch" "$MAC80211_DIR/"
cp "$REPO/patches/hostapd/999-hostapd-ft-readd-unassociated-sta-before-ptk.patch" "$HOSTAPD_DIR/"

echo "Applied FT key-addition-fix patches to: $ROOT"
