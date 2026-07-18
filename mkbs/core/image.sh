#!/bin/bash
# MKBS Core - Image creation
# Handles ISO, raw disk images, and installation media

# Create bootable ISO image
create_iso_image() {
    local output="$1"
    local sysroot="${MKBS_SYSROOT}"
    local staging="${MKBS_BUILD_DIR}/iso-staging"

    log_info "Creating ISO image: $output"

    # Create staging directory
    mkdir -p "$staging"/{boot/grub,EFI/BOOT,LIVE/rootfs}

    # Copy kernel and initramfs
    if [[ -f "${sysroot}/boot/vmlinuz" ]]; then
        cp "${sysroot}/boot/vmlinuz" "${staging}/boot/vmlinuz"
    fi

    if [[ -f "${sysroot}/boot/initramfs.img" ]]; then
        cp "${sysroot}/boot/initramfs.img" "${staging}/boot/initramfs.img"
    fi

    # Create GRUB configuration
    cat > "${staging}/boot/grub/grub.cfg" << 'EOF'
set default=0
set timeout=5

menuentry "MoonOS Live" {
    linux /boot/vmlinuz boot=live quiet
    initrd /boot/initramfs.img
}

menuentry "MoonOS Live (Verbose)" {
    linux /boot/vmlinuz boot=live debug
    initrd /boot/initramfs.img
}

menuentry "MoonOS Install" {
    linux /boot/vmlinuz boot=live installer quiet
    initrd /boot/initramfs.img
}

menuentry "Memory Test" {
    linux /boot/memtest86+
}
EOF

    # Create GRUB EFI configuration for UEFI boot
    cat > "${staging}/EFI/BOOT/grub.cfg" << 'EOF'
set default=0
set timeout=5

menuentry "MoonOS Live (UEFI)" {
    linux /boot/vmlinuz boot=live quiet
    initrd /boot/initramfs.img
}
EOF

    # Create initramfs content (compressed rootfs)
    log_info "Creating squashfs rootfs"
    if command -v mksquashfs &>/dev/null; then
        mksquashfs "$sysroot" "${staging}/LIVE/rootfs.squashfs" \
            -comp gzip -b 1M -no-xattrs -noappend
    else
        log_warn "mksquashfs not found, skipping squashfs creation"
    fi

    # Create ISO with grub-mkrescue or xorriso
    if command -v grub-mkrescue &>/dev/null; then
        grub-mkrescue -o "$output" "$staging"
    elif command -v xorriso &>/dev/null; then
        _create_iso_xorriso "$output" "$staging"
    else
        log_error "No ISO creation tool found (install grub-tools or xorriso)"
        return 1
    fi

    log_success "ISO image created: $output"
}

# Create raw disk image
create_raw_image() {
    local output="$1"
    local size="${2:-2G}"
    local sysroot="${MKBS_SYSROOT}"

    log_info "Creating raw disk image: $output ($size)"

    # Create empty image
    truncate -s "$size" "$output"

    # Create partition table
    parted -s "$output" mklabel gpt

    # Create partitions
    parted -s "$output" mkpart primary fat32 1MiB 512MiB
    parted -s "$output" mkpart primary ext4 512MiB 100%
    parted -s "$output" set 1 boot on

    # Setup loop device
    local loop_dev
    loop_dev=$(losetup --find --show "$output")

    # Format partitions
    mkfs.fat -F32 "${loop_dev}p1"
    mkfs.ext4 -F "${loop_dev}p2"

    # Mount and install
    local mount_dir="${MKBS_BUILD_DIR}/disk-mount"
    mkdir -p "$mount_dir"

    mount "${loop_dev}p2" "$mount_dir"
    mkdir -p "${mount_dir}/boot/efi"
    mount "${loop_dev}p1" "${mount_dir}/boot/efi"

    # Install rootfs
    cp -a "${sysroot}/." "$mount_dir/"

    # Install GRUB
    _install_grub "$mount_dir" "$loop_dev"

    # Cleanup
    umount "${mount_dir}/boot/efi"
    umount "$mount_dir"
    losetup -d "$loop_dev"

    log_success "Raw disk image created: $output"
}

# Install GRUB bootloader
_install_grub() {
    local root_dir="$1"
    local disk_dev="$2"

    log_info "Installing GRUB bootloader"

    # Determine GRUB target
    local grub_target="x86_64-linux-musl"

    # Install GRUB for BIOS
    grub-install \
        --target=i386-pc \
        --boot-directory="${root_dir}/boot" \
        --modules="part_gpt part_msdos ext2 fat" \
        "$disk_dev" || log_warn "BIOS GRUB install failed"

    # Install GRUB for UEFI
    grub-install \
        --target=x86_64-efi \
        --efi-directory="${root_dir}/boot/efi" \
        --boot-directory="${root_dir}/boot" \
        --removable \
        --modules="part_gpt part_msdos ext2 fat" || log_warn "UEFI GRUB install failed"
}

# Create ISO with xorriso
_create_iso_xorriso() {
    local output="$1"
    local staging="$2"

    xorriso -as mkisofs \
        -iso-level 3 \
        -full-iso9660-filenames \
        -volid "MOONOS" \
        -output "$output" \
        -eltorito-boot boot/grub/bios.img \
            -no-emul-boot \
            -boot-load-size 4 \
            -boot-info-table \
            --eltorito-catalog boot/grub/boot.cat \
        -eltorito-alt-boot \
            -e EFI/BOOT/efi.img \
            -no-emul-boot \
            -isohybrid-gpt-basdat \
        "$staging"
}

# Create initramfs
create_initramfs() {
    local output="$1"
    local sysroot="${MKBS_SYSROOT}"
    local initramfs_dir="${MKBS_BUILD_DIR}/initramfs"

    log_info "Creating initramfs: $output"

    # Create initramfs directory structure
    mkdir -p "$initramfs_dir"/{bin,sbin,lib,lib64,dev,proc,sys,tmp,etc,run,var}

    # Copy required binaries
    local bins=(
        busybox
        mount
        umount
        sh
        bash
        udevadm
        switch_root
        mdev
    )

    for bin in "${bins[@]}"; do
        local bin_path
        bin_path="$(find "${sysroot}/usr/bin" "${sysroot}/bin" -name "$bin" 2>/dev/null | head -n1)"
        if [[ -n "$bin_path" ]]; then
            cp "$bin_path" "${initramfs_dir}/bin/"
        fi
    done

    # Copy required libraries
    if [[ -d "${sysroot}/lib" ]]; then
        cp -a "${sysroot}/lib/"*.so* "${initramfs_dir}/lib/" 2>/dev/null || true
    fi
    if [[ -d "${sysroot}/lib64" ]]; then
        cp -a "${sysroot}/lib64/"*.so* "${initramfs_dir}/lib64/" 2>/dev/null || true
    fi

    # Create init script
    cat > "${initramfs_dir}/init" << 'INIT'
#!/bin/sh
# MoonOS Init Script

export PATH=/bin:/sbin:/usr/bin:/usr/sbin

# Mount essential filesystems
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev
mount -t tmpfs tmpfs /tmp

# Start mdev for device management
echo /sbin/mdev > /proc/sys/kernel/hotplug
/sbin/mdev -s

# Wait for devices
sleep 1

# Find the root device
ROOT=""
for dev in /dev/sd* /dev/vd* /dev/nvme*; do
    if [ -b "$dev" ]; then
        # Check if this device has a MoonOS partition
        if blkid "$dev" | grep -q "MOONOS"; then
            ROOT="$dev"
            break
        fi
    fi
done

if [ -z "$ROOT" ]; then
    echo "ERROR: No MoonOS root device found"
    echo "Dropping to emergency shell..."
    exec /bin/sh
fi

# Mount root filesystem
mount -o ro "$ROOT" /mnt

# Switch to real root
exec switch_root /mnt /sbin/init
INIT

    chmod +x "${initramfs_dir}/init"

    # Pack initramfs
    (cd "$initramfs_dir" && find . -print0 | cpio --null -o --format=newc 2>/dev/null | gzip -9 > "$output")

    log_success "Initramfs created: $output"
}
