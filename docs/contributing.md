# Contributing to MoonOS

Thank you for your interest in contributing to MoonOS! This document provides guidelines and information for contributors.

## Table of Contents

- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Code Style](#code-style)
- [Testing](#testing)
- [Pull Requests](#pull-requests)
- [Reporting Issues](#reporting-issues)

## Getting Started

### Prerequisites

Before contributing, ensure you have:

- Linux system (Debian/Ubuntu recommended)
- Git
- Build tools (gcc, make, etc.)
- QEMU (for testing)

### Fork and Clone

```bash
# Fork the repository on GitHub

# Clone your fork
git clone https://github.com/your-username/moonos.git
cd moonos

# Add upstream remote
git remote add upstream https://github.com/moonos/moonos.git

# Create a feature branch
git checkout -b feature/my-feature
```

## Development Setup

### Install Dependencies

```bash
# Debian/Ubuntu
sudo apt-get install -y \
    build-essential \
    git \
    curl \
    wget \
    qemu-user-static \
    binfmt-support

# Fedora
sudo dnf install -y \
    gcc \
    gcc-c++ \
    make \
    git \
    curl \
    wget \
    qemu-user-static
```

### Configure Build

```bash
# Configure for development
./mkbs/mkbs configure --target=x86_64 --profile=base
```

### Build Packages

```bash
# Build a specific package
./mkbs/mkbs build package-name

# Build with verbose output
./mkbs/mkbs build package-name --verbose
```

## Code Style

### Shell Scripts

- Use 4 spaces for indentation
- Use `set -euo pipefail` at the start of scripts
- Quote all variables
- Use `[[ ]]` instead of `[ ]`
- Use `$(command)` instead of backticks

```bash
#!/bin/bash
set -euo pipefail

# Good
if [[ -f "$file" ]]; then
    echo "File exists: $file"
fi

# Bad
if [ -f $file ]; then
    echo "File exists: $file"
fi
```

### PKGBUILD

- Use 4 spaces for indentation
- Quote all variables
- Use `pkg_*` naming convention
- Document all functions

```bash
pkg_name="my-package"
pkg_version="1.0.0"
pkg_release="1"
pkg_description="Package description"
pkg_url="https://example.com"
pkg_license="MIT"
pkg_arch="x86_64"
pkg_depends=("musl")
pkg_build_depends=()

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

### C Code

- Follow Linux kernel coding style
- Use tabs for indentation (8 spaces)
- Keep functions short and focused
- Document all public functions

## Testing

### Running Tests

```bash
# Run all tests
./tests/test_runner.sh

# Run specific test suite
./tests/test_runner.sh --suite=unit

# Run with verbose output
./tests/test_runner.sh --verbose
```

### Writing Tests

Create test files in `tests/` directory:

```bash
#!/bin/bash
# tests/unit/test_my_feature.sh

set -euo pipefail

source tests/test_runner.sh

# Test: Feature works correctly
test_my_feature() {
    local result
    result=$(my_command --option)

    test_assert_equals "expected" "$result" "Feature should return expected value"
}

# Run tests
test_my_feature
```

### Test Types

- **Unit Tests**: Test individual components
- **Integration Tests**: Test component interactions
- **System Tests**: Test complete system functionality
- **Security Tests**: Test security features

## Pull Requests

### Creating a Pull Request

1. Create a feature branch:
```bash
git checkout -b feature/my-feature
```

2. Make your changes

3. Commit with descriptive message:
```bash
git commit -m "Add new feature

- Description of changes
- Why the change was needed
- Any breaking changes"
```

4. Push to your fork:
```bash
git push origin feature/my-feature
```

5. Create pull request on GitHub

### PR Requirements

- [ ] Code follows style guidelines
- [ ] Tests pass
- [ ] Documentation updated
- [ ] No breaking changes (or documented)
- [ ] Commit messages are clear

### Review Process

1. Automated tests run
2. Code review by maintainers
3. Address feedback
4. Merge when approved

## Reporting Issues

### Bug Reports

When reporting bugs, include:

- Operating system and version
- MoonOS version
- Steps to reproduce
- Expected behavior
- Actual behavior
- Logs/screenshots

### Feature Requests

When requesting features, include:

- Description of the feature
- Use case
- Expected behavior
- Implementation ideas

### Security Issues

For security issues, please email security@moonos.org instead of opening an issue.

## Development Workflow

### Daily Development

```bash
# Pull latest changes
git pull upstream main

# Build and test
./mkbs/mkbs build base
./tests/test_runner.sh

# Commit changes
git add .
git commit -m "Description of changes"

# Push to fork
git push origin main
```

### Creating a Release

1. Update version numbers
2. Update changelog
3. Create release branch
4. Run full test suite
5. Create pull request
6. Merge and tag

## Getting Help

- **Documentation**: Check the `docs/` directory
- **Issues**: Open an issue on GitHub
- **Discussions**: Use GitHub Discussions
- **Chat**: Join our Matrix channel

## Code of Conduct

Please follow our [Code of Conduct](CODE_OF_CONDUCT.md) in all interactions.
