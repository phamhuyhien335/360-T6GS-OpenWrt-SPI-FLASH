# 360T6GS NOR Auto Build

Source-only, CI-first repository for building NOR-safe firmware variants for Qihoo 360T6GS via GitHub Actions.

## Why NOR-only

Most 360T6GS upstream builds are for the 128MB NAND flash. When flashing through Breed on this router, writing a NAND-oriented image can cause bootloop. This repo bypasses NAND and uses SPI NOR layout (`jedec,spi-nor`) to match the Breed flashing path.

## Repository layout

- `mt7621_qihoo_360t6gs.dts` — custom NOR DTS used by the NOR build variant
- `scripts/apply-t6gs-nor.sh` — applies NOR DTS + image recipe patch into upstream source
- `.github/workflows/build-360t6gs-all-wrt.yml` — matrix workflow that builds NOR firmware variants
- `.github/workflows/build-uboot-360t6gs.yml` — builds custom U-Boot for 360T6GS

## Build firmware on GitHub Actions

1. Go to the **Actions** tab
2. Select **Build 360T6GS NOR WRT**
3. Click **Run workflow**
4. Wait for all matrix jobs to finish
5. Download artifacts from each job

Each artifact contains files from `bin/targets/ramips/mt7621/` for that variant.

Artifact job names:

| Job | Source | Branch |
|-----|--------|--------|
| `openwrt-main-nor` | openwrt/openwrt | main |
| `immortalwrt-main-nor` | immortalwrt/immortalwrt | master |
| `lede-main-nor` | coolsnowwolf/lede | master |
| `x-wrt-main-nor` | x-wrt/x-wrt | master |
| `lienol-main-nor` | Lienol/openwrt | 25.12 |

## Build U-Boot

A custom U-Boot is required to flash firmware on the 360T6GS. Build it via GitHub Actions:

1. Go to the **Actions** tab
2. Select **Build 360T6GS U-Boot**
3. Click **Run workflow**
4. Download the `u-boot-T6GS` artifact

The U-Boot is configured with:

| Parameter | Value |
|-----------|-------|
| Flash Type | NOR |
| MTD Partition | `192k(u-boot),64k(u-boot-env),64k(factory),-(firmware)` |
| Kernel Load Address | `0x50000` |
| Reset GPIO | 7 |
| System LED GPIO | 13 |
| CPU Frequency | 880 MHz |
| DRAM Frequency | 1200 MT/s |
| DDR Init | DDR3-128MiB-KGD |
| Baud Rate | 115200 |

## Flash guide

The 360T6GS ships with stock Qihoo firmware and no custom bootloader. You need to install U-Boot first before flashing OpenWrt.

### Prerequisites

- USB-TTL adapter (CH341, CH340, or similar)
- 3x DuPont wires
- Soldering iron + solder
- PuTTY (or any serial terminal)
- HFS (HTTP File Server) or any HTTP file server
- Downgrade firmware: `T6GS-4.1.0.2669-rel-upgrade.bin` (by @fourkox, from right.com.cn)
- Custom U-Boot: `u-boot-mt7621.bin` (built from this repo)
- NOR firmware: built from this repo

### Step 1: Downgrade stock firmware

1. Reset the router (hold reset 10s)
2. Access the web UI at `192.168.0.1` or `192.168.1.1`
3. Flash `T6GS-4.1.0.2669-rel-upgrade.bin` via the upgrade page
4. Reset again after flashing

### Step 2: Disassemble the router

1. Peel off the label on the bottom — there is a hidden screw underneath
2. Remove all screws and open the case

### Step 3: Solder TTL wires

Solder 3 wires to the pads on the **back side, upper right corner**:

| Router Pad | Wire |
|------------|------|
| GND | GND |
| RX | RX |
| TX | TX |

Connect to USB-TTL: **GND↔GND, RX↔TX, TX↔RX**

### Step 4: Enter failsafe mode

1. Open PuTTY → Serial → select COM port (check Device Manager)
2. Baud rate: **115200**
3. Power on the router
4. When you see `Press the [f] key and hit [enter] to enter failsafe mode` → press **f** + Enter

### Step 5: Enable telnet

Enter these commands in failsafe mode:

```
mount_root
sed -i 's/.*local debug=.*/\tlocal debug=1/' /etc/init.d/telnet
passwd root
```

Set a root password when prompted.

### Step 6: Flash U-Boot via telnet

1. Disconnect USB-TTL
2. Connect router LAN port to PC with Ethernet cable
3. Power on the router normally
4. Open HFS → drag `u-boot-mt7621.bin` into the window
5. Copy the HTTP link (e.g., `http://192.168.2.x:8080/u-boot-mt7621.bin`)
6. Open PuTTY → Telnet → connect to `192.168.1.1`
7. Login with `root` and the password you set
8. Run:

```
cd /tmp
wget http://192.168.2.x:8080/u-boot-mt7621.bin
mtd write u-boot-mt7621.bin u-boot
```

You should see `Writing from u-boot-mt7621.bin to u-boot ...` on success.

### Step 7: Flash NOR firmware via U-Boot

1. Power off the router
2. **Hold the reset button** and power on
3. Wait for the green LED to blink 3-4 times, then release reset
4. Open browser and go to **192.168.1.1**
5. The U-Boot web interface appears — upload your NOR `.bin` firmware
6. After flashing, the router may not reboot automatically — power cycle manually

### Step 8: First boot

The first boot of OpenWrt is slow (can take several minutes). Be patient.

Access LuCI at `192.168.1.1`.

## NOR flash usage note

The NOR variant runs on the 16MB SPI NOR chip with approximately **6.8MB** of free space for packages. LuCI and SQM are included out of the box.

## Breed flash setting

If using Breed (not the custom U-Boot from this repo):

- Flash Layout: `public 0x50000`

## Credits

Special thanks to **善良的坏boy** from the Right.com.cn forum for creating the original hardware device tree configuration that made this possible!
