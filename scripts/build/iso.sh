#!/bin/bash
# Moon OS ISO Builder
# Pure GRUB boot (BIOS + UEFI) - no ISOLINUX
set -ex

VERSION="${1:-1.0.0}"
ARCH="${2:-amd64}"
OUTPUT="${3:-moonos-${VERSION}-x86_64.iso}"
WORKDIR=$(pwd)/build/iso-work
ROOTFS="${WORKDIR}/rootfs"
ISOROOT="${WORKDIR}/iso-root"

echo "=== Moon OS ISO Builder ==="
echo "Version: ${VERSION} | Arch: ${ARCH} | Output: ${OUTPUT}"

# Cleanup
rm -rf "${WORKDIR}"
mkdir -p "${ISOROOT}/boot/grub" "${ISOROOT}/live"

# ──────────────────────────────────────────────
# 1. debootstrap rootfs
# ──────────────────────────────────────────────
echo "[1/6] debootstrap..."
sudo debootstrap --arch=${ARCH} --variant=minbase \
  --include=linux-image-amd64,initramfs-tools,systemd-sysv,dbus,NetworkManager,sudo,curl,wget \
  bookworm "${ROOTFS}" http://deb.debian.org/debian/

# ──────────────────────────────────────────────
# 2. Configure rootfs
# ──────────────────────────────────────────────
echo "[2/6] Configuring rootfs..."
echo "moonos" | sudo tee "${ROOTFS}/etc/hostname" > /dev/null
echo "127.0.0.1 localhost" | sudo tee "${ROOTFS}/etc/hosts" > /dev/null
echo "moonos" | sudo tee "${ROOTFS}/etc/hostname" > /dev/null

echo 'root:moonos' | sudo chroot "${ROOTFS}" chpasswd
sudo chroot "${ROOTFS}" useradd -m -s /bin/bash -G sudo live 2>/dev/null || true
echo 'live:moonos' | sudo chroot "${ROOTFS}" chpasswd
echo 'live ALL=(ALL) NOPASSWD:ALL' | sudo tee "${ROOTFS}/etc/sudoers.d/live" > /dev/null

# ──────────────────────────────────────────────
# 3. Generate initramfs
# ──────────────────────────────────────────────
echo "[3/6] Generating initramfs..."
sudo chroot "${ROOTFS}" update-initramfs -u -k all 2>&1 | tail -5 || true

# ──────────────────────────────────────────────
# 4. Copy kernel + initrd
# ──────────────────────────────────────────────
echo "[4/6] Copying kernel..."
KERNEL=$(ls "${ROOTFS}/boot/vmlinuz-"* 2>/dev/null | head -1)
INITRD=$(ls "${ROOTFS}/boot/initrd.img-"* 2>/dev/null | head -1)

if [ -z "$KERNEL" ]; then
  echo "ERROR: No kernel found!"
  ls "${ROOTFS}/boot/"
  exit 1
fi

echo "  Kernel: $(basename $KERNEL)"
echo "  Initrd: $(basename $INITRD)"
sudo cp "$KERNEL" "${ISOROOT}/boot/vmlinuz"
[ -n "$INITRD" ] && sudo cp "$INITRD" "${ISOROOT}/boot/initrd.img"

# ──────────────────────────────────────────────
# 5. Create squashfs
# ──────────────────────────────────────────────
echo "[5/6] Creating squashfs..."
sudo mksquashfs "${ROOTFS}" "${ISOROOT}/live/filesystem.squashfs" -comp gzip -b 1M
echo "  Size: $(du -sh ${ISOROOT}/live/filesystem.squashfs | cut -f1)"

# ──────────────────────────────────────────────
# 6. Build ISO with GRUB (BIOS + UEFI)
# ──────────────────────────────────────────────
echo "[6/6] Building ISO..."

# GRUB config
cat > /tmp/grub.cfg << 'EOF'
set timeout=10
set default=0

menuentry "Moon OS Live" {
    linux /boot/vmlinuz boot=live quiet splash
    initrd /boot/initrd.img
}

menuentry "Moon OS Live (Safe Mode)" {
    linux /boot/vmlinuz boot=live nomodeset quiet
    initrd /boot/initrd.img
}
EOF

# Generate standalone GRUB EFI image
GRUB_EFI="${WORKDIR}/bootx64.efi"
sudo grub-mkstandalone \
  --format=x86_64-efi \
  --output="${GRUB_EFI}" \
  --locales="" \
  --fonts="" \
  "boot/grub/grub.cfg=/tmp/grub.cfg"

# Generate GRUB BIOS core image
GRUB_BIOS="${WORKDIR}/core.img"
sudo grub-mkimage \
  -o "${GRUB_BIOS}" \
  -p '(hd0,msdos1)/boot/grub' \
  -O i386-pc \
  biosdisk iso9660 part_msdos part_gpt fat ext2 normal configfile linux boot

# Copy isolinux.bin for MBR (it's just a 512-byte MBR bootstrap)
# Use the one from syslinux if available
MBR_BIN=""
for f in /usr/lib/ISOLINUX/isohdpfx.bin /usr/lib/syslinux/isohdpfx.bin /usr/share/syslinux/isohdpfx.bin; do
  if [ -f "$f" ]; then
    MBR_BIN="$f"
    break
  fi
done

# Build the ISO
ISO_SRC="${ISOROOT}"

if [ -n "${MBR_BIN}" ]; then
  echo "Building hybrid BIOS+UEFI ISO..."
  sudo xorriso -as mkisofs \
    -o "${OUTPUT}" \
    -V "MOONOS" \
    -isohybrid-mbr "${MBR_BIN}" \
    -c boot/boot.cat \
    -boot-load-size 4 \
    -boot-info-table \
    -eltorito-boot boot/grub/bios.img \
    -no-emul-boot \
    -boot-load-size 4 \
    -append_partition 2 0xef "${GRUB_EFI}" \
    -eltorito-alt-boot \
    -e boot/grub/efi.img \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    "${ISO_SRC}" 2>&1 || echo "xorriso hybrid failed, trying simpler method..."
fi

# Simpler fallback: just UEFI boot
if [ ! -f "${OUTPUT}" ]; then
  echo "Building UEFI-only ISO..."
  sudo xorriso -as mkisofs \
    -o "${OUTPUT}" \
    -V "MOONOS" \
    -r -J \
    -eltorito-boot "${GRUB_EFI}" \
    -no-emul-boot \
    -append_partition 2 0xef "${GRUB_EFI}" \
    "${ISO_SRC}"
fi

# Even simpler fallback
if [ ! -f "${OUTPUT}" ]; then
  echo "Building basic ISO..."
  sudo xorriso -as mkisofs \
    -o "${OUTPUT}" \
    -V "MOONOS" \
    -r -J \
    "${ISO_SRC}"
fi

echo ""
echo "=== BUILD COMPLETE ==="
ls -lh "${OUTPUT}"
file "${OUTPUT}"
