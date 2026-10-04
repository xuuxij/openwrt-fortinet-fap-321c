# Recovery and returning to the vendor firmware

## Why recovery is possible

- OpenWrt marks `u-boot` and `art` (calibration) read-only. `sysupgrade` writes only
  `loader` and `fwconcat0`.
- As long as U-Boot is intact you can always stop it over the serial console and
  boot an OpenWrt initramfs image from RAM, whatever is in the rest of the flash.

What can destroy U-Boot or the calibration data:

- the boot menu's `G` option,
- the `lu` / `lf` / `lk` environment scripts,
- manual `erase`, `cp.b` or `protect` commands,
- an SPI programmer used carelessly.

Only an SPI programmer and a full flash backup can recover from that.

## OpenWrt doesn't boot

1. Connect the serial console, power-cycle, then press **Ctrl+C**, **`k`**, **`1`**
   (see [INSTALL.md](INSTALL.md)).
2. `tftpboot 0x80100000 <initramfs image>` then `bootm 0x80100000`.
3. From the RAM system either:
   - reinstall: `sysupgrade -n /tmp/<sysupgrade image>`, or
   - go back to the vendor firmware (below).

## Back to the vendor firmware (untested)

From the RAM-booted OpenWrt, with your backup files copied to `/tmp`:

```sh
mtd write /tmp/mtd1.bin fwconcat0
mtd write /tmp/mtd2.bin loader
mtd write /tmp/mtd3.bin fwconcat1
mtd write /tmp/mtd4.bin reserved
reboot
```

These partition names exist in the OpenWrt port. The vendor firmware sees the same
regions as `rootfs`, `uImage` and `reserved`. Leave `u-boot` (mtd0) and `art` (mtd5)
alone: OpenWrt never changes them.

The 221-C documentation describes erasing `reserved` instead of restoring it. Writing
back your own backup restores the exact original state.

Upstream OpenWrt documents the same layout for the FAP-221-C. This procedure has not
yet been tested on a 321C.
