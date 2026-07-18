# MoonOS Architecture Guide

## Overview

MoonOS is a production-ready, modular Linux distribution built from source. It follows a layered architecture where every component is replaceable and version-controlled.

## System Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    User Space                           │
├─────────────────────────────────────────────────────────┤
│  Desktop Environment  │  Server Applications           │
│  (GNOME/KDE/Sway)     │  (Nginx/PostgreSQL/etc.)       │
├─────────────────────────────────────────────────────────┤
│              System Libraries                           │
│  (musl, ncurses, openssl, zlib, etc.)                   │
├─────────────────────────────────────────────────────────┤
│              Core Utilities                              │
│  (coreutils, bash, util-linux, etc.)                    │
├─────────────────────────────────────────────────────────┤
│              Init System                                │
│  (OpenRC/runit/s6-rc)                                   │
├─────────────────────────────────────────────────────────┤
│              Linux Kernel                               │
│  (6.7.x LTS with MoonOS patches)                       │
├─────────────────────────────────────────────────────────┤
│              Hardware Abstraction                       │
│  (BIOS/UEFI, Device Drivers)                           │
└─────────────────────────────────────────────────────────┘
```

## Build System (MKBS)

MKBS (Moon Kit Build System) is the core build system for MoonOS. It handles:

- **Package Building**: Automated compilation from source
- **Dependency Management**: Automatic dependency resolution
- **Cross-Compilation**: Multi-architecture support
- **Reproducible Builds**: Deterministic output
- **Incremental Builds**: Build only what changed

### Build Pipeline

```
Source Code → Fetch → Verify → Extract → Patch → Configure → Build → Package → Install
     │           │        │         │        │         │          │         │         │
     │           │        │         │        │         │          │         │         │
     ▼           ▼        ▼         ▼        ▼         ▼          ▼         ▼         ▼
   Download   SHA256    tar/      Apply    ./conf    make       Create    Copy to
              Check     unzip     patches  ige       -jN       .pkg.tar  sysroot
```

### Package Structure

Each package in `packages/<category>/<name>/` contains:

```
package/
├── PKGBUILD          # Build script and metadata
├── patches/          # Optional patch files
├── files/            # Optional additional files
└── test.sh           # Optional test script
```

### PKGBUILD Format

```bash
pkg_name="package-name"
pkg_version="1.0.0"
pkg_release="1"
pkg_description="Package description"
pkg_url="https://example.com"
pkg_license="MIT"
pkg_arch="x86_64 aarch64"
pkg_depends=("dependency1" "dependency2")
pkg_build_depends=("build-dependency")

pkg_source=("https://example.com/source.tar.gz")
pkg_sha256=("checksum_here")

pkg_configure() {
    ./configure --prefix=/usr
}

pkg_compile() {
    make -j$(nproc)
}

pkg_install() {
    make DESTDIR="${PKG_INSTALL_DIR}" install
}
```

## Package Categories

### Base System (`packages/base/`)

Essential packages for a minimal system:

- **musl**: C library
- **busybox**: Minimal utilities
- **coreutils**: GNU core utilities
- **bash**: Shell
- **linux**: Kernel
- **openrc**: Init system
- **util-linux**: System utilities

### Development (`packages/development/`)

Development tools and libraries:

- **gcc**: Compiler collection
- **binutils**: Binary utilities
- **make**: Build tool
- **gdb**: Debugger
- **cmake/meson**: Build systems

### Desktop (`packages/desktop/`)

Desktop environment packages:

- **xorg-server**: X11 server
- **mesa**: Graphics drivers
- **gnome-shell**: Desktop environment
- **firefox**: Web browser

### Server (`packages/server/`)

Server applications:

- **nginx**: Web server
- **postgresql**: Database
- **openssh**: SSH server
- **docker-ce**: Container runtime

## Boot Process

```
BIOS/UEFI → GRUB → Linux Kernel → initramfs → Switch Root → Init (OpenRC) → System
```

### Boot Stages

1. **BIOS/UEFI**: Hardware initialization
2. **GRUB**: Bootloader
3. **Linux Kernel**: Kernel loading
4. **initramfs**: Temporary root filesystem
5. **Switch Root**: Transition to real root
6. **Init (OpenRC)**: Service management
7. **System**: Full system running

## Security Features

### Built-in Security

- **Stack Protection**: `-fstack-protector-strong`
- **PIE**: Position Independent Executables
- **RELRO**: Read-Only Relocations
- **FORTIFY_SOURCE**: Buffer overflow detection
- **ASLR**: Address Space Layout Randomization

### Kernel Security

- **SELinux**: Mandatory Access Control
- **Seccomp**: System Call Filtering
- **Capabilities**: Fine-grained Privileges
- **Namespaces**: Process Isolation
- **Cgroups**: Resource Limits

## Cross-Compilation

MoonOS supports cross-compilation for multiple architectures:

| Target | Arch | Libc | Status |
|--------|------|------|--------|
| x86_64 | x86_64 | musl | Supported |
| aarch64 | aarch64 | musl | Supported |
| armv7l | arm | musl | Supported |
| riscv64 | riscv64 | musl | Experimental |

## Release Engineering

### Versioning

MoonOS uses semantic versioning:

```
MAJOR.MINOR.PATCH
```

- **MAJOR**: Breaking changes
- **MINOR**: New features
- **PATCH**: Bug fixes

### Release Process

1. Code freeze on develop branch
2. Create release branch
3. Run full test suite
4. Build all packages
5. Create installation media
6. Security audit
7. Release to main branch
8. Tag release

### Release Schedule

- **Major releases**: Every 6 months
- **Minor releases**: Every 2 months
- **Security updates**: As needed
