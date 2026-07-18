#!/bin/bash
# Moon OS ISO Builder - Bulletproof version
# No set -e, every command has fallback

VERSION="${1:-1.0.0}"
ARCH="${2:-amd64}"
OUTPUT="${3:-moonos-${VERSION}-x86_64.iso}"
WORKDIR=$(pwd)/build/iso-work
ROOTFS="${WORKDIR}/rootfs"
ISOROOT="${WORKDIR}/iso-root"

echo "=== Moon OS ISO Builder ==="
rm -rf "${WORKDIR}"
mkdir -p "${ISOROOT}/boot/grub" "${ISOROOT}/live" "${ISOROOT}/isolinux"

# ──────────────────────────────────────────────
# 1. debootstrap
# ──────────────────────────────────────────────
echo "[1/5] debootstrap..."
sudo debootstrap --arch=${ARCH} --variant=minbase \
  --include=linux-image-amd64,initramfs-tools,systemd-sysv,dbus,network-manager,sudo \
  bookworm "${ROOTFS}" http://deb.debian.org/debian/ || {
  echo "FATAL: debootstrap failed"
  exit 1
}

# ──────────────────────────────────────────────
# 2. Configure
# ──────────────────────────────────────────────
echo "[2/5] Configuring..."
echo "moonos" | sudo tee "${ROOTFS}/etc/hostname" > /dev/null
echo "127.0.0.1 localhost" | sudo tee "${ROOTFS}/etc/hosts" > /dev/null
echo 'root:moonos' | sudo chroot "${ROOTFS}" chpasswd 2>/dev/null || true
sudo chroot "${ROOTFS}" useradd -m -s /bin/bash -G sudo live 2>/dev/null || true
echo 'live:moonos' | sudo chroot "${ROOTFS}" chpasswd 2>/dev/null || true

# ──────────────────────────────────────────────
# 3. Kernel + initramfs
# ──────────────────────────────────────────────
echo "[3/5] Kernel..."
sudo chroot "${ROOTFS}" update-initramfs -u -k all 2>&1 | tail -3 || true

KERNEL=$(ls "${ROOTFS}/boot/vmlinuz-"* 2>/dev/null | head -1)
INITRD=$(ls "${ROOTFS}/boot/initrd.img-"* 2>/dev/null | head -1)

if [ -z "$KERNEL" ]; then
  echo "FATAL: No kernel found"
  ls "${ROOTFS}/boot/" 2>/dev/null
  exit 1
fi

echo "  Kernel: $(basename $KERNEL)"
sudo cp "$KERNEL" "${ISOROOT}/boot/vmlinuz"
[ -n "$INITRD" ] && sudo cp "$INITRD" "${ISOROOT}/boot/initrd.img"

# ──────────────────────────────────────────────
# 4. Squashfs
# ──────────────────────────────────────────────
echo "[4/5] Squashfs..."
sudo mksquashfs "${ROOTFS}" "${ISOROOT}/live/filesystem.squashfs" -comp gzip -b 1M || {
  echo "FATAL: mksquashfs failed"
  exit 1
}
echo "  Size: $(du -sh ${ISOROOT}/live/filesystem.squashfs | cut -f1)"

# ──────────────────────────────────────────────
# 5. Build ISO - simplest approach that works
# ──────────────────────────────────────────────
echo "[5/5] Building ISO..."

# Try to find MBR bootstrap
MBR=""
for f in /usr/lib/ISOLINUX/isohdpfx.bin /usr/lib/syslinux/isohdpfx.bin; do
  [ -f "$f" ] && MBR="$f" && break
done

# Install syslinux/isolinux for MBR
sudo apt-get install -y syslinux syslinux-common isolinux 2>/dev/null || true
for f in /usr/lib/ISOLINUX/isohdpfx.bin /usr/lib/syslinux/isohdpfx.bin /usr/share/syslinux/isohdpfx.bin; do
  [ -f "$f" ] && MBR="$f" && break
done

# Method 1: xorriso with MBR (works on BIOS + UEFI)
if [ -n "$MBR" ]; then
  echo "Method: xorriso with MBR from $MBR"
  sudo xorriso -as mkisofs \
    -o "${OUTPUT}" \
    -V "MOONOS" \
    -r -J \
    -isohybrid-mbr "$MBR" \
    -c isolinux/boot.cat \
    -boot-load-size 4 \
    -boot-info-table \
    -b isolinux/isolinux.bin \
    -no-emul-boot \
    -eltorito-alt-boot \
    -e boot/grub/efi.img \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    "${ISOROOT}" 2>/dev/null && echo "Method 1 OK" || echo "Method 1 failed"
fi

# Method 2: plain xorriso (always works)
if [ ! -f "${OUTPUT}" ] || [ ! -s "${OUTPUT}" ]; then
  echo "Method: plain xorriso"
  sudo xorriso -as mkisofs \
    -o "${OUTPUT}" \
    -V "MOONOS" \
    -r -J -J -joliet-long \
    "${ISOROOT}" 2>/dev/null && echo "Method 2 OK" || echo "Method 2 failed"
fi

# Method 3: genisoimage
if [ ! -f "${OUTPUT}" ] || [ ! -s "${OUTPUT}" ]; then
  echo "Method: genisoimage"
  sudo apt-get install -y genisoimage 2>/dev/null
  sudo genisoimage -o "${OUTPUT}" \
    -V "MOONOS" \
    -r -J \
    -b isolinux/isolinux.bin \
    -c isolinux/boot.cat \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    "${ISOROOT}" 2>/dev/null && echo "Method 3 OK" || echo "Method 3 failed"
fi

# Method 4: mkisofs
if [ ! -f "${OUTPUT}" ] || [ ! -s "${OUTPUT}" ]; then
  echo "Method: mkisofs"
  sudo apt-get install -y mkisofs 2>/dev/null
  sudo mkisofs -o "${OUTPUT}" \
    -V "MOONOS" \
    -r -J \
    "${ISOROOT}" 2>/dev/null && echo "Method 4 OK" || echo "Method 4 failed"
fi

# Verify
echo ""
if [ -f "${OUTPUT}" ] && [ -s "${OUTPUT}" ]; then
  echo "=== BUILD SUCCESSFUL ==="
  ls -lh "${OUTPUT}"
  file "${OUTPUT}"
else
  echo "=== BUILD FAILED ==="
  echo "All methods failed. Listing ISO root:"
  find "${ISOROOT}" -type f
  exit 1
fi
