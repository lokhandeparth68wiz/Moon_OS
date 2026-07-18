# MoonOS Installer - System Configuration
# System configuration utilities

# Configure fstab
configure_fstab() {
    local root_uuid
    root_uuid=$(get_partition_uuid "${INSTALL_CONFIG[target_disk]}2")

    local efi_uuid
    efi_uuid=$(get_partition_uuid "${INSTALL_CONFIG[target_disk]}1")

    cat > /mnt/etc/fstab << EOF
# <file system>  <mount point>  <type>  <options>  <dump>  <pass>
UUID=${root_uuid}  /              ext4    defaults,noatime  0       1
UUID=${efi_uuid}   /boot/efi      vfat    defaults,noatime  0       2
tmpfs             /tmp           tmpfs   defaults,nosuid,nodev,relatime  0       0
tmpfs             /run           tmpfs   defaults,nosuid,nodev,relatime,mode=755  0       0
proc              /proc          proc    defaults,nosuid,nodev,noexec,relatime  0       0
sysfs             /sys           sysfs   defaults,nosuid,nodev,noexec,relatime  0       0
devtmpfs          /dev           devtmpfs defaults,nosuid,relatime  0       0
EOF
}

# Configure hostname
configure_hostname_system() {
    local hostname="${INSTALL_CONFIG[hostname]}"

    echo "$hostname" > /mnt/etc/hostname

    cat > /mnt/etc/hosts << EOF
127.0.0.1       localhost
127.0.1.1       ${hostname}
::1             localhost
EOF
}

# Configure timezone
configure_timezone_system() {
    local timezone="${INSTALL_CONFIG[timezone]}"

    ln -sf "/usr/share/zoneinfo/${timezone}" /mnt/etc/localtime

    echo "$timezone" > /mnt/etc/timezone
}

# Configure locale
configure_locale_system() {
    local locale="${INSTALL_CONFIG[locale]}"

    echo "$locale UTF-8" > /mnt/etc/locale.gen
    echo "LANG=$locale" > /mnt/etc/locale.conf

    # Generate locales
    chroot /mnt /usr/bin/locale-gen
}

# Configure keyboard
configure_keyboard_system() {
    local keyboard="${INSTALL_CONFIG[keyboard]}"

    cat > /mnt/etc/conf.d/keymaps << EOF
# /etc/conf.d/keymaps

keymap="${keyboard}"
EOF
}

# Set root password
set_root_password() {
    local password="${INSTALL_CONFIG[root_password]}"

    if [[ -z "$password" ]]; then
        # Generate random password
        password=$(openssl rand -base64 12)
        ui_warning "Generated root password: $password"
        echo "Please save this password!"
        ui_wait_key
    fi

    echo "root:${password}" | chpasswd -R /mnt
}

# Create user account
create_user_account() {
    local username="${INSTALL_CONFIG[username]}"
    local password="${INSTALL_CONFIG[user_password]}"

    if [[ -z "$username" ]]; then
        return 0
    fi

    # Create user
    chroot /mnt /usr/sbin/useradd -m -G wheel,docker,video -s /bin/bash "$username"

    # Set password
    if [[ -n "$password" ]]; then
        echo "${username}:${password}" | chpasswd -R /mnt
    fi

    # Configure sudoers
    echo "%wheel ALL=(ALL) ALL" >> /mnt/etc/sudoers
}

# Configure network
configure_network() {
    local hostname="${INSTALL_CONFIG[hostname]}"

    # Create network configuration
    cat > /mnt/etc/conf.d/net << EOF
# /etc/conf.d/net

modules="bonding"
EOF

    # Enable DHCP for all interfaces
    for iface in $(ls /sys/class/net/ | grep -v lo); do
        ln -sf /etc/init.d/net.${iface} "/mnt/etc/runlevels/default/net.${iface}"
    done

    # Configure loopback
    ln -sf /etc/init.d/loopback /mnt/etc/runlevels/boot/loopback
}

# Configure sysctl
configure_sysctl() {
    cat > /mnt/etc/sysctl.d/99-moonos.conf << 'EOF'
# MoonOS System Configuration

# Kernel Parameters
kernel.sysrq = 1
kernel.core_uses_pid = 1
kernel.msgmnb = 65536
kernel.msgmax = 65536
kernel.shmmax = 68719476736
kernel.shmall = 4294967296

# Network Parameters
net.ipv4.ip_forward = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5

# IPv6
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Memory
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
vm.overcommit_memory = 1
EOF
}

# Configure security limits
configure_limits() {
    cat > /mnt/etc/security/limits.d/99-moonos.conf << 'EOF'
# MoonOS Security Limits

*    soft    core            0
*    hard    core            0
*    soft    nproc           65535
*    hard    nproc           65535
*    soft    nofile          65535
*    hard    nofile          65535
root soft    nproc           65535
root hard    nproc           65535
root soft    nofile          65535
root hard    nofile          65535
EOF
}

# Configure kernel modules
configure_modules() {
    cat > /mnt/etc/modules.d/00-common << 'EOF'
# Common kernel modules

# Network
bonding
8021q

# Storage
ahci
libata

# Input
evdev

# USB
usbhid
usb_storage

# Graphics
i915
amdgpu
nouveau
EOF
}

# Get partition UUID
get_partition_uuid() {
    local partition="$1"
    blkid -s UUID -o value "$partition"
}
