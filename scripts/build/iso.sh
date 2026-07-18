#!/bin/bash
# Moon OS ISO Builder
# Creates a bootable live ISO with kernel, initramfs, and live-boot
# NO set -e - we handle errors manually

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
echo "Workdir: ${WORKDIR}"
echo ""

# Cleanup
rm -rf "${WORKDIR}"
mkdir -p "${WORKDIR}" "${ISOROOT}/boot/grub" "${ISOROOT}/isolinux" "${ISOROOT}/live"

# ──────────────────────────────────────────────
# 1. Build minimal rootfs with debootstrap
# ──────────────────────────────────────────────
echo "[1/7] Building rootfs with debootstrap..."

# Try full include first, fall back to minimal
echo "Attempting full package install..."
sudo debootstrap --arch=${ARCH} \
  --variant=minbase \
  --include=linux-image-amd64,initramfs-tools,systemd-sysv,dbus,NetworkManager,sudo,bash-completion,locales,curl,wget,firefox-esr \
  bookworm "${ROOTFS}" http://deb.debian.org/debian/ 2>&1 || {
  echo "Full install failed, trying minimal base..."
  sudo rm -rf "${ROOTFS}"
  sudo debootstrap --arch=${ARCH} \
    --variant=minbase \
    bookworm "${ROOTFS}" http://deb.debian.org/debian/ 2>&1 || {
    echo "ERROR: debootstrap failed completely"
    exit 1
  }
  echo "Minimal base installed, adding kernel manually..."
  sudo chroot "${ROOTFS}" /bin/bash -c "apt-get update && apt-get install -y linux-image-amd64 initramfs-tools systemd-sysv" || \
    echo "Warning: Could not install kernel in chroot"
}

echo "Rootfs debootstrap complete"

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
EOF

# OS identity
sudo tee "${ROOTFS}/etc/lsb-release" > /dev/null << 'EOF'
DISTRIB_ID=MoonOS
DISTRIB_RELEASE=1.0.0
DISTRIB_CODENAME=Apex
DISTRIB_DESCRIPTION="Moon OS 1.0.0 Apex"
EOF

sudo mkdir -p "${ROOTFS}/etc"
sudo tee "${ROOTFS}/etc/moonos-release" > /dev/null << 'EOF'
Moon OS 1.0.0 Apex
EOF

# Root password
echo "root:moonos" | sudo chroot "${ROOTFS}" chpasswd 2>/dev/null || \
  echo "root:moonos" | sudo chroot "${ROOTFS}" /bin/bash -c "chpasswd" 2>/dev/null || true

# Create live user
sudo chroot "${ROOTFS}" /bin/bash -c "useradd -m -s /bin/bash -G sudo live 2>/dev/null" || true
echo "live:moonos" | sudo chroot "${ROOTFS}" /bin/bash -c "chpasswd" 2>/dev/null || true
sudo chroot "${ROOTFS}" /bin/bash -c "echo 'live ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers" 2>/dev/null || true

# Networking
sudo mkdir -p "${ROOTFS}/etc/NetworkManager/system-connections" 2>/dev/null || true
sudo tee "${ROOTFS}/etc/NetworkManager/NetworkManager.conf" > /dev/null << 'EOF'
[main]
plugins=ifupdown,keyfile
dns=dnsmasq

[ifupdown]
managed=true
EOF

# ──────────────────────────────────────────────
# 3. Generate initramfs
# ──────────────────────────────────────────────
echo "[3/7] Generating initramfs..."
sudo chroot "${ROOTFS}" /bin/bash -c "update-initramfs -u -k all" 2>&1 || \
  echo "Warning: initramfs generation had warnings (non-fatal)"

# ──────────────────────────────────────────────
# 4. Copy kernel and initramfs to ISO
# ──────────────────────────────────────────────
echo "[4/7] Copying kernel and initramfs..."

# Find kernel
KERNEL=""
for k in "${ROOTFS}/boot/vmlinuz-"*; do
  if [ -f "$k" ]; then
    KERNEL="$k"
    break
  fi
done

INITRD=""
for i in "${ROOTFS}/boot/initrd.img-"*; do
  if [ -f "$i" ]; then
    INITRD="$i"
    break
  fi
done

if [ -z "${KERNEL}" ]; then
  echo "ERROR: No kernel found in ${ROOTFS}/boot/"
  ls -la "${ROOTFS}/boot/" 2>/dev/null || echo "Boot dir empty or missing"
  exit 1
fi

echo "Kernel: ${KERNEL}"
echo "Initrd: ${INITRD}"

sudo cp "${KERNEL}" "${ISOROOT}/boot/vmlinuz"
if [ -n "${INITRD}" ]; then
  sudo cp "${INITRD}" "${ISOROOT}/boot/initrd.img"
else
  echo "WARNING: No initrd found, creating empty one"
  sudo touch "${ISOROOT}/boot/initrd.img"
fi

# ──────────────────────────────────────────────
# 5. Create GRUB config
# ──────────────────────────────────────────────
echo "[5/7] Creating GRUB configuration..."

sudo tee "${ISOROOT}/boot/grub/grub.cfg" > /dev/null << 'GRUBEOF'
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
GRUBEOF

# ──────────────────────────────────────────────
# 6. Create squashfs
# ──────────────────────────────────────────────
echo "[6/7] Creating squashfs rootfs..."
sudo mksquashfs "${ROOTFS}" "${ISOROOT}/live/filesystem.squashfs" \
  -comp gzip -b 1M -no-xattrs 2>&1 || {
  echo "xz compression failed, trying gzip..."
  sudo mksquashfs "${ROOTFS}" "${ISOROOT}/live/filesystem.squashfs" \
    -comp gzip -b 1M 2>&1 || {
    echo "ERROR: squashfs creation failed"
    exit 1
  }
}

echo "Squashfs size: $(du -sh ${ISOROOT}/live/filesystem.squashfs | cut -f1)"

# ──────────────────────────────────────────────
# 7. Create isolinux config
# ──────────────────────────────────────────────
echo "[7/7] Building ISO image..."

sudo tee "${ISOROOT}/isolinux/isolinux.cfg" > /dev/null << 'ISEOF'
PROMPT 0
TIMEOUT 50
DEFAULT live

LABEL live
  MENU LABEL Moon OS - Live
  LINUX /boot/vmlinuz
  INITRD /boot/initrd.img
  APPEND boot=live quiet splash

LABEL safemode
  MENU LABEL Moon OS - Safe Mode
  LINUX /boot/vmlinuz
  INITRD /boot/initrd.img
  APPEND boot=live nomodeset quiet
ISEOF

# Copy isolinux.bin if available
if [ -f /usr/lib/ISOLINUX/isolinux.bin ]; then
  sudo cp /usr/lib/ISOLINUX/isolinux.bin "${ISOROOT}/isolinux/"
fi

# ──────────────────────────────────────────────
# 8. Build ISO
# ──────────────────────────────────────────────
# Simple ISO that works everywhere
sudo xorriso -as mkisofs \
  -o "${OUTPUT}" \
  -V "MOONOS" \
  -r -J \
  -J -joliet-long \
  -isohybrid-mbr /usr/lib/ISOLINUX/isolinux.bin 2>/dev/null \
  -c isolinux/boot.cat \
  -boot-load-size 4 \
  -boot-info-table \
  -eltorito-boot isolinux/isolinux.bin \
  -no-emul-boot \
  -eltorito-alt-boot \
  -b boot/grub/grub.cfg \
  -no-emul-boot \
  -isohybrid-gpt-basdat \
  "${ISOROOT}" 2>&1 || {
  echo "Hybrid ISO failed, building standard ISO..."
  sudo xorriso -as mkisofs \
    -o "${OUTPUT}" \
    -V "MOONOS" \
    -r -J \
    -J -joliet-long \
    "${ISOROOT}" 2>&1 || {
    echo "ERROR: ISO creation failed"
    exit 1
  }
}

# ──────────────────────────────────────────────
# Verify
# ──────────────────────────────────────────────
echo ""
echo "=== Build Complete ==="
if [ -f "${OUTPUT}" ]; then
  ls -lh "${OUTPUT}"
  file "${OUTPUT}"
  sha256sum "${OUTPUT}" > "${OUTPUT}.sha256"
  echo "Checksum: $(cat ${OUTPUT}.sha256)"
  echo ""
  echo "ISO ready: ${OUTPUT}"
else
  echo "ERROR: ISO file not created"
  exit 1
fi
