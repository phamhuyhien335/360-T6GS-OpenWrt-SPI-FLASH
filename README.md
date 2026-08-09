# Qihoo 360T6GS & 360T7 NAND Auto Build

Source-only, CI-first repository for building NAND firmware for the **Qihoo 360T6GS** and **Qihoo 360T7** via GitHub Actions.

Both devices use **128MB NAND** flash (no SPI NOR):

| Device | SoC | Target |
|--------|-----|--------|
| 360T6GS | MT7621 + MT7915 | `ramips/mt7621` |
| 360T7 | MT7981 (Filogic) | `mediatek/filogic` |

Both firmware variants include `wpad-mesh-mbedtls` (802.11s mesh + 802.11r fast roaming), so a 360T6GS and a 360T7 can be meshed and roaming together.

On top of that, both variants install `luci-app-sqm` (SQM/queue-management UI) and `luci-app-ttyd` (web terminal). Their dependencies (`sqm-scripts`, `ttyd`, `luci-base`, ...) are pulled in automatically by the package manager — they are not listed explicitly in `DEVICE_PACKAGES`.

## Repository layout

- `mt7621_qihoo_360t6gs.dts` — NAND device tree used by the normal build variant (T6GS)
- `mt7621_qihoo_360t6gs-recovery.dts` — recovery variant: makes the `u-boot` partition writable so the bootloader can be restored from Linux (`mtd write`)
- `scripts/apply-t6gs.sh` — applies NAND DTS + image recipe patch into upstream source (includes `wpad-mesh-mbedtls`)
- `scripts/apply-t6gs-recovery.sh` — same, using the recovery DTS
- `scripts/apply-t7.sh` — patches `qihoo_360t7` profile in upstream source to add `wpad-mesh-mbedtls`
- `.github/workflows/build-360t6gs-all-wrt.yml` — matrix workflow that builds 360T6GS firmware variants
- `.github/workflows/build-360t7-all-wrt.yml` — matrix workflow that builds 360T7 firmware variants
- `.github/workflows/build-uboot-360t6gs.yml` — builds custom U-Boot for 360T6GS
- `.github/workflows/build-recovery.yml` — builds the recovery initramfs (writable u-boot partition)

## NAND layout

| Partition | Offset | Size | Note |
|-----------|--------|------|------|
| u-boot | 0x000000 | 512K | read-only in normal build |
| u-boot-env | 0x080000 | 256K | |
| Factory | 0x0c0000 | 256K | read-only, holds MAC/EEPROM |
| kernel | 0x180000 | 4MB | legacy uImage |
| firmware | 0x580000 | rest | UBI |

## Build firmware on GitHub Actions

Each device has its own matrix workflow:

| Workflow | Device | Target |
|----------|--------|--------|
| `Build 360T6GS WRT` | 360T6GS | `ramips/mt7621` |
| `Build 360T7 WRT` | 360T7 | `mediatek/filogic` |

1. Go to the **Actions** tab
2. Select the workflow for your device
3. Click **Run workflow**
4. Wait for all matrix jobs to finish
5. Download artifacts from each job

Each T6GS artifact contains files from `bin/targets/ramips/mt7621/`; each T7 artifact contains files from `bin/targets/mediatek/filogic/`.

Artifact job names (same matrix for both workflows):

| Job | Source | Branch |
|-----|--------|--------|
| `openwrt-main` | openwrt/openwrt | main |
| `immortalwrt-main` | immortalwrt/immortalwrt | master |
| `lede-main` | coolsnowwolf/lede | master |
| `x-wrt-main` | x-wrt/x-wrt | master |
| `lienol-main` | Lienol/openwrt | 25.12 |

## Build U-Boot

A custom U-Boot is required to flash firmware on the 360T6GS. Build it via GitHub Actions:

1. Go to the **Actions** tab
2. Select **Build 360T6GS U-Boot**
3. Click **Run workflow**
4. Download the `u-boot-T6GS` artifact

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
- Custom U-Boot: `u-boot-T6GS` artifact (built from this repo)
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
4. Open HFS → drag `u-boot-T6GS.bin` into the window
5. Copy the HTTP link (e.g., `http://192.168.2.x:8080/u-boot-T6GS.bin`)
6. Open PuTTY → Telnet → connect to `192.168.1.1`
7. Login with `root` and the password you set
8. Run:

```
cd /tmp
wget http://192.168.2.x:8080/u-boot-T6GS.bin
mtd write u-boot-T6GS.bin u-boot
```

You should see `Writing from u-boot-T6GS.bin to u-boot ...` on success.

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

1. Build **Build 360T6GS Recovery Initramfs** (`build-recovery.yml`) → get `...-initramfs-kernel.bin`
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

## 360T7 overview

The 360T7 is a MediaTek **MT7981** (Filogic 820) board with 128MB NAND. It is **different hardware** from the 360T6GS (MT7621 + MT7915); its device tree and profiles live upstream in `target/linux/mediatek/image/filogic.mk` and `target/linux/mediatek/dts/mt7981b-qihoo-360t7.dts`.

The 360T7 firmware is built on the **same 5-source matrix** as the T6GS, with `scripts/apply-t7.sh` adding `wpad-mesh-mbedtls` so it can mesh/roam with a T6GS.

## 360T7 flash

The stock 360T7 ships with MediaTek/Qihoo stock bootloader (it exposes a U-Boot web UI on `192.168.1.1` when reset is held at power-on). To install ImmortalWrt:

1. Build firmware via **Build 360T7 WRT** workflow → download `...qihoo_360t7-squashfs-sysupgrade.itb`
2. Power off, **hold reset**, power on → U-Boot web UI appears at `192.168.1.1`
3. Upload the `.itb` file and flash. Power cycle when done.

(First boot is again slow — wait several minutes before accessing LuCI.)

## Mesh + roaming between 360T6GS and 360T7

Both firmware builds include `wpad-mesh-mbedtls`, which provides:

- **802.11s mesh** forwarding (the `wpad-basic-*` package does **not** support mesh, so it is replaced by `wpad-mesh-mbedtls`)
- **802.11r/FT fast roaming** between the two APs

Because the 360T6GS (MT7621+MT7915) and 360T7 (MT7981) are unrelated chipsets, a plain wireless-repeater/"same SSID" setup will **not** let clients roam automatically. Instead use a real **802.11s mesh** link: on the 5 GHz radio of each node go to **Network → Wireless → Add** (mesh mode) and configure:

| Setting | Value |
|---------|-------|
| Mode | **802.11s** |
| Network | mesh (create new) |
| Mesh ID | same on both nodes, e.g. `360mesh` |
| Encryption | **SAE** (same password on both nodes) |
| Band | **5 GHz (AC/AX)** — both chips support it |

Then bridge the mesh interface + your client network together (e.g. attach the mesh interface to the `lan` bridge, or run `batman-adv` if you want layer-3 mesh routing).

> **Note:** Pure 802.11s mesh between an MT7981 (T7) and MT7621 (T6GS) node works fine. A known caveat is that **batman-adv over wireless mesh on MT7981/MT7986 is slow (≈2–3 Mbps TX)** ([openwrt#18703](https://github.com/openwrt/openwrt/issues/18703)); pure 802.11s or a wired bridge is the recommended backhaul.

For **802.11r FT roaming** on the client (SSID) network, create an identical `wifi-iface` (AP) on both nodes. The mesh interface itself does the inter-node forwarding; the AP interface is what wireless clients connect to. On both nodes:

| Setting | Value |
|---------|-------|
| Mode | **Access** (AP) |
| Network | lan |
| SSID | same on both nodes |
| Encryption | WPA2-PSK (or WPA3-SAE) |
| IEEE 802.11r | **enabled** (FT) |
| Mobility domain | same 4-hex on both nodes, e.g. `1337` |
| FT protocol | `FT over the DS` (`ft_over_ds=1`) — reliable between mixed chipsets |
| PMK R1 push | enabled |

For multi-AP FT, pre-share the **R0KH/R1KH** keys so each AP can authenticate a roaming station for the others. Put this under `config wifi-device`/`hostapd` (see OpenWrt `hostapd.operations` docs):

| Field | On the primary node | On the secondary node |
|-------|--------------------|-----------------------|
| `r0kh` | `r0kh=00:11:22:33:44:55 360t6gs r0-secret` | `r0kh=00:11:22:33:44:55 360t7 r0-secret` |
| `r1kh` | `r1kh=<MAC-of-T7> 00:11:22:33:44:55 r1-secret` | `r1kh=<MAC-of-T6GS> 00:11:22:33:44:55 r1-secret` |

(`r0kh` MAC/key is the *remote* AP; the second `r0kh` token is an arbitrary label, the third is the shared secret — keep the same shared secret on both.)

Clients doing 802.11r FT will fast-roam between the 360T6GS and 360T7 APs with sub-30 ms transitions as you move between their coverage areas. Roaming is ultimately a client-side decision (802.11k/v/BSS-transition help, but only if the client supports and uses them); a few Android devices are known to disconnect periodically with 802.11r — that is client-side and not fixable from the APs.

> **Note:** On MT7981/MT7621 with recent mac80211, 802.11r roams hit a kernel race that logs `nl80211: kernel reports: key addition failed` and can leave the client associated-but-broken until the next reassociation ([mt76#1098](https://github.com/openwrt/mt76/issues/1098)). The `openwrt-main` and `immortalwrt-main` matrix jobs apply the upstream fix ([openwrt#23181](https://github.com/openwrt/openwrt/pull/23181), still unmerged) via `scripts/apply-ft-fix.sh`, which drops in the `400-mac80211-defer-ap-side-ft-key-upload.patch` and `999-hostapd-ft-readd-unassociated-sta-before-ptk.patch` patches. Older sources (`lede`, `x-wrt`, `lienol`) keep their stock mac80211 since the patch targets 6.18 backports.

## Credits

Special thanks to **善良的坏boy** from the Right.com.cn forum for creating the original hardware device tree configuration that made this possible!
