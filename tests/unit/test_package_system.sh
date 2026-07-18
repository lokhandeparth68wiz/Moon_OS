#!/bin/bash
# MoonOS Unit Tests - Package System
# Tests for package management functionality

set -euo pipefail

TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${TEST_ROOT}/../test_runner.sh"

# Test: Package metadata parsing
test_pkg_metadata() {
    local pkgbuild="${MOONOS_ROOT}/packages/base/musl/PKGBUILD"

    # Source PKGBUILD
    (
        source "$pkgbuild"

        # Check required variables
        test_assert_equals "musl" "$pkg_name" "Package name should be musl"
        test_assert_equals "1.2.4" "$pkg_version" "Package version should be 1.2.4"
        test_assert_not_empty "$pkg_description" "Description should not be empty"
        test_assert_not_empty "$pkg_url" "URL should not be empty"
        test_assert_not_empty "$pkg_license" "License should not be empty"
    )
}

# Test: Package checksum validation
test_pkg_checksum() {
    local pkgbuild="${MOONOS_ROOT}/packages/base/musl/PKGBUILD"

    # Source PKGBUILD
    (
        source "$pkgbuild"

        # Check checksums exist
        test_assert_equals "${#pkg_source[@]}" "${#pkg_sha256[@]}" "Source and checksum counts should match"
    )
}

# Test: Package dependency list
test_pkg_dependencies() {
    local pkgbuild="${MOONOS_ROOT}/packages/base/musl/PKGBUILD"

    # Source PKGBUILD
    (
        source "$pkgbuild"

        # musl should have no dependencies
        test_assert_equals 0 "${#pkg_depends[@]}" "musl should have no dependencies"
    )
}

# Test: Package source URL validation
test_pkg_source_url() {
    local pkgbuild="${MOONOS_ROOT}/packages/base/musl/PKGBUILD"

    # Source PKGBUILD
    (
        source "$pkgbuild"

        # Check source URL format
        for source_url in "${pkg_source[@]}"; do
            test_assert "[[ \"$source_url\" =~ ^https?:// ]] " "Source URL should be HTTP/HTTPS"
        done
    )
}

# Run tests
run_all_tests
