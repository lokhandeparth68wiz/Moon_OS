#!/bin/bash
# MKBS Core - Build orchestration
# Manages the complete build pipeline

# Build a single package
build_package() {
    local pkg_name="$1"
    local pkg_dir="${MKBS_REPO_DIR}/${pkg_name}"

    if [[ ! -d "$pkg_dir" ]]; then
        log_error "Package not found: $pkg_name"
        return 1
    fi

    log_step "Build" "Processing package: $pkg_name"

    # Check if already built
    local state
    state="$(pkg_get_state "$pkg_name")"
    if [[ "$state" -ge "$PKG_STATE_BUILT" ]]; then
        log_info "Package $pkg_name already built, skipping"
        return 0
    fi

    # Load package
    pkg_load "$pkg_dir"

    # Check dependencies
    pkg_check_deps "$pkg_dir"

    # Fetch sources
    pkg_fetch "$pkg_dir"

    # Verify sources
    pkg_verify "$pkg_dir"

    # Extract sources
    pkg_extract "$pkg_dir"

    # Apply patches
    pkg_apply_patches "$pkg_dir"

    # Build package
    pkg_build "$pkg_dir"

    # Create package
    pkg_package "$pkg_dir"

    log_success "Built: $pkg_name"
}

# Build package group
build_group() {
    local group="$1"
    local packages

    case "$group" in
        minimal)
            packages="musl coreutils busybox kernel-headers"
            ;;
        base)
            packages="musl coreutils busybox kernel-headers linux bash openrc util-linux e2fsprogs"
            ;;
        desktop)
            build_group base
            packages="mesa xorg-server wayland gnome-shell firefox"
            ;;
        server)
            build_group base
            packages="nginx postgresql openssh docker-ce"
            ;;
        development)
            build_group base
            packages="gcc binutils gdb make cmake meson ninja clang llvm"
            ;;
        all)
            packages=$(pkg_list | awk '{print $1}')
            ;;
        *)
            log_error "Unknown package group: $group"
            log_error "Available groups: minimal, base, desktop, server, development, all"
            return 1
            ;;
    esac

    for pkg in $packages; do
        build_package "$pkg"
    done
}

# Build command
mkbs_build() {
    local build_targets=()
    local build_all=0

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --all)
                build_all=1
                ;;
            --force)
                # Force rebuild by cleaning
                mkbs_clean --package "$2"
                shift
                ;;
            --no-tests)
                MKBS_SKIP_TESTS=1
                ;;
            -*)
                log_error "Unknown build option: $1"
                exit 1
                ;;
            *)
                build_targets+=("$1")
                ;;
        esac
        shift
    done

    # Initialize
    mkbs_init_config

    # Create build directories
    mkdir -p "$MKBS_BUILD_DIR" "$MKBS_OUTPUT_DIR"

    # Build all if requested
    if [[ "$build_all" -eq 1 ]]; then
        build_group all
        return $?
    fi

    # Build specified targets
    if [[ ${#build_targets[@]} -eq 0 ]]; then
        log_error "No build targets specified"
        log_error "Usage: mkbs build <package|group> [--all]"
        exit 1
    fi

    for target in "${build_targets[@]}"; do
        # Check if it's a group
        if [[ -n "${MKBS_PROFILES[$target]+x}" ]] || \
           [[ "$target" == "minimal" ]] || \
           [[ "$target" == "all" ]]; then
            build_group "$target"
        else
            build_package "$target"
        fi
    done

    log_success "Build completed successfully"
}

# Apply patches to package
pkg_apply_patches() {
    local pkg_dir="$1"
    local patches_dir="${pkg_dir}/patches"
    local build_dir="${MKBS_BUILD_DIR}/$(basename "$pkg_dir")"

    if [[ ! -d "$patches_dir" ]]; then
        return 0
    fi

    log_step "Patch" "Applying patches for $(basename "$pkg_dir")"

    for patch in "$patches_dir"/*.patch; do
        if [[ ! -f "$patch" ]]; then
            continue
        fi

        local patch_name
        patch_name="$(basename "$patch")"
        log_info "Applying: $patch_name"

        # Find the source directory
        local source_dir
        source_dir="$(find "$build_dir" -maxdepth 1 -type d | tail -n1)"

        if ! patch -d "$source_dir" -p1 < "$patch"; then
            log_error "Failed to apply patch: $patch_name"
            return 1
        fi
    done

    log_success "All patches applied"
}

# Clean build artifacts
mkbs_clean() {
    local clean_target=""
    local clean_all=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --all)
                clean_all=1
                ;;
            --package)
                clean_target="$2"
                shift
                ;;
            *)
                clean_target="$1"
                ;;
        esac
        shift
    done

    if [[ "$clean_all" -eq 1 ]]; then
        log_step "Clean" "Removing all build artifacts"
        rm -rf "${MOONOS_ROOT}/build"
        rm -rf "${MOONOS_ROOT}/output"
        rm -rf "${MOONOS_ROOT}/sysroot"
        rm -rf "${MOONOS_ROOT}/toolchain"
        log_success "All build artifacts removed"
        return 0
    fi

    if [[ -n "$clean_target" ]]; then
        log_step "Clean" "Removing build artifacts for $clean_target"
        rm -rf "${MKBS_BUILD_DIR:-${MOONOS_ROOT}/build}/${clean_target}"
        log_success "Cleaned: $clean_target"
        return 0
    fi

    log_error "Specify --all or --package <name>"
    exit 1
}

# Create installation image
mkbs_image() {
    local image_format="iso"
    local image_output="moonos.iso"
    local image_size="2G"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --format=*)
                image_format="${1#*=}"
                ;;
            --output=*)
                image_output="${1#*=}"
                ;;
            --size=*)
                image_size="${1#*=}"
                ;;
            *)
                log_error "Unknown image option: $1"
                exit 1
                ;;
        esac
        shift
    done

    log_step "Image" "Creating $image_format installation image"

    source "${MKBS_ROOT}/core/image.sh"

    case "$image_format" in
        iso)
            create_iso_image "$image_output"
            ;;
        raw)
            create_raw_image "$image_output" "$image_size"
            ;;
        *)
            log_error "Unsupported image format: $image_format"
            exit 1
            ;;
    esac

    log_success "Image created: $image_output"
}
