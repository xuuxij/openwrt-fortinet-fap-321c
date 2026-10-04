# FortiAP-321C hardware notes

All values below were read from a production unit (board silkscreen
`7016A0886008 V1.00`) unless marked otherwise.

## Identification

- FCC ID: TVE-26145033. Fortinet's filing reuses the internal photos of the Senao
  CAP7250AG (FCC ID U2M-CAP7250AG), which show a pre-production board labelled
  `CAP7250AG 0.20`.
- Production board `7016A0886008` is the board of the WatchGuard AP300, according to
  OpenWrt forum thread 88170, post #1.
- U-Boot banner: `FortiAP-321C (Jan 19 2018 - 15:23:09)`, `Ver:04000004`.

## Chips

| Part | Chip |
|---|---|
| SoC | QCA9558-AT4A (MIPS 74Kc, 720 MHz) |
| RAM | 2x Nanya DDR2, 256 MiB total |
| Flash | Winbond W25Q256**JV**, 32 MiB. JEDEC `ef4019`; SFDP BFPT minor revision 5 means the 4-byte opcodes are present |
| Ethernet PHY | Atheros AR8035-A, RGMII, MDIO address 5 |
| 2.4 GHz | QCA9558 on-chip WMAC (ath9k, reported as AR9550) |
| 5 GHz | QCA9880-BR4A on a mini-PCIe card (PCI `168c:003c`, ath10k) |

## Flash layout (vendor) and OpenWrt mapping

| Offset | Size | Vendor name | OpenWrt name |
|---|---|---|---|
| 0x0000000 | 0x0040000 | u-boot | u-boot (read-only) |
| 0x0040000 | 0x1400000 | rootfs | fwconcat0 |
| 0x1440000 | 0x0010000 | uImage (first block) | loader |
| 0x1450000 | 0x03f0000 | uImage (rest) | fwconcat1 |
| 0x1840000 | 0x07b0000 | reserved | reserved (fwconcat2) |
| 0x1ff0000 | 0x0010000 | caldata | art (read-only) |

Vendor kernel command line:
`mtdparts=ath-nor0:256k(u-boot),20480k(rootfs),4096k(uImage),7872k(reserved),64k(caldata)`

U-Boot boots with `bootcmd=bootm 0xa0440000`, which is flash offset 0x1440000. OpenWrt
puts the OKLI loader there. The loader starts the kernel at flash offset 0x40000, and
fwconcat0, fwconcat1 and reserved are joined into the `firmware` partition.

## Data in flash

| Location | Contents |
|---|---|
| u-boot + 0x3ff80 | label MAC as 12 ASCII hex characters |
| u-boot + 0x3ff90 | serial number (ASCII) |
| u-boot + 0x3ffa0 | board ID `FP321C`, part number, region code |
| art + 0x1000 | ath9k calibration (0x440 bytes) |
| art + 0x5000 | ath10k calibration (0x844 bytes) |

The vendor firmware uses label + 1 for the 2.4 GHz radio and label + 9 for the 5 GHz
radio. The OpenWrt port does the same.

## GPIOs

These follow the WatchGuard AP300 (same board). LED behaviour has not been visually
verified on a 321C.

| GPIO | Function |
|---|---|
| 12 | LED LAN, orange (activity), active-low |
| 13 | LED LAN, green (link), active-low |
| 16 | external watchdog (toggled by OpenWrt) |
| 17 | reset button, active-low |
| 19 | LED WLAN, green (5 GHz activity), active-low |
| 22 | LED power, green, active-low |
| 23 | LED WLAN, amber (2.4 GHz activity), active-low |

## Serial console (J10)

3.3 V TTL, 9600 8N1. Pin 1 (▲, next to C103/C104) is VCC, then GND, TX, RX. RX is next
to R175/R176. On the AP300, R176 pulls RX to ground and R175 sits in series. On the
tested 321C, RX worked as shipped.

## U-Boot

Menu `G/Q/H` (`G` writes flash). The hidden key `k` with password `1` gives the `fap>`
shell. Useful read-only commands: `help`, `printenv`, `version`, `bdinfo`, `sn`, `md`,
`ping`, `crc32`. `tftpboot` and `bootm` load into RAM. Default network: AP
192.168.1.1, server 192.168.1.10.
