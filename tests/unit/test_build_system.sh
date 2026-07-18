#!/bin/bash
# MoonOS Unit Tests - Build System
# Tests for MKBS build system functionality

set -euo pipefail

TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${TEST_ROOT}/../test_runner.sh"

# Test: MKBS help command
test_mkbs_help() {
    test_assert_success "bash ${MOONOS_ROOT}/mkbs/mkbs --help" "MKBS help should work"
}

# Test: MKBS version
test_mkbs_version() {
    test_assert_success "bash ${MOONOS_ROOT}/mkbs/mkbs --version" "MKBS version should work"
}

# Test: Package loading
test_pkg_load() {
    local pkg_dir="${MOONOS_ROOT}/packages/base/musl"
    test_assert_directory_exists "$pkg_dir" "musl package directory should exist"
    test_assert_file_exists "${pkg_dir}/PKGBUILD" "musl PKGBUILD should exist"
}

# Test: Package list
test_pkg_list() {
    test_assert_success "bash ${MOONOS_ROOT}/mkbs/mkbs pkg list" "Package list should work"
}

# Test: Configuration loading
test_config_load() {
    test_assert_success "bash ${MOONOS_ROOT}/mkbs/mkbs configure --target=x86_64" "Configuration should work"
}

# Run tests
run_all_tests
