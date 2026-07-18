# MoonOS Makefile
# Top-level build orchestration

MOONOS_ROOT := $(shell pwd)
MKBS := $(MOONOS_ROOT)/mkbs/mkbs

.PHONY: all help configure build clean test lint release

# Default target
all: build

# Show help
help:
	@echo "MoonOS Build System"
	@echo ""
	@echo "Targets:"
	@echo "  configure    - Configure build for target platform"
	@echo "  build        - Build packages or package groups"
	@echo "  clean        - Clean build artifacts"
	@echo "  test         - Run test suites"
	@echo "  lint         - Run linters on packages"
	@echo "  release      - Create release"
	@echo "  image        - Create installation image"
	@echo ""
	@echo "Examples:"
	@echo "  make configure TARGET=x86_64 PROFILE=base"
	@echo "  make build PACKAGE=musl"
	@echo "  make build GROUP=base"
	@echo "  make image FORMAT=iso"
	@echo ""

# Configure build
configure:
	$(MKBS) configure --target=$(TARGET) --profile=$(PROFILE)

# Build packages
build:
ifdef PACKAGE
	$(MKBS) build $(PACKAGE)
else ifdef GROUP
	$(MKBS) build $(GROUP)
else
	$(MKBS) build base
endif

# Build all packages
build-all:
	$(MKBS) build --all

# Clean build artifacts
clean:
	$(MKBS) clean --all

# Run tests
test:
	./tests/test_runner.sh $(ARGS)

# Run linters
lint:
	$(MKBS) lint --all

# Create installation image
image:
	$(MKBS) image --format=$(FORMAT) --output=$(OUTPUT)

# Create ISO image
iso:
	$(MKBS) image --format=iso --output=moonos.iso

# Create raw disk image
raw:
	$(MKBS) image --format=raw --output=moonos.img

# Run integration tests
test-integration:
	./tests/test_runner.sh --suite=integration

# Run system tests
test-system:
	./tests/test_runner.sh --suite=system

# Run security tests
test-security:
	./tests/test_runner.sh --suite=security

# Run all tests
test-all:
	./tests/test_runner.sh --all

# Update package checksums
update-checksums:
	$(MKBS) pkg update-checksums $(PACKAGE)

# Show package information
pkg-info:
	$(MKBS) pkg info $(PACKAGE)

# List all packages
pkg-list:
	$(MKBS) pkg list

# Create release
release:
	./release/release.sh $(VERSION)

# Generate documentation
docs:
	cd docs && make html

# Install dependencies (for Debian/Ubuntu)
deps-ubuntu:
	sudo apt-get update
	sudo apt-get install -y \
		build-essential \
		git \
		curl \
		wget \
		qemu-user-static \
		binfmt-support

# Install dependencies (for Fedora)
deps-fedora:
	sudo dnf install -y \
		gcc \
		gcc-c++ \
		make \
		git \
		curl \
		wget \
		qemu-user-static

# Show build configuration
config:
	@echo "Target:  $(TARGET)"
	@echo "Profile: $(PROFILE)"
	@echo "Jobs:    $(JOBS)"
