# MoonOS Build System Documentation

## Overview

MKBS (Moon Kit Build System) is the build system for MoonOS. It automates the process of building packages from source and creating installation media.

## Getting Started

### Prerequisites

Before building MoonOS, ensure your build host has:

```bash
# Required packages (Debian/Ubuntu)
sudo apt-get install -y \
    build-essential \
    git \
    curl \
    wget \
    qemu-user-static \
    binfmt-support

# Required packages (Fedora)
sudo dnf install -y \
    gcc \
    gcc-c++ \
    make \
    git \
    curl \
    wget \
    qemu-user-static
```

### Quick Start

```bash
# Clone the repository
git clone https://github.com/moonos/moonos.git
cd moonos

# Configure for x86_64
./mkbs/mkbs configure --target=x86_64

# Build base system
./mkbs/mkbs build base

# Create installation ISO
./mkbs/mkbs image --format=iso --output=moonos.iso
```

## Configuration

### Target Platforms

MoonOS supports the following target platforms:

| Target | Architecture | Libc | Status |
|--------|--------------|------|--------|
| x86_64 | x86_64 | musl | Stable |
| aarch64 | aarch64 | musl | Stable |
| armv7l | arm | musl | Stable |
| riscv64 | riscv64 | musl | Experimental |

### Build Profiles

| Profile | Description | Packages |
|---------|-------------|----------|
| minimal | Minimal system | kernel, coreutils, busybox |
| base | Base system | minimal + bash, openrc, util-linux |
| desktop | Desktop system | base + xorg, mesa, gnome |
| server | Server system | base + nginx, postgresql, openssh |
| development | Dev tools | base + gcc, binutils, gdb |

### Configuration Options

```bash
# Configure for specific target
./mkbs/mkbs configure --target=aarch64 --profile=server

# Configure with custom options
./mkbs/mkbs configure --target=x86_64 --init=runit --shell=zsh
```

## Building Packages

### Build a Single Package

```bash
# Build a package
./mkbs/mkbs build musl

# Build with verbose output
./mkbs/mkbs build musl --verbose

# Force rebuild
./mkbs/mkbs build musl --force
```

### Build a Package Group

```bash
# Build all packages in a profile
./mkbs/mkbs build base

# Build all packages
./mkbs/mkbs build --all
```

### Package States

Packages go through the following states during build:

1. **Fetched**: Source downloaded
2. **Verified**: Checksum verified
3. **Extracted**: Source extracted
4. **Patched**: Patches applied
5. **Configured**: Configure script run
6. **Built**: Compilation complete
7. **Packaged**: Package created
8. **Installed**: Installed to sysroot

## Package Development

### Creating a New Package

1. Create package directory:
```bash
mkdir -p packages/custom/my-package/patches
```

2. Create PKGBUILD:
```bash
cat > packages/custom/my-package/PKGBUILD << 'EOF'
pkg_name="my-package"
pkg_version="1.0.0"
pkg_release="1"
pkg_description="My awesome package"
pkg_url="https://example.com"
pkg_license="MIT"
pkg_arch="x86_64"
pkg_depends=("musl")
pkg_build_depends=()

pkg_source=("https://example.com/source.tar.gz")
pkg_sha256=("SKIP")

pkg_configure() {
    ./configure --prefix=/usr
}

pkg_compile() {
    make -j$(nproc)
}

pkg_install() {
    make DESTDIR="${PKG_INSTALL_DIR}" install
}
EOF
```

3. Build the package:
```bash
./mkbs/mkbs build my-package
```

### Package Testing

Create a test script:

```bash
cat > packages/custom/my-package/test.sh << 'EOF'
#!/bin/bash
# Test my-package

set -euo pipefail

# Source test framework
source tests/test_runner.sh

# Test: Package installed correctly
test_assert_file_exists "/usr/bin/my-package"

# Test: Package runs
test_assert_success "my-package --version"

# Test: Package outputs expected version
test_assert_equals "1.0.0" "$(my-package --version)"
EOF
chmod +x packages/custom/my-package/test.sh
```

### Adding Patches

1. Create patch file:
```bash
# Create patch from changes
diff -u original.c modified.c > packages/my-package/patches/fix-bug.patch
```

2. Patches are automatically applied during build.

## Creating Installation Media

### ISO Image

```bash
# Create bootable ISO
./mkbs/mkbs image --format=iso --output=moonos.iso
```

### Raw Disk Image

```bash
# Create raw disk image
./mkbs/mkbs image --format=raw --output=moonos.img --size=4G
```

### USB Image

```bash
# Create USB image
./mkbs/mkbs image --format=raw --output=moonos-usb.img --size=2G
```

## Cleaning Up

### Clean Build Artifacts

```bash
# Clean specific package
./mkbs/mkbs clean --package musl

# Clean all build artifacts
./mkbs/mkbs clean --all
```

### Clean Cache

```bash
# Remove downloaded sources
rm -rf cache/*
```

## Debugging

### Verbose Output

```bash
# Enable verbose output
./mkbs/mkbs build package --verbose

# Enable debug output
./mkbs/mkbs build package --debug
```

### Build Logs

Build logs are stored in:
```
build/<target>/<package>/
```

### Common Issues

#### Build Fails

1. Check build log
2. Verify dependencies
3. Check for missing tools
4. Review PKGBUILD

#### Package Not Found

1. Check package name
2. Verify package exists in repository
3. Check package dependencies

## Advanced Topics

### Cross-Compilation

```bash
# Configure for cross-compilation
./mkbs/mkbs configure --target=aarch64

# Build with cross-compilation
./mkbs/mkbs build base
```

### Custom Toolchain

```bash
# Use custom compiler
./mkbs/mkbs configure --compiler=clang

# Use custom linker
./mkbs/mkbs configure --linker=mold
```

### Reproducible Builds

MoonOS supports reproducible builds:

```bash
# Build with reproducible output
./mkbs/mkbs build base --reproducible
```

## Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines on contributing to MoonOS.
