#!/bin/bash
# MKBS Core - Utility functions
# Common utilities used across the build system

# Check if running as root
is_root() {
    [[ $EUID -eq 0 ]]
}

# Require root
require_root() {
    if ! is_root; then
        log_fatal "This operation requires root privileges"
    fi
}

# Check if a command exists
command_exists() {
    command -v "$1" &>/dev/null
}

# Get number of CPU cores
get_nproc() {
    nproc 2>/dev/null || echo 4
}

# Human readable size
human_size() {
    local bytes="$1"
    local units=("B" "KB" "MB" "GB" "TB")
    local unit=0

    while (( bytes > 1024 )); do
        bytes=$((bytes / 1024))
        ((unit++))
    done

    echo "${bytes}${units[$unit]}"
}

# Calculate SHA256
sha256() {
    sha256sum "$1" | cut -d' ' -f1
}

# Retry a command
retry() {
    local attempts="$1"
    local delay="$2"
    shift 2

    local count=0
    until "$@"; do
        ((count++))
        if [[ $count -ge $attempts ]]; then
            log_error "Command failed after $attempts attempts: $*"
            return 1
        fi
        log_warn "Attempt $count/$attempts failed, retrying in ${delay}s..."
        sleep "$delay"
    done
}

# Download file with progress
download() {
    local url="$1"
    local output="$2"

    if command_exists curl; then
        curl -L -o "$output" --progress-bar "$url"
    elif command_exists wget; then
        wget -O "$output" "$url"
    else
        log_error "No download tool found (install curl or wget)"
        return 1
    fi
}

# Create a temporary directory
temp_dir() {
    mktemp -d "${TMPDIR:-/tmp}/mkbs.XXXXXX"
}

# Cleanup temporary files on exit
cleanup() {
    if [[ -n "${MKBS_TEMP_DIR:-}" ]]; then
        rm -rf "$MKBS_TEMP_DIR"
    fi
}

trap cleanup EXIT

# Cross-compilation environment setup
setup_cross_env() {
    local target="$1"
    local sysroot="$2"

    export CC="${target}-gcc"
    export CXX="${target}-g++"
    export AR="${target}-ar"
    export AS="${target}-as"
    export LD="${target}-ld"
    export RANLIB="${target}-ranlib"
    export STRIP="${target}-strip"
    export NM="${target}-nm"
    export OBJCOPY="${target}-objcopy"
    export OBJDUMP="${target}-objdump"
    export READELF="${target}-readelf"
    export CFLAGS="--sysroot=${sysroot} -O2"
    export CXXFLAGS="--sysroot=${sysroot} -O2"
    export LDFLAGS="--sysroot=${sysroot}"
    export PKG_CONFIG_PATH="${sysroot}/usr/lib/pkgconfig:${sysroot}/usr/share/pkgconfig"
}

# Native build environment setup
setup_native_env() {
    local sysroot="$1"

    export CC="gcc"
    export CXX="g++"
    export AR="ar"
    export AS="as"
    export LD="ld"
    export RANLIB="ranlib"
    export STRIP="strip"
    export NM="nm"
    export OBJCOPY="objcopy"
    export OBJDUMP="objdump"
    export READELF="readelf"
    export CFLAGS="-O2"
    export CXXFLAGS="-O2"
    export LDFLAGS=""
    export PKG_CONFIG_PATH="${sysroot}/usr/lib/pkgconfig:${sysroot}/usr/share/pkgconfig"
}

# Verify package checksum
verify_checksum() {
    local file="$1"
    local expected="$2"

    local actual
    actual=$(sha256 "$file")

    if [[ "$actual" != "$expected" ]]; then
        log_error "Checksum mismatch for $file"
        log_error "  Expected: $expected"
        log_error "  Got:      $actual"
        return 1
    fi

    return 0
}

# Compare version strings
version_gt() {
    [[ "$1" != "$2" ]] && [[ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" == "$2" ]]
}

# Compare version strings
version_lt() {
    [[ "$1" != "$2" ]] && [[ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" == "$1" ]]
}

# Get package filename
pkg_filename() {
    local name="$1"
    local version="$2"
    local release="$3"
    local ext="${4:-pkg.tar.xz}"

    echo "${name}-${version}-${release}.${ext}"
}

# Extract package name from filename
pkg_name_from_file() {
    local filename="$1"
    echo "$filename" | sed 's/-[0-9].*$//'
}

# Extract version from filename
pkg_version_from_file() {
    local filename="$1"
    echo "$filename" | sed 's/^[^-]*-//' | sed 's/-[0-9]*\..*$//'
}

# Generate build report
generate_build_report() {
    local output="${MOONOS_ROOT}/build-report.txt"

    cat > "$output" << EOF
MoonOS Build Report
===================
Generated: $(date)
Target:    ${MKBS_CONFIG[target]:-unknown}
Profile:   ${MKBS_CONFIG[profile]:-unknown}

Packages Built:
EOF

    # List built packages
    find "$MKBS_OUTPUT_DIR" -name "*.pkg.tar.xz" -type f | while read -r pkg; do
        echo "  - $(basename "$pkg")"
    done >> "$output"

    cat >> "$output" << EOF

Total Size:
$(du -sh "$MKBS_OUTPUT_DIR" 2>/dev/null | cut -f1)

Build Log:
${MKBS_LOG_FILE:-/tmp/mkbs.log}
EOF

    log_info "Build report generated: $output"
}

# Validate PKGBUILD
validate_pkgbuild() {
    local pkgbuild="$1"

    if [[ ! -f "$pkgbuild" ]]; then
        log_error "PKGBUILD not found: $pkgbuild"
        return 1
    fi

    # Source PKGBUILD
    (
        # shellcheck disable=SC1090
        source "$pkgbuild"

        # Check required variables
        local required_vars=(pkg_name pkg_version pkg_description pkg_url pkg_license pkg_source)
        for var in "${required_vars[@]}"; do
            if [[ -z "${!var:-}" ]]; then
                log_error "Missing required variable: $var"
                return 1
            fi
        done

        # Check required functions
        local required_funcs=(pkg_configure pkg_compile pkg_install)
        for func in "${required_funcs[@]}"; do
            if ! type "$func" &>/dev/null; then
                log_error "Missing required function: $func"
                return 1
            fi
        done

        log_info "PKGBUILD validation passed: $pkgbuild"
    )
}

# Lint PKGBUILD
lint_pkgbuild() {
    local pkgbuild="$1"

    log_info "Linting: $pkgbuild"

    # Check for common issues
    (
        # shellcheck disable=SC1090
        source "$pkgbuild"

        # Check for hardcoded paths
        if grep -q '/usr/local' "$pkgbuild"; then
            log_warn "Hardcoded /usr/local path found in $pkgbuild"
        fi

        # Check for missing checksums
        if [[ "${#pkg_source[@]}" -gt 0 ]] && [[ "${#pkg_sha256[@]}" -eq 0 ]]; then
            log_warn "No checksums defined in $pkgbuild"
        fi

        # Check for proper quoting
        if grep -q 'pkg_version' "$pkgbuild" | grep -v '"'; then
            log_warn "Possible unquoted variable expansion in $pkgbuild"
        fi

        log_info "Lint completed: $pkgbuild"
    )
}
