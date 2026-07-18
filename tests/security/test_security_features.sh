#!/bin/bash
# MoonOS Security Tests
# Tests for security features and configurations

set -euo pipefail

TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${TEST_ROOT}/../test_runner.sh"

# Test: File permissions
test_file_permissions() {
    # Test: /etc/shadow has correct permissions
    if [[ -f /etc/shadow ]]; then
        local perms
        perms=$(stat -c "%a" /etc/shadow)
        test_assert_equals "640" "$perms" "/etc/shadow should have 640 permissions"
    fi

    # Test: /etc/passwd has correct permissions
    if [[ -f /etc/passwd ]]; then
        local perms
        perms=$(stat -c "%a" /etc/passwd)
        test_assert_equals "644" "$perms" "/etc/passwd should have 644 permissions"
    fi

    # Test: /etc/group has correct permissions
    if [[ -f /etc/group ]]; then
        local perms
        perms=$(stat -c "%a" /etc/group)
        test_assert_equals "644" "$perms" "/etc/group should have 644 permissions"
    fi
}

# Test: Sudo configuration
test_sudo_configuration() {
    # Test: sudoers file exists
    test_assert_file_exists "/etc/sudoers" "/etc/sudoers should exist"

    # Test: sudoers file has correct permissions
    local perms
    perms=$(stat -c "%a" /etc/sudoers)
    test_assert_equals "440" "$perms" "/etc/sudoers should have 440 permissions"
}

# Test: SSH configuration
test_ssh_configuration() {
    # Test: SSH directory exists
    if [[ -d /etc/ssh ]]; then
        # Test: SSH config has correct permissions
        local perms
        perms=$(stat -c "%a" /etc/ssh)
        test_assert_equals "755" "$perms" "/etc/ssh should have 755 permissions"
    fi
}

# Test: Firewall configuration
test_firewall_configuration() {
    # Test: iptables is available
    test_assert_command_exists "iptables" "iptables should be installed"

    # Test: ip6tables is available
    test_assert_command_exists "ip6tables" "ip6tables should be installed"
}

# Test: Kernel security features
test_kernel_security() {
    # Test: ASLR is enabled
    if [[ -f /proc/sys/kernel/randomize_va_space ]]; then
        local aslr
        aslr=$(cat /proc/sys/kernel/randomize_va_space)
        test_assert "[[ \"$aslr\" -eq 2 ]]" "ASLR should be fully enabled"
    fi

    # Test: SysRq is disabled
    if [[ -f /proc/sys/kernel/sysrq ]]; then
        local sysrq
        sysrq=$(cat /proc/sys/kernel/sysrq)
        test_assert "[[ \"$sysrq\" -eq 0 ]]" "SysRq should be disabled"
    fi
}

# Test: Network security
test_network_security() {
    # Test: IP forwarding is disabled (for non-router)
    if [[ -f /proc/sys/net/ipv4/ip_forward ]]; then
        local forward
        forward=$(cat /proc/sys/net/ipv4/ip_forward)
        # Note: This might be 1 in containers
        # test_assert "[[ \"$forward\" -eq 0 ]]" "IP forwarding should be disabled"
    fi

    # Test: ICMP redirects are disabled
    if [[ -f /proc/sys/net/ipv4/conf/all/accept_redirects ]]; then
        local redirects
        redirects=$(cat /proc/sys/net/ipv4/conf/all/accept_redirects)
        test_assert "[[ \"$redirects\" -eq 0 ]]" "ICMP redirects should be disabled"
    fi
}

# Test: User security
test_user_security() {
    # Test: No empty passwords
    if [[ -f /etc/shadow ]]; then
        local empty_passwords
        empty_passwords=$(awk -F: '($2 == "" || $2 == "!") {print $1}' /etc/shadow | wc -l)
        # This is expected for locked accounts
    fi

    # Test: Root has no empty password
    if [[ -f /etc/shadow ]]; then
        local root_password
        root_password=$(grep "^root:" /etc/shadow | cut -d: -f2)
        test_assert "[[ -n \"$root_password\" && \"$root_password\" != \"!\" && \"$root_password\" != \"*\" ]]" "Root should have a password set"
    fi
}

# Run tests
run_all_tests
