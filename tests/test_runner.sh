#!/bin/bash
# MoonOS Test Framework
# Test runner for packages and system components

set -euo pipefail

TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOONOS_ROOT="$(dirname "$TEST_ROOT")"

# Test configuration
declare -A TEST_CONFIG=(
    [verbose]=0
    [parallel]=0
    [timeout]=300
    [output_dir]="${MOONOS_ROOT}/test-results"
)

# Test results
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Colors
readonly TEST_GREEN='\033[0;32m'
readonly TEST_RED='\033[0;31m'
readonly TEST_YELLOW='\033[1;33m'
readonly TEST_BLUE='\033[0;34m'
readonly TEST_NC='\033[0m'

# Run all tests
run_all_tests() {
    echo "=========================================="
    echo "  MoonOS Test Suite"
    echo "=========================================="
    echo ""

    # Create output directory
    mkdir -p "${TEST_CONFIG[output_dir]}"

    # Run test suites
    run_test_suite "unit" "Unit Tests"
    run_test_suite "integration" "Integration Tests"
    run_test_suite "system" "System Tests"
    run_test_suite "security" "Security Tests"

    # Print summary
    print_test_summary
}

# Run a test suite
run_test_suite() {
    local suite="$1"
    local description="$2"
    local suite_dir="${TEST_ROOT}/${suite}"

    if [[ ! -d "$suite_dir" ]]; then
        echo -e "${TEST_YELLOW}Skipping $description (directory not found)${TEST_NC}"
        return 0
    fi

    echo ""
    echo -e "${TEST_BLUE}Running $description...${TEST_NC}"
    echo "-------------------------------------------"

    for test_file in "$suite_dir"/test_*.sh; do
        if [[ -f "$test_file" ]]; then
            run_single_test "$test_file"
        fi
    done
}

# Run a single test
run_single_test() {
    local test_file="$1"
    local test_name
    test_name=$(basename "$test_file" .sh)

    ((TESTS_RUN++))

    echo -n "  $test_name... "

    # Run test with timeout
    local output
    if output=$(timeout "${TEST_CONFIG[timeout]}" bash "$test_file" 2>&1); then
        ((TESTS_PASSED++))
        echo -e "${TEST_GREEN}PASS${TEST_NC}"
    else
        local exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
            ((TESTS_SKIPPED++))
            echo -e "${TEST_YELLOW}TIMEOUT${TEST_NC}"
        else
            ((TESTS_FAILED++))
            echo -e "${TEST_RED}FAIL${TEST_NC}"
            if [[ "${TEST_CONFIG[verbose]}" -eq 1 ]]; then
                echo "    Output: $output"
            fi

            # Save failure output
            echo "$output" > "${TEST_CONFIG[output_dir]}/${test_name}.log"
        fi
    fi
}

# Print test summary
print_test_summary() {
    echo ""
    echo "=========================================="
    echo "  Test Summary"
    echo "=========================================="
    echo "  Total:    $TESTS_RUN"
    echo -e "  Passed:   ${TEST_GREEN}$TESTS_PASSED${TEST_NC}"
    echo -e "  Failed:   ${TEST_RED}$TESTS_FAILED${TEST_NC}"
    echo -e "  Skipped:  ${TEST_YELLOW}$TESTS_SKIPPED${TEST_NC}"
    echo "=========================================="
    echo ""

    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo "Failed tests:"
        for log in "${TEST_CONFIG[output_dir]}"/*.log; do
            if [[ -f "$log" ]]; then
                echo "  - $(basename "$log" .log)"
            fi
        done
        return 1
    fi

    return 0
}

# Test helper functions
test_assert() {
    local condition="$1"
    local message="${2:-Assertion failed}"

    if ! eval "$condition"; then
        echo "FAIL: $message"
        return 1
    fi
}

test_assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Values not equal}"

    if [[ "$expected" != "$actual" ]]; then
        echo "FAIL: $message"
        echo "  Expected: $expected"
        echo "  Got:      $actual"
        return 1
    fi
}

test_assert_file_exists() {
    local file="$1"
    local message="${2:-File does not exist}"

    if [[ ! -f "$file" ]]; then
        echo "FAIL: $message"
        echo "  File: $file"
        return 1
    fi
}

test_assert_directory_exists() {
    local dir="$1"
    local message="${2:-Directory does not exist}"

    if [[ ! -d "$dir" ]]; then
        echo "FAIL: $message"
        echo "  Directory: $dir"
        return 1
    fi
}

test_assert_command_exists() {
    local command="$1"
    local message="${2:-Command not found}"

    if ! command -v "$command" &>/dev/null; then
        echo "FAIL: $message"
        echo "  Command: $command"
        return 1
    fi
}

test_assert_success() {
    local command="$1"
    local message="${2:-Command failed}"

    if ! eval "$command" &>/dev/null; then
        echo "FAIL: $message"
        echo "  Command: $command"
        return 1
    fi
}

test_skip() {
    local message="${1:-Skipped}"
    echo "SKIP: $message"
    return 0
}

# Main function
main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --verbose|-v)
                TEST_CONFIG[verbose]=1
                shift
                ;;
            --parallel|-p)
                TEST_CONFIG[parallel]=1
                shift
                ;;
            --timeout=*)
                TEST_CONFIG[timeout]="${1#*=}"
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [options]"
                echo ""
                echo "Options:"
                echo "  --verbose, -v       Enable verbose output"
                echo "  --parallel, -p      Run tests in parallel"
                echo "  --timeout=<seconds> Set test timeout"
                echo "  --help, -h          Show this help"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # Run tests
    run_all_tests
}

# Run main function if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
