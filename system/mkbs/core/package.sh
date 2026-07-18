#!/bin/bash
# MKBS Core - Package management
# Handles package metadata, dependencies, and lifecycle

# Package states
readonly PKG_STATE_NONE=0
readonly PKG_STATE_FETCHED=1
readonly PKG_STATE_CHECKED=2
readonly PKG_STATE_EXTRACTED=3
readonly PKG_STATE_PATCHED=4
readonly PKG_STATE_CONFIGURED=5
readonly PKG_STATE_BUILT=6
readonly PKG_STATE_INSTALLED=7
readonly PKG_STATE_PACKED=8
readonly PKG_STATE_PUBLISHED=9

# Package directory structure
# Each package has:
#   PKGBUILD       - Build script
#   patches/       - Optional patch files
#   files/         - Optional additional files
#   test.sh        - Optional test script

# Parse PKGBUILD file
pkg_load() {
    local pkg_dir="$1"
    local pkgbuild="${pkg_dir}/PKGBUILD"

    if [[ ! -f "$pkgbuild" ]]; then
        log_error "No PKGBUILD found in $pkg_dir"
        return 1
    fi

    # Source the PKGBUILD
    # shellcheck disable=SC1090
    source "$pkgbuild"

    # Set package metadata
    PKG_NAME="${pkg_name}"
    PKG_VERSION="${pkg_version}"
    PKG_RELEASE="${pkg_release:-1}"
    PKG_DESCRIPTION="${pkg_description}"
    PKG_URL="${pkg_url}"
    PKG_LICENSE="${pkg_license}"
    PKG_ARCH="${pkg_arch:-any}"
    PKG_DEPENDS="${pkg_depends:-}"
    PKG_BUILD_DEPENDS="${pkg_build_depends:-}"
    PKG_SOURCE="${pkg_source:-}"
    PKG_SHA256="${pkg_sha256:-}"
    PKG_SOURCE_DIR="${pkg_source_dir:-${PKG_NAME}-${PKG_VERSION}}"

    log_debug "Loaded package: ${PKG_NAME} v${PKG_VERSION}-${PKG_RELEASE}"
}

# Get package state
pkg_get_state() {
    local pkg_name="$1"
    local state_file="${MKBS_BUILD_DIR}/${pkg_name}/.state"

    if [[ -f "$state_file" ]]; then
        cat "$state_file"
    else
        echo "$PKG_STATE_NONE"
    fi
}

# Set package state
pkg_set_state() {
    local pkg_name="$1"
    local state="$2"
    local state_file="${MKBS_BUILD_DIR}/${pkg_name}/.state"

    mkdir -p "$(dirname "$state_file")"
    echo "$state" > "$state_file"
    log_debug "Package $pkg_name state set to $state"
}

# Check if package needs building
pkg_needs_build() {
    local pkg_dir="$1"
    local pkgbuild="${pkg_dir}/PKGBUILD"

    if [[ ! -f "$pkgbuild" ]]; then
        return 1
    fi

    # Source PKGBUILD to get version info
    (
        # shellcheck disable=SC1090
        source "$pkgbuild"

        local pkg_name="${pkg_name}"
        local pkg_version="${pkg_version}"
        local pkg_release="${pkg_release:-1}"

        # Check if already built
        local pkg_file="${MKBS_OUTPUT_DIR}/${pkg_name}-${pkg_version}-${pkg_release}.pkg.tar.xz"
        if [[ -f "$pkg_file" ]]; then
            # Check if PKGBUILD is newer than package
            if [[ "$pkgbuild" -nt "$pkg_file" ]]; then
                return 0
            fi
            return 1
        fi
        return 0
    )
}

# Fetch package sources
pkg_fetch() {
    local pkg_dir="$1"
    local pkgbuild="${pkg_dir}/PKGBUILD"

    log_step "Fetch" "Downloading sources for $(basename "$pkg_dir")"

    # Source PKGBUILD
    (
        # shellcheck disable=SC1090
        source "$pkgbuild"

        local sources=("${pkg_source[@]}")
        local dest="${MKBS_CACHE_DIR:-${MOONOS_ROOT}/cache}"

        mkdir -p "$dest"

        for source_url in "${sources[@]}"; do
            local filename
            filename="$(basename "$source_url")"
            local filepath="${dest}/${filename}"

            if [[ -f "$filepath" ]]; then
                log_info "Source already cached: $filename"
                continue
            fi

            log_info "Downloading: $source_url"
            if ! curl -L -o "$filepath" "$source_url"; then
                log_error "Failed to download: $source_url"
                return 1
            fi
        done

        pkg_set_state "${pkg_name}" "$PKG_STATE_FETCHED"
    )
}

# Verify package sources
pkg_verify() {
    local pkg_dir="$1"
    local pkgbuild="${pkg_dir}/PKGBUILD"

    log_step "Verify" "Checking source integrity for $(basename "$pkg_dir")"

    (
        # shellcheck disable=SC1090
        source "$pkgbuild"

        local sources=("${pkg_source[@]}")
        local checksums=("${pkg_sha256[@]}")
        local cache="${MKBS_CACHE_DIR:-${MOONOS_ROOT}/cache}"

        if [[ ${#sources[@]} -ne ${#checksums[@]} ]]; then
            log_warn "Checksum count mismatch, skipping verification"
            return 0
        fi

        for i in "${!sources[@]}"; do
            local filename
            filename="$(basename "${sources[$i]}")"
            local filepath="${cache}/${filename}"
            local expected="${checksums[$i]}"

            if [[ "$expected" == "SKIP" ]]; then
                log_debug "Skipping checksum for $filename"
                continue
            fi

            local actual
            actual="$(sha256sum "$filepath" | cut -d' ' -f1)"

            if [[ "$actual" != "$expected" ]]; then
                log_error "Checksum mismatch for $filename"
                log_error "  Expected: $expected"
                log_error "  Got:      $actual"
                return 1
            fi

            log_debug "Checksum verified: $filename"
        done

        pkg_set_state "${pkg_name}" "$PKG_STATE_CHECKED"
    )
}

# Extract package sources
pkg_extract() {
    local pkg_dir="$1"
    local pkgbuild="${pkg_dir}/PKGBUILD"
    local build_dir="${MKBS_BUILD_DIR}/$(basename "$pkg_dir")"

    log_step "Extract" "Extracting sources for $(basename "$pkg_dir")"

    (
        # shellcheck disable=SC1090
        source "$pkgbuild"

        local cache="${MKBS_CACHE_DIR:-${MOONOS_ROOT}/cache}"

        mkdir -p "$build_dir"

        for source_url in "${pkg_source[@]}"; do
            local filename
            filename="$(basename "$source_url")"
            local filepath="${cache}/${filename}"

            log_info "Extracting: $filename"

            case "$filename" in
                *.tar.gz|*.tgz)
                    tar xzf "$filepath" -C "$build_dir"
                    ;;
                *.tar.bz2|*.tbz2)
                    tar xjf "$filepath" -C "$build_dir"
                    ;;
                *.tar.xz|*.txz)
                    tar xJf "$filepath" -C "$build_dir"
                    ;;
                *.tar.zst)
                    tar --zstd -xf "$filepath" -C "$build_dir"
                    ;;
                *.tar)
                    tar xf "$filepath" -C "$build_dir"
                    ;;
                *.zip)
                    unzip -q "$filepath" -d "$build_dir"
                    ;;
                *)
                    log_warn "Unknown archive format: $filename"
                    cp "$filepath" "$build_dir/"
                    ;;
            esac
        done

        pkg_set_state "${pkg_name}" "$PKG_STATE_EXTRACTED"
    )
}

# Build package
pkg_build() {
    local pkg_dir="$1"
    local pkgbuild="${pkg_dir}/PKGBUILD"
    local build_dir="${MKBS_BUILD_DIR}/$(basename "$pkg_dir")"

    log_step "Build" "Building $(basename "$pkg_dir")"

    (
        # shellcheck disable=SC1090
        source "$pkgbuild"

        # Change to source directory
        cd "$build_dir/$PKG_SOURCE_DIR" || {
            log_error "Source directory not found: $PKG_SOURCE_DIR"
            return 1
        }

        # Source the build functions
        source "${MKBS_ROOT}/core/package.sh"

        # Execute build steps
        if type pkg_prelude &>/dev/null; then
            log_info "Running pre-build step"
            pkg_prelude
        fi

        if type pkg_configure &>/dev/null; then
            log_info "Configuring package"
            pkg_configure
        fi

        if type pkg_compile &>/dev/null; then
            log_info "Compiling package"
            pkg_compile
        fi

        if type pkg_check &>/dev/null; then
            log_info "Running tests"
            pkg_check
        fi

        if type pkg_install &>/dev/null; then
            log_info "Installing to staging"
            pkg_install
        fi

        pkg_set_state "${pkg_name}" "$PKG_STATE_BUILT"
    )
}

# Package the built package
pkg_package() {
    local pkg_dir="$1"
    local pkgbuild="${pkg_dir}/PKGBUILD"
    local build_dir="${MKBS_BUILD_DIR}/$(basename "$pkg_dir")"
    local staging_dir="${build_dir}/.pkg"

    log_step "Package" "Creating package for $(basename "$pkg_dir")"

    (
        # shellcheck disable=SC1090
        source "$pkgbuild"

        mkdir -p "$staging_dir"

        # Create package metadata
        mkdir -p "${staging_dir}/.PKGINFO"
        cat > "${staging_dir}/.PKGINFO/info" << EOF
# MoonOS Package Info
pkgname=${pkg_name}
pkgver=${pkg_version}
pkgrel=${pkg_release}
pkgdesc=${pkg_description}
url=${pkg_url}
arch=${pkg_arch}
license=${pkg_license}
depends=${pkg_depends[*]:-}
builddepends=${pkg_build_depends[*]:-}
builddate=$(date +%s)
packager=MoonOS Build System
EOF

        # Create tarball
        local pkg_file="${MKBS_OUTPUT_DIR}/${pkg_name}-${pkg_version}-${pkg_release}.pkg.tar.xz"
        cd "$staging_dir"
        tar cJf "$pkg_file" .

        log_info "Package created: $pkg_file"
        pkg_set_state "${pkg_name}" "$PKG_STATE_PACKED"
    )
}

# Install package
pkg_install() {
    local pkg_name="$1"
    local pkg_file="${MKBS_OUTPUT_DIR}/${pkg_name}-*.pkg.tar.xz"

    # Find the latest version
    local latest
    latest=$(ls -t $pkg_file 2>/dev/null | head -n1)

    if [[ -z "$latest" ]]; then
        log_error "No package found for $pkg_name"
        return 1
    fi

    log_step "Install" "Installing $pkg_name"

    # Extract to sysroot
    tar xJf "$latest" -C "$MKBS_SYSROOT"

    log_success "Installed $pkg_name"
}

# Check package dependencies
pkg_check_deps() {
    local pkg_dir="$1"
    local pkgbuild="${pkg_dir}/PKGBUILD"

    (
        # shellcheck disable=SC1090
        source "$pkgbuild"

        local deps=("${pkg_depends[@]}" "${pkg_build_depends[@]}")

        for dep in "${deps[@]}"; do
            local dep_name="${dep%%[><=]*}"

            # Check if dependency exists in package list
            if ! find "${MKBS_REPO_DIR}" -name "$dep_name" -type d | grep -q .; then
                log_warn "Dependency not found in repository: $dep_name"
            fi
        done
    )
}

# List all packages
pkg_list() {
    local repo_dir="${MKBS_REPO_DIR}"

    if [[ ! -d "$repo_dir" ]]; then
        log_error "Repository directory not found: $repo_dir"
        return 1
    fi

    find "$repo_dir" -name "PKGBUILD" -type f | while read -r pkgbuild; do
        local pkg_dir
        pkg_dir="$(dirname "$pkgbuild")"
        local pkg_name
        pkg_name="$(basename "$pkg_dir")"

        (
            # shellcheck disable=SC1090
            source "$pkgbuild"
            echo "${pkg_name} ${pkg_version}-${pkg_release}"
        )
    done
}

# Show package info
pkg_info() {
    local pkg_name="$1"
    local pkg_dir="${MKBS_REPO_DIR}/${pkg_name}"

    if [[ ! -d "$pkg_dir" ]]; then
        log_error "Package not found: $pkg_name"
        return 1
    fi

    (
        # shellcheck disable=SC1090
        source "${pkg_dir}/PKGBUILD"

        echo "Name:        ${pkg_name}"
        echo "Version:     ${pkg_version}"
        echo "Release:     ${pkg_release}"
        echo "Description: ${pkg_description}"
        echo "URL:         ${pkg_url}"
        echo "License:     ${pkg_license}"
        echo "Arch:        ${pkg_arch}"
        echo "Depends:     ${pkg_depends[*]:-none}"
        echo "BuildDeps:   ${pkg_build_depends[*]:-none}"
    )
}

# Update package checksums
pkg_update_checksums() {
    local pkg_dir="$1"
    local pkgbuild="${pkg_dir}/PKGBUILD"
    local cache="${MKBS_CACHE_DIR:-${MOONOS_ROOT}/cache}"

    log_step "Update" "Updating checksums for $(basename "$pkg_dir")"

    (
        # shellcheck disable=SC1090
        source "$pkgbuild"

        local sources=("${pkg_source[@]}")
        local new_checksums=()

        for source_url in "${sources[@]}"; do
            local filename
            filename="$(basename "$source_url")"
            local filepath="${cache}/${filename}"

            if [[ ! -f "$filepath" ]]; then
                log_error "Source not downloaded: $filename"
                log_error "Run: mkbs pkg fetch $(basename "$pkg_dir")"
                return 1
            fi

            local checksum
            checksum="$(sha256sum "$filepath" | cut -d' ' -f1)"
            new_checksums+=("$checksum")
        done

        # Update PKGBUILD with new checksums
        local checksums_str="${new_checksums[*]}"
        sed -i "s/^pkg_sha256=(.*/pkg_sha256=($checksums_str)/" "$pkgbuild"

        log_success "Checksums updated"
    )
}
