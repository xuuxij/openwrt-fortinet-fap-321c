#!/usr/bin/env bash
# Build OpenWrt images for the Fortinet FAP-321-C (ath79/generic).
#
# Usage: scripts/build.sh <patch> [git-ref]
#   <patch>    patch from patches/ matching the ref
#   [git-ref]  OpenWrt tag or branch, default v25.12.5
#
# Run as a normal user on Debian/Ubuntu (OpenWrt refuses to build as root).
# Output: <src>/bin/targets/ath79/generic/*fortinet_fap-321-c*
set -euo pipefail

PATCH="$(realpath "${1:?usage: build.sh <patch> [git-ref]}")"
REF="${2:-v25.12.5}"
SRC="${SRC:-$HOME/openwrt-fap-321-c-$REF}"
JOBS="$(nproc)"

if [ "$(id -u)" -eq 0 ]; then
	echo "run this as a normal user, not root" >&2
	exit 1
fi

if command -v apt-get >/dev/null; then
	sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq
	sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
		build-essential clang flex bison g++ gawk gcc-multilib g++-multilib \
		gettext git libncurses-dev libssl-dev python3-setuptools python3-dev \
		rsync swig unzip zlib1g-dev file wget zstd
fi

if [ ! -d "$SRC/.git" ]; then
	git clone --branch "$REF" --depth 1 https://git.openwrt.org/openwrt/openwrt.git "$SRC"
fi
cd "$SRC"

if ! grep -q 'fortinet_fap-321-c' target/linux/ath79/image/generic.mk; then
	git apply --check "$PATCH"
	git apply "$PATCH"
fi

./scripts/feeds update -a
./scripts/feeds install -a

cat > .config <<'EOF'
CONFIG_TARGET_ath79=y
CONFIG_TARGET_ath79_generic=y
CONFIG_TARGET_ath79_generic_DEVICE_fortinet_fap-321-c=y
CONFIG_TARGET_ROOTFS_INITRAMFS=y
CONFIG_PACKAGE_luci=y
CONFIG_KERNEL_BUILD_USER="builder"
CONFIG_KERNEL_BUILD_DOMAIN="buildhost"
EOF
make defconfig
grep -q '^CONFIG_TARGET_ath79_generic_DEVICE_fortinet_fap-321-c=y' .config

make -j"$JOBS" download
if ! make -j"$JOBS" >build.log 2>&1; then
	echo "build failed; rerunning single-threaded for a readable error" >&2
	make -j1 V=s >build-j1.log 2>&1 || {
		grep -n -E 'make\[[0-9]+\]: \*\*\*|[Ee]rror' build-j1.log | tail -20 >&2
		echo "full log: $SRC/build-j1.log" >&2
		exit 1
	}
fi

OUT=bin/targets/ath79/generic

# The lzma-loader runs at 0x81800000 and unpacks the kernel to 0x80060000,
# so the uncompressed initramfs kernel must stay below 0x017a0000 bytes.
LIMIT=$((0x81800000 - 0x80060000))
VMI="$(find build_dir -path '*linux-ath79_generic*' -name 'vmlinux-initramfs' | head -n1)"
SIZE="$(stat -c %s "$VMI")"
echo "uncompressed initramfs kernel: $SIZE bytes (limit $LIMIT)"
if [ "$SIZE" -ge "$LIMIT" ]; then
	echo "WARNING: initramfs too large for the loader; do not TFTP-boot it" >&2
fi

# factory.bin must decompress to exactly the vendor rootfs+uImage size
FAC="$(ls "$OUT"/*fap-321-c*factory.bin)"
RAW="$(gzip -dc "$FAC" | wc -c)"
echo "factory.bin payload: $RAW bytes (expected $((24576 * 1024)))"

(cd "$OUT" && sha256sum *fap-321-c*)
echo "images are in $SRC/$OUT"
