#!/bin/bash
# Moon OS ISO Builder
# Creates a bootable live ISO with kernel, initramfs, and live-boot
set -e

VERSION="${1:-1.0.0}"
ARCH="${2:-amd64}"
OUTPUT="${3:-moonos-${VERSION}-x86_64.iso}"
WORKDIR=$(pwd)/build/iso-work
ROOTFS="${WORKDIR}/rootfs"
ISOROOT="${WORKDIR}/iso-root"

echo "=== Moon OS ISO Builder ==="
echo "Version: ${VERSION}"
echo "Arch: ${ARCH}"
echo "Output: ${OUTPUT}"

# Cleanup
rm -rf "${WORKDIR}"
mkdir -p "${WORKDIR}" "${ISOROOT}"

# ──────────────────────────────────────────────
# 1. Build rootfs with debootstrap
# ──────────────────────────────────────────────
echo "[1/7] Building rootfs with debootstrap..."
sudo debootstrap --arch=${ARCH} \
  --include=linux-image-amd64,initramfs-tools,live-boot,systemd-sysv,dbus,NetworkManager,gdm3,gnome-session,gnome-terminal,firefox-esr,sudo,bash-completion,locales,keyboard-configuration \
  bookworm "${ROOTFS}" http://deb.debian.org/debian/

# ──────────────────────────────────────────────
# 2. Configure rootfs
# ──────────────────────────────────────────────
echo "[2/7] Configuring rootfs..."

# Hostname
echo "moonos" | sudo tee "${ROOTFS}/etc/hostname" > /dev/null

# Hosts
sudo tee "${ROOTFS}/etc/hosts" > /dev/null << 'EOF'
127.0.0.1   localhost
127.0.1.1   moonos
EOF

# Fstab
sudo tee "${ROOTFS}/etc/fstab" > /dev/null << 'EOF'
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
proc            /proc           proc    defaults        0       0
/dev/sr0        / iso9660       ro,noauto,nofail    0       0
EOF

# Boot splash
sudo tee "${ROOTFS}/etc/lsb-release" > /dev/null << 'EOF'
DISTRIB_ID=MoonOS
DISTRIB_RELEASE=1.0.0
DISTRIB_CODENAME=Apex
DISTRIB_DESCRIPTION="Moon OS 1.0.0 Apex"
EOF

# Root password (live user)
sudo chroot "${ROOTFS}" /bin/bash -c "echo 'root:moonos' | chpasswd" || true
sudo chroot "${ROOTFS}" /bin/bash -c "useradd -m -s /bin/bash -G sudo live" || true
echo "live:moonos" | sudo tee "${ROOTFS}/etc/live/user.conf" > /dev/null || true

# Auto-login
sudo mkdir -p "${ROOTFS}/etc/gdm3/custom.conf"
sudo tee "${ROOTFS}/etc/gdm3/custom.conf" > /dev/null << 'EOF'
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=live
WaylandEnable=false

[security]
AllowRemoteAutoLogin=false

[xdm-data]
EOF

# Networking
sudo mkdir -p "${ROOTFS}/etc/NetworkManager/system-connections"
sudo tee "${ROOTFS}/etc/NetworkManager/system-connections/wired.nmconnection" > /dev/null << 'EOF'
[connection]
id=Wired connection 1
type=ethernet
autoconnect=true

[ipv4]
method=auto
dns=8.8.8.8;8.8.4.4;

[ipv6]
method=auto
EOF

# ──────────────────────────────────────────────
# 3. Install kernel and initramfs
# ──────────────────────────────────────────────
echo "[3/7] Installing kernel and generating initramfs..."
sudo chroot "${ROOTFS}" /bin/bash -c "update-initramfs -u -k all" || \
  echo "Warning: initramfs generation had warnings"

# ──────────────────────────────────────────────
# 4. Configure bootloader (GRUB)
# ──────────────────────────────────────────────
echo "[4/7] Configuring GRUB bootloader..."

# Copy kernel and initramfs to ISO
KERNEL_VERSION=$(ls "${ROOTFS}/boot/vmlinuz-"* 2>/dev/null | head -1 | xargs basename || echo "vmlinuz")
INITRD_VERSION=$(ls "${ROOTFS}/boot/initrd.img-"* 2>/dev/null | head -1 | xargs basename || echo "initrd.img")

sudo mkdir -p "${ISOROOT}/boot/grub"
sudo cp "${ROOTFS}/boot/${KERNEL_VERSION}" "${ISOROOT}/boot/vmlinuz"
sudo cp "${ROOTFS}/boot/${INITRD_VERSION}" "${ISOROOT}/boot/initrd.img"

# GRUB config for BIOS
sudo mkdir -p "${ISOROOT}/boot/grub/i386-pc"
sudo tee "${ISOROOT}/boot/grub/grub.cfg" > /dev/null << GRUBEOF
set timeout=10
set default=0
set gfxmode=auto
set gfxpayload=keep

menuentry "Moon OS - Live" {
    linux /boot/vmlinuz boot=live quiet splash
    initrd /boot/initrd.img
}

menuentry "Moon OS - Live (Safe Mode)" {
    linux /boot/vmlinuz boot=live nomodeset quiet
    initrd /boot/initrd.img
}

menuentry "Moon OS - Live (Verbose)" {
    linux /boot/vmlinuz boot=live debug
    initrd /boot/initrd.img
}

menuentry "Moon OS - Install to Disk" {
    linux /boot/vmlinuz boot=live installer quiet
    initrd /boot/initrd.img
}
GRUBEOF

# ──────────────────────────────────────────────
# 5. Create squashfs rootfs
# ──────────────────────────────────────────────
echo "[5/7] Creating squashfs rootfs..."
sudo mksquashfs "${ROOTFS}" "${ISOROOT}/live/filesystem.squashfs" \
  -comp xz -b 1M -Xdict-size 1M -no-xattrs -noappend
ls -lh "${ISOROOT}/live/filesystem.squashfs"

# ──────────────────────────────────────────────
# 6. Install isolinux for BIOS boot
# ──────────────────────────────────────────────
echo "[6/7] Installing isolinux..."
sudo apt-get install -y isolinux syslinux syslinux-common 2>/dev/null || true

sudo mkdir -p "${ISOROOT}/isolinux"
if [ -f /usr/lib/ISOLINUX/isolinux.bin ]; then
  sudo cp /usr/lib/ISOLINUX/isolinux.bin "${ISOROOT}/isolinux/"
fi
if [ -f /usr/lib/syslinux/modules/bios/ldlinux.c32 ]; then
  sudo cp /usr/lib/syslinux/modules/bios/ldlinux.c32 "${ISOROOT}/isolinux/" 2>/dev/null || true
fi

sudo tee "${ISOROOT}/isolinux/isolinux.cfg" > /dev/null << 'ISEOF'
UI vesamenu.c32
PROMPT 0
TIMEOUT 50

LABEL live
  MENU LABEL ^Moon OS - Live
  LINUX /boot/vmlinuz
  INITRD /boot/initrd.img
  APPEND boot=live quiet splash

LABEL safemode
  MENU LABEL Moon OS - Safe Mode
  LINUX /boot/vmlinuz
  INITRD /boot/initrd.img
  APPEND boot=live nomodeset quiet

LABEL install
  MENU LABEL Moon OS - Install to Disk
  LINUX /boot/vmlinuz
  INITRD /boot/initrd.img
  APPEND boot=live installer quiet
ISEOF

# ──────────────────────────────────────────────
# 7. Build ISO (BIOS + UEFI)
# ──────────────────────────────────────────────
echo "[7/7] Building ISO image..."

# Generate GRUB EFI image
GRUB_EFI=""
if [ -d /usr/lib/grub/x86_64-efi ]; then
  GRUB_EFI="${WORKDIR}/grub-efi.bin"
  grub-mkstandalone \
    --format=x86_64-efi \
    --output="${GRUB_EFI}" \
    --locales="" \
    --fonts="" \
    "boot/grub/grub.cfg=${ISOROOT}/boot/grub/grub.cfg"
fi

# Build ISO with xorriso
if [ -n "${GRUB_EFI}" ] && [ -f /usr/lib/ISOLINUX/isolinux.bin ]; then
  echo "Building hybrid BIOS+UEFI ISO..."
  sudo xorriso -as mkisofs \
    -o "${OUTPUT}" \
    -V "MOONOS" \
    -isohybrid-mbr /usr/lib/ISOLINUX/isolinux.bin \
    -c isolinux/boot.cat \
    -boot-load-size 4 \
    -boot-info-table \
    -isohybrid-gpt-basdat \
    -eltorito-alt-boot \
    -e boot/grub/efi.img \
    -no-emul-boot \
    -append_partition 2 0xef "${GRUB_EFI}" \
    "${ISOROOT}"
elif [ -f /usr/lib/ISOLINUX/isolinux.bin ]; then
  echo "Building BIOS-only ISO..."
  sudo xorriso -as mkisofs \
    -o "${OUTPUT}" \
    -V "MOONOS" \
    -isohybrid-mbr /usr/lib/ISOLINUX/isolinux.bin \
    -c isolinux/boot.cat \
    -boot-load-size 4 \
    -boot-info-table \
    "${ISOROOT}"
else
  echo "Building simple ISO..."
  sudo xorriso -as mkisofs \
    -o "${OUTPUT}" \
    -V "MOONOS" \
    -r -J \
    "${ISOROOT}"
fi

# ──────────────────────────────────────────────
# Verify
# ──────────────────────────────────────────────
echo ""
echo "=== Build Complete ==="
ls -lh "${OUTPUT}"
file "${OUTPUT}"

# Generate checksums
sha256sum "${OUTPUT}" > "${OUTPUT}.sha256"
echo "Checksum: $(cat ${OUTPUT}.sha256)"
echo ""
echo "ISO ready: ${OUTPUT}"
