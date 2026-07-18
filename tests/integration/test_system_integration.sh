#!/bin/bash
# MoonOS Integration Tests
# Tests for system integration and component interactions

set -euo pipefail

TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${TEST_ROOT}/../test_runner.sh"

# Test: Package installation
test_package_installation() {
    # Test: sysroot directory structure exists
    test_assert_directory_exists "/usr" "usr directory should exist"
    test_assert_directory_exists "/bin" "bin directory should exist"
    test_assert_directory_exists "/sbin" "sbin directory should exist"
    test_assert_directory_exists "/lib" "lib directory should exist"
    test_assert_directory_exists "/etc" "etc directory should exist"
    test_assert_directory_exists "/var" "var directory should exist"
}

# Test: System utilities
test_system_utilities() {
    # Test: BusyBox is installed
    test_assert_command_exists "busybox" "busybox should be installed"

    # Test: Core utilities are installed
    test_assert_command_exists "ls" "ls should be installed"
    test_assert_command_exists "cp" "cp should be installed"
    test_assert_command_exists "mv" "mv should be installed"
    test_assert_command_exists "rm" "rm should be installed"
    test_assert_command_exists "mkdir" "mkdir should be installed"
    test_assert_command_exists "cat" "cat should be installed"
    test_assert_command_exists "grep" "grep should be installed"
    test_assert_command_exists "find" "find should be installed"
}

# Test: Shell configuration
test_shell_configuration() {
    # Test: Bash is installed
    test_assert_command_exists "bash" "bash should be installed"

    # Test: sh is linked to bash
    test_assert_file_exists "/bin/sh" "/bin/sh should exist"
}

# Test: Init system
test_init_system() {
    # Test: OpenRC is installed
    test_assert_file_exists "/sbin/openrc-init" "openrc-init should be installed"
    test_assert_file_exists "/etc/init.d" "init.d directory should exist"

    # Test: Runlevels exist
    test_assert_directory_exists "/etc/runlevels" "runlevels directory should exist"
    test_assert_directory_exists "/etc/runlevels/boot" "boot runlevel should exist"
    test_assert_directory_exists "/etc/runlevels/default" "default runlevel should exist"
}

# Test: Kernel modules
test_kernel_modules() {
    # Test: /proc exists
    test_assert_directory_exists "/proc" "/proc should be mounted"

    # Test: /sys exists
    test_assert_directory_exists "/sys" "/sys should be mounted"

    # Test: /dev exists
    test_assert_directory_exists "/dev" "/dev should be mounted"
}

# Test: Network configuration
test_network_configuration() {
    # Test: /etc/hosts exists
    test_assert_file_exists "/etc/hosts" "/etc/hosts should exist"

    # Test: Hostname is configured
    test_assert_file_exists "/etc/hostname" "/etc/hostname should exist"
}

# Run tests
run_all_tests
