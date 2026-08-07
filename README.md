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
- Downgrade firmware: `T6GS-4.1.0.2669-rel-upgrade.bin` (by @fourkox — download from right.com.cn thread [360 T6GS详细刷机教程](https://www.right.com.cn/forum/thread-8457978-1-1.html))
- Custom U-Boot: `u-boot-mt7621.bin` (built from this repo)
- NOR firmware: built from this repo

### Critical: MT7621 power sequence

MT7621 boards require powering on **before** connecting USB-TTL. If you plug in USB-TTL first, the board will not boot.

Correct order:

1. Power on the router
2. Wait 3-5 seconds
3. Plug USB-TTL into PC

This is a known quirk of MT7621 — work quickly between steps.

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

> **Note:** Due to the MT7621 power sequence quirk, you may need to try several times to catch the failsafe prompt. Be patient and quick.

1. Open PuTTY → Serial → select COM port (check Device Manager)
2. Baud rate: **115200**
3. Connect Ethernet cable between router LAN port and PC
4. Set PC network adapter to static IP:
   - IP: `192.168.2.2`
   - Subnet mask: `255.255.255.0`
   - Gateway: `192.168.2.1`
5. Power on the router → wait 3-5s → plug USB-TTL into PC
6. When you see `Press the [f] key and hit [enter] to enter failsafe mode` → press **f** + Enter
7. If you miss the prompt, power cycle and try again. You can also:
   - Reboot from the stock web UI (192.168.0.1 or 192.168.1.1)
   - During reboot, spam `f` + Enter in the serial console

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

## Alternative: Using Breed

Instead of the custom U-Boot from this repo, you can install [Breed](https://breed.hackpascal.net/) (a universal bootloader for MT7621 routers).

### Install Breed

Same TTL process as the U-Boot method above, but in **Step 6**, use Breed instead:

1. Download `breed-mt7621-xxx.bin` from [breed.hackpascal.net](https://breed.hackpascal.net/) (choose a build compatible with your flash size)
2. Transfer it via HFS (same method as u-boot)
3. Flash via telnet:
   ```
   cd /tmp
   wget http://192.168.2.x:8080/breed-mt7621-xxx.bin
   mtd write breed-mt7621-xxx.bin u-boot
   ```

### Enter Breed

1. Power off the router
2. **Hold the reset button** and power on
3. Wait for the green LED to blink, then release reset
4. Open browser and go to **192.168.1.1**
5. Breed web interface appears

### Flash firmware via Breed

1. Go to **Firmware Upgrade**
2. Check **Firmware** and select your NOR `.bin` file
3. Set Flash Layout to **public 0x50000**
4. Click **Upload** and wait for the router to reboot

### ⚠️ Breed limitations on 360T6GS

Breed is designed for NAND-based routers and may not handle NOR flash perfectly:

- Partition detection may be incorrect
- Environment variables might not persist
- Some Breed builds may not boot NOR firmware reliably

For best results on 360T6GS, the **custom U-Boot from this repo** (configured for NOR flash) is recommended.

## Credits

Special thanks to **善良的坏boy** from the Right.com.cn forum for creating the original hardware device tree configuration that made this possible!
