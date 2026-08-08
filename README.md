# 360T6GS NAND Auto Build

Source-only, CI-first repository for building NAND firmware for the Qihoo 360T6GS via GitHub Actions.

The 360T6GS uses a **128MB NAND** flash (ESMT PSU1GA30DT, SLC). There is no SPI NOR flash on this device.

## Repository layout

- `mt7621_qihoo_360t6gs-nand.dts` — NAND device tree used by the normal build variant
- `mt7621_qihoo_360t6gs-nand-recovery.dts` — recovery variant: makes the `u-boot` partition writable so the bootloader can be restored from Linux (`mtd write`)
- `scripts/apply-t6gs-nand.sh` — applies NAND DTS + image recipe patch into upstream source
- `scripts/apply-t6gs-nand-recovery.sh` — same, using the recovery DTS
- `.github/workflows/build-360t6gs-all-wrt.yml` — matrix workflow that builds NAND firmware variants
- `.github/workflows/build-uboot-360t6gs-nand.yml` — builds custom U-Boot for 360T6GS (NAND)
- `.github/workflows/build-recovery-nand.yml` — builds the recovery initramfs (writable u-boot partition)

## NAND layout

| Partition | Offset | Size | Note |
|-----------|--------|------|------|
| u-boot | 0x000000 | 512K | read-only in normal build |
| u-boot-env | 0x080000 | 256K | |
| Factory | 0x0c0000 | 256K | read-only, holds MAC/EEPROM |
| kernel | 0x180000 | 4MB | legacy uImage |
| firmware | 0x580000 | rest | UBI |

## Build firmware on GitHub Actions

1. Go to the **Actions** tab
2. Select **Build 360T6GS WRT**
3. Click **Run workflow**
4. Wait for all matrix jobs to finish
5. Download artifacts from each job

Each artifact contains files from `bin/targets/ramips/mt7621/` for that variant.

Artifact job names:

| Job | Source | Branch |
|-----|--------|--------|
| `openwrt-main-nand` | openwrt/openwrt | main |
| `immortalwrt-main-nand` | immortalwrt/immortalwrt | master |
| `lede-main-nand` | coolsnowwolf/lede | master |
| `x-wrt-main-nand` | x-wrt/x-wrt | master |
| `lienol-main-nand` | Lienol/openwrt | 25.12 |

## Build U-Boot

A custom U-Boot is required to flash firmware on the 360T6GS. Build it via GitHub Actions:

1. Go to the **Actions** tab
2. Select **Build 360T6GS U-Boot (NAND)**
3. Click **Run workflow**
4. Download the `u-boot-T6GS-nand` artifact

The U-Boot is configured with:

| Parameter | Value |
|-----------|-------|
| Flash Type | NAND |
| MTD Partition | `512k(u-boot),256k(u-boot-env),256k(factory),-(firmware)` |
| Kernel Load Address | `0x0` |
| Reset GPIO | 7 |
| System LED GPIO | 13 |
| CPU Frequency | 880 MHz |
| DRAM Frequency | 1200 MT/s |
| DDR Init | DDR3-256MiB |
| Baud Rate | 115200 |

## Flashing guide

The 360T6GS ships with stock Qihoo firmware and no custom bootloader. You need to install U-Boot first before flashing OpenWrt.

### Prerequisites

- USB-TTL adapter (CH341, CH340, or similar)
- 3x DuPont wires
- Soldering iron + solder
- PuTTY (or any serial terminal)
- HTTP file server (HFS, or tftpd)
- Downgrade firmware: `T6GS-4.1.0.2669-rel-upgrade.bin` (by @fourkox — download from right.com.cn thread [360 T6GS详细刷机教程](https://www.right.com.cn/forum/thread-8457978-1-1.html))
- Custom U-Boot: `u-boot-T6GS-nand.bin` (built from this repo)
- NAND firmware: built from this repo

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
4. Open HFS → drag `u-boot-T6GS-nand.bin` into the window
5. Copy the HTTP link (e.g., `http://192.168.2.x:8080/u-boot-T6GS-nand.bin`)
6. Open PuTTY → Telnet → connect to `192.168.1.1`
7. Login with `root` and the password you set
8. Run:

```
cd /tmp
wget http://192.168.2.x:8080/u-boot-T6GS-nand.bin
mtd write u-boot-T6GS-nand.bin u-boot
```

You should see `Writing from u-boot-T6GS-nand.bin to u-boot ...` on success.

### Step 7: Flash NAND firmware via U-Boot

1. Power off the router
2. **Hold the reset button** and power on
3. Wait for the green LED to blink 3-4 times, then release reset
4. Open browser and go to **192.168.1.1**
5. The U-Boot web interface appears — upload your NAND `.bin` firmware (use the `squashfs-firmware.bin` image)
6. After flashing, the router may not reboot automatically — power cycle manually

### Step 8: First boot

The first boot of OpenWrt is slow (can take several minutes). Be patient.

Access LuCI at `192.168.1.1`.

## Recovering a bricked u-boot partition

If the `u-boot` partition was accidentally overwritten (e.g. flashing the wrong image), the normal firmware DTS marks it `read-only`, which prevents `mtd write` from restoring it. Use the recovery initramfs instead:

1. Build **Build recovery initramfs** (`build-recovery-nand.yml`) → get `...-initramfs-kernel.bin`
2. Boot it via U-Boot TFTP: copy the file as `recovery.bin` into the tftpd base directory, power on the router with the reset button pressed, and it downloads `recovery.bin` to RAM
3. In the booted Linux, download the original bootloader and write it back:
   ```
   cd /tmp
   wget http://<PC-IP>:8080/360_T6GS-u-boot.bin
   mtd write 360_T6GS-u-boot.bin u-boot
   mtd verify 360_T6GS-u-boot.bin u-boot
   ```
4. Power cycle — the router boots from NAND again

The recovery DTS only removes `read-only` from the `u-boot` partition; the `Factory` partition stays read-only.

## Credits

Special thanks to **善良的坏boy** from the Right.com.cn forum for creating the original hardware device tree configuration that made this possible!
