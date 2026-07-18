#!/bin/bash
# MoonOS Release Engineering
# Automated release process

set -euo pipefail

RELEASE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOONOS_ROOT="$(dirname "$RELEASE_ROOT")"

# Release configuration
declare -A RELEASE_CONFIG=(
    [version]=""
    [tag]=""
    [branch]="main"
    [changelog]=""
    [output_dir]="${MOONOS_ROOT}/release/output"
    [staging_dir]="${MOONOS_ROOT}/release/staging"
)

usage() {
    cat << EOF
MoonOS Release Engineering

Usage: release.sh <command> [options]

Commands:
    create     Create a new release
    tag        Tag a release
    changelog  Generate changelog
    checksums  Generate checksums
    publish    Publish release artifacts

Options:
    --version=<version>    Release version (e.g., 1.0.0)
    --tag=<tag>            Release tag (e.g., v1.0.0)
    --branch=<branch>      Release branch (default: main)
    --output=<dir>         Output directory

Examples:
    release.sh create --version=1.0.0
    release.sh tag --version=1.0.0
    release.sh changelog --version=1.0.0

EOF
    exit 0
}

main() {
    local command=""
    local args=()

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --version=*)
                RELEASE_CONFIG[version]="${1#*=}"
                shift
                ;;
            --tag=*)
                RELEASE_CONFIG[tag]="${1#*=}"
                shift
                ;;
            --branch=*)
                RELEASE_CONFIG[branch]="${1#*=}"
                shift
                ;;
            --output=*)
                RELEASE_CONFIG[output_dir]="${1#*=}"
                shift
                ;;
            --help|-h)
                usage
                ;;
            *)
                if [[ -z "$command" ]]; then
                    command="$1"
                else
                    args+=("$1")
                fi
                shift
                ;;
        esac
    done

    # Execute command
    case "$command" in
        create)
            create_release "${args[@]}"
            ;;
        tag)
            tag_release "${args[@]}"
            ;;
        changelog)
            generate_changelog "${args[@]}"
            ;;
        checksums)
            generate_checksums "${args[@]}"
            ;;
        publish)
            publish_release "${args[@]}"
            ;;
        "")
            usage
            ;;
        *)
            echo "Unknown command: $command"
            usage
            ;;
    esac
}

# Create release
create_release() {
    echo "Creating release ${RELEASE_CONFIG[version]}..."

    # Validate version
    if [[ -z "${RELEASE_CONFIG[version]}" ]]; then
        echo "Error: Version not specified"
        echo "Use --version=<version> to specify version"
        exit 1
    fi

    # Set tag
    RELEASE_CONFIG[tag]="v${RELEASE_CONFIG[version]}"

    # Create output directories
    mkdir -p "${RELEASE_CONFIG[output_dir]}"
    mkdir -p "${RELEASE_CONFIG[staging_dir]}"

    # Step 1: Validate release
    step_validate_release

    # Step 2: Generate changelog
    step_generate_changelog

    # Step 3: Build all packages
    step_build_packages

    # Step 4: Run tests
    step_run_tests

    # Step 5: Create installation images
    step_create_images

    # Step 6: Generate checksums
    step_generate_checksums

    # Step 7: Create release notes
    step_create_release_notes

    echo ""
    echo "=========================================="
    echo "  Release ${RELEASE_CONFIG[version]} Created!"
    echo "=========================================="
    echo ""
    echo "Release artifacts are in: ${RELEASE_CONFIG[output_dir]}"
    echo ""
    echo "Next steps:"
    echo "  1. Review release notes"
    echo "  2. Tag the release: release.sh tag --version=${RELEASE_CONFIG[version]}"
    echo "  3. Publish to GitHub: release.sh publish --version=${RELEASE_CONFIG[version]}"
    echo ""
}

# Validate release
step_validate_release() {
    echo "Step 1/7: Validating release..."

    # Check if version is set
    if [[ -z "${RELEASE_CONFIG[version]}" ]]; then
        echo "Error: Version not set"
        exit 1
    fi

    # Check if on correct branch
    local current_branch
    current_branch=$(git rev-parse --abbrev-ref HEAD)
    if [[ "$current_branch" != "${RELEASE_CONFIG[branch]}" ]]; then
        echo "Warning: Not on ${RELEASE_CONFIG[branch]} branch (currently on $current_branch)"
        read -p "Continue? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    # Check for uncommitted changes
    if ! git diff --quiet; then
        echo "Warning: There are uncommitted changes"
        read -p "Continue? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    echo "Validation complete."
}

# Generate changelog
step_generate_changelog() {
    echo "Step 2/7: Generating changelog..."

    # Generate changelog from git history
    local changelog_file="${RELEASE_CONFIG[staging_dir]}/CHANGELOG.md"

    cat > "$changelog_file" << EOF
# MoonOS ${RELEASE_CONFIG[version]} Changelog

## Release Date
$(date '+%Y-%m-%d')

## Changes

EOF

    # Get commits since last tag
    local last_tag
    last_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

    if [[ -n "$last_tag" ]]; then
        git log "$last_tag"..HEAD --pretty=format:"- %s (%h)" >> "$changelog_file"
    else
        git log --pretty=format:"- %s (%h)" >> "$changelog_file"
    fi

    echo "" >> "$changelog_file"

    echo "Changelog generated."
}

# Build packages
step_build_packages() {
    echo "Step 3/7: Building packages..."

    # Build base packages
    ./mkbs/mkbs configure --target=x86_64 --profile=base
    ./mkbs/mkbs build base

    echo "Packages built."
}

# Run tests
step_run_tests() {
    echo "Step 4/7: Running tests..."

    ./tests/test_runner.sh

    echo "Tests complete."
}

# Create images
step_create_images() {
    echo "Step 5/7: Creating installation images..."

    # Create ISO image
    ./mkbs/mkbs image \
        --format=iso \
        --output="${RELEASE_CONFIG[output_dir]}/moonos-${RELEASE_CONFIG[version]}-x86_64.iso"

    echo "Images created."
}

# Generate checksums
step_generate_checksums() {
    echo "Step 6/7: Generating checksums..."

    local checksums_file="${RELEASE_CONFIG[output_dir]}/checksums.txt"

    cd "${RELEASE_CONFIG[output_dir]}"
    find . -name "*.iso" -o -name "*.img" | while read -r file; do
        sha256sum "$file" >> "$checksums_file"
    done

    echo "Checksums generated."
}

# Create release notes
step_create_release_notes() {
    echo "Step 7/7: Creating release notes..."

    local release_notes="${RELEASE_CONFIG[output_dir]}/RELEASE_NOTES.md"

    cat > "$release_notes" << EOF
# MoonOS ${RELEASE_CONFIG[version]}

## Release Information

- **Version:** ${RELEASE_CONFIG[version]}
- **Release Date:** $(date '+%Y-%m-%d')
- **Codename:** TBD

## New Features

- Feature 1
- Feature 2

## Bug Fixes

- Fix 1
- Fix 2

## Security Updates

- Security update 1

## Known Issues

- Issue 1

## Upgrade Instructions

### From Previous Version

1. Update your system:
   \`\`\`bash
   sudo pkg update
   sudo pkg upgrade
   \`\`\`

2. Reboot if necessary:
   \`\`\`bash
   sudo reboot
   \`\`\`

## Verification

### Checksums

See \`checksums.txt\` for SHA256 verification.

### Verify Download

\`\`\`bash
sha256sum -c checksums.txt moonos-${RELEASE_CONFIG[version]}-x86_64.iso
\`\`\`

## Thanks

Thanks to all contributors who helped with this release!
EOF

    echo "Release notes created."
}

# Tag release
tag_release() {
    if [[ -z "${RELEASE_CONFIG[version]}" ]]; then
        echo "Error: Version not specified"
        exit 1
    fi

    RELEASE_CONFIG[tag]="v${RELEASE_CONFIG[version]}"

    echo "Tagging release ${RELEASE_CONFIG[tag]}..."

    # Create annotated tag
    git tag -a "${RELEASE_CONFIG[tag]}" -m "Release ${RELEASE_CONFIG[version]}"

    echo "Tag created: ${RELEASE_CONFIG[tag]}"
    echo "Push with: git push origin ${RELEASE_CONFIG[tag]}"
}

# Generate changelog
generate_changelog() {
    if [[ -z "${RELEASE_CONFIG[version]}" ]]; then
        echo "Error: Version not specified"
        exit 1
    fi

    step_generate_changelog
}

# Generate checksums
generate_checksums() {
    step_generate_checksums
}

# Publish release
publish_release() {
    if [[ -z "${RELEASE_CONFIG[version]}" ]]; then
        echo "Error: Version not specified"
        exit 1
    fi

    RELEASE_CONFIG[tag]="v${RELEASE_CONFIG[version]}"

    echo "Publishing release ${RELEASE_CONFIG[version]}..."

    # Check if gh CLI is available
    if ! command -v gh &>/dev/null; then
        echo "Error: GitHub CLI (gh) not found"
        echo "Install it from: https://cli.github.com/"
        exit 1
    fi

    # Create GitHub release
    gh release create "${RELEASE_CONFIG[tag]}" \
        --title "MoonOS ${RELEASE_CONFIG[version]}" \
        --notes-file "${RELEASE_CONFIG[output_dir]}/RELEASE_NOTES.md" \
        "${RELEASE_CONFIG[output_dir]}/moonos-${RELEASE_CONFIG[version]}-x86_64.iso#MoonOS ${RELEASE_CONFIG[version]} (x86_64)" \
        "${RELEASE_CONFIG[output_dir]}/checksums.txt"

    echo "Release published to GitHub!"
}

main "$@"
