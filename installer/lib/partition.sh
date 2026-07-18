#!/bin/bash
# MoonOS Installer - Partition Management
# Disk partitioning and formatting utilities

# Select target disk
select_disk() {
    ui_header "Disk Selection"

    echo "Available disks:"
    echo ""

    # List available disks
    local disks=()
    while IFS= read -r line; do
        local disk_name
        disk_name=$(echo "$line" | awk '{print $1}')
        local disk_size
        disk_size=$(echo "$line" | awk '{print $2}')
        local disk_model
        disk_model=$(echo "$line" | awk '{print $3}')

        disks+=("/dev/$disk_name ($disk_size) - $disk_model")
    done < <(lsblk -d -n -o NAME,SIZE,MODEL | grep -E "^(sd|vd|nvme|mmcblk)")

    if [[ ${#disks[@]} -eq 0 ]]; then
        ui_error "No disks found"
        exit 1
    fi

    # Add RAM disk for testing
    disks+=("/dev/ram0 (RAM disk) - For testing")

    # Select disk
    local selected
    selected=$(ui_select "Select target disk" "${disks[@]}")

    # Extract disk name
    INSTALL_CONFIG[target_disk]=$(echo "$selected" | awk '{print $1}')

    echo ""
    ui_warning "WARNING: All data on ${INSTALL_CONFIG[target_disk]} will be lost!"
    echo ""

    if ! ui_yesno "Continue with installation?"; then
        echo "Installation cancelled."
        exit 0
    fi
}

# Get disk information
get_disk_info() {
    local disk="$1"

    echo "Disk Information:"
    echo "  Device: $disk"
    echo "  Size: $(lsblk -d -n -o SIZE "$disk")"
    echo "  Model: $(lsblk -d -n -o MODEL "$disk")"
    echo "  Serial: $(lsblk -d -n -o SERIAL "$disk" 2>/dev/null || echo "N/A")"
}

# Create partition table
create_partition_table() {
    local disk="$1"
    local table_type="${2:-gpt}"

    echo "Creating $table_type partition table on $disk..."

    parted -s "$disk" mklabel "$table_type"
}

# Create partitions
create_partitions() {
    local disk="$1"
    local efi_size="${2:-512MiB}"
    local root_size="${3:-100%}"

    echo "Creating partitions on $disk..."

    # Create EFI partition
    parted -s "$disk" mkpart primary fat32 1MiB "$efi_size"

    # Create root partition
    parted -s "$disk" mkpart primary ext4 "$efi_size" "$root_size"

    # Set boot flag on EFI partition
    parted -s "$disk" set 1 boot on

    # Wait for kernel to recognize partitions
    partprobe "$disk"
    sleep 2

    echo "Partitions created."
}

# Format partitions
format_partitions() {
    local disk="$1"
    local root_label="${2:-moonos}"

    echo "Formatting partitions..."

    # Determine partition naming
    local part_prefix
    if [[ "$disk" == *"nvme"* ]] || [[ "$disk" == *"mmcblk"* ]]; then
        part_prefix="p"
    else
        part_prefix=""
    fi

    # Format EFI partition
    echo "  Formatting EFI partition..."
    mkfs.fat -F32 -n "EFI" "${disk}${part_prefix}1"

    # Format root partition
    echo "  Formatting root partition..."
    mkfs.ext4 -F -L "$root_label" "${disk}${part_prefix}2"

    echo "Formatting complete."
}

# Mount partitions
mount_partitions() {
    local disk="$1"
    local mount_point="${2:-/mnt}"

    echo "Mounting partitions..."

    # Determine partition naming
    local part_prefix
    if [[ "$disk" == *"nvme"* ]] || [[ "$disk" == *"mmcblk"* ]]; then
        part_prefix="p"
    else
        part_prefix=""
    fi

    # Create mount point
    mkdir -p "$mount_point"

    # Mount root partition
    mount "${disk}${part_prefix}2" "$mount_point"

    # Create and mount EFI partition
    mkdir -p "${mount_point}/boot/efi"
    mount "${disk}${part_prefix}1" "${mount_point}/boot/efi"

    echo "Partitions mounted."
}

# Unmount partitions
unmount_partitions() {
    local mount_point="${1:-/mnt}"

    echo "Unmounting partitions..."

    # Unmount in reverse order
    umount "${mount_point}/boot/efi" 2>/dev/null || true
    umount "$mount_point" 2>/dev/null || true

    echo "Partitions unmounted."
}

# Get partition UUID
get_partition_uuid() {
    local partition="$1"
    blkid -s UUID -o value "$partition"
}

# Get partition type
get_partition_type() {
    local partition="$1"
    blkid -s TYPE -o value "$partition"
}

# Check if disk is valid
validate_disk() {
    local disk="$1"

    # Check if disk exists
    if [[ ! -b "$disk" ]]; then
        echo "Error: $disk is not a block device"
        return 1
    fi

    # Check if disk is mounted
    if mount | grep -q "$disk"; then
        echo "Error: $disk is currently mounted"
        return 1
    fi

    # Check if disk is writable
    if ! touch "${disk}.test" 2>/dev/null; then
        echo "Error: $disk is not writable"
        return 1
    fi
    rm -f "${disk}.test"

    return 0
}

# Create RAM disk for testing
create_ram_disk() {
    local size="${1:-1G}"

    echo "Creating RAM disk for testing..."

    # Convert size to bytes
    local size_bytes
    case "$size" in
        *G)
            size_bytes=$(( ${size%G} * 1024 * 1024 * 1024 ))
            ;;
        *M)
            size_bytes=$(( ${size%M} * 1024 * 1024 ))
            ;;
        *)
            size_bytes=$size
            ;;
    esac

    # Create RAM disk
    modprobe brd rd_nr=1 rd_size=$((size_bytes / 512))

    echo "RAM disk created at /dev/ram0"
}

# Wipe disk
wipe_disk() {
    local disk="$1"
    local secure="${2:-false}"

    echo "Wiping disk $disk..."

    if [[ "$secure" == "true" ]]; then
        # Secure wipe
        dd if=/dev/urandom of="$disk" bs=1M status=progress
    else
        # Quick wipe
        dd if=/dev/zero of="$disk" bs=1M count=10
    fi

    echo "Disk wiped."
}

# Get disk usage
get_disk_usage() {
    local disk="$1"

    echo "Disk Usage:"
    df -h "$disk" 2>/dev/null || echo "Not mounted"
}
