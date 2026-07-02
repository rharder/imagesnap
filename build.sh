#!/bin/bash

# ImageSnap Build Script
# Command-line build tool for the ImageSnap Swift project
# Usage: ./build.sh [command] [options]

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="imagesnap"
XCODE_PROJECT="${SCRIPT_DIR}/ImageSnap.xcodeproj"
SOURCE_FILE="${SCRIPT_DIR}/main.swift"
BUILD_DIR="${SCRIPT_DIR}/build"
RELEASE_DIR="${BUILD_DIR}/Release"
INSTALL_PREFIX="/usr/local"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Frameworks required
FRAMEWORKS=("AVFoundation" "AppKit" "CoreImage")

#######################################
# Helper Functions
#######################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

usage() {
    cat << EOF
Usage: $(basename "$0") [command] [options]

Commands:
  build           Build the project (default: Release)
  build:debug     Build in Debug configuration
  build:release   Build in Release configuration
  clean           Clean build artifacts
  install         Build and install to ${INSTALL_PREFIX}/bin
  uninstall       Remove installed binary
  test            Run the built binary with basic test
  direct          Build directly with swiftc (no Xcode)
  list-devices    List available video devices (requires built binary)

Options:
  -h, --help      Show this help message
  -v, --verbose   Verbose output
  -d, --debug     Build in Debug configuration
  -r, --release   Build in Release configuration

Examples:
  $(basename "$0") build                    # Build Release
  $(basename "$0") build:debug             # Build Debug
  $(basename "$0") install                  # Build and install
  $(basename "$0") clean                    # Clean all build artifacts
  $(basename "$0") direct                   # Build with swiftc directly

Environment Variables:
  INSTALL_PREFIX  Change install location (default: /usr/local)
  BUILD_DIR       Change build directory (default: ./build)
EOF
}

check_dependencies() {
    log_info "Checking dependencies..."
    
    # Check for Xcode command line tools
    if ! xcode-select -p >/dev/null 2>&1; then
        log_error "Xcode command line tools not installed."
        log_error "Run: xcode-select --install"
        exit 1
    fi
    
    # Check for swiftc
    if ! command -v swiftc >/dev/null 2>&1; then
        log_error "Swift compiler not found."
        log_error "Install Xcode or Swift toolchain."
        exit 1
    fi
    
    log_success "Dependencies OK"
}

check_xcode_project() {
    if [ ! -d "${XCODE_PROJECT}" ]; then
        log_error "Xcode project '${XCODE_PROJECT}' not found in ${SCRIPT_DIR}"
        exit 1
    fi
}

#######################################
# Build Functions
#######################################

build_with_xcodebuild() {
    local config="${1:-Release}"
    local build_dir="${BUILD_DIR}/xcodebuild"
    
    log_info "Building with xcodebuild (${config} configuration)..."
    
    mkdir -p "${build_dir}"
    mkdir -p "${BUILD_DIR}/Release"
    mkdir -p "${BUILD_DIR}/Intermediates"
    
    # Mark build directory as created by build system to allow xcodebuild to clean it
    xattr -w com.apple.xcode.CreatedByBuildSystem true "${BUILD_DIR}" 2>/dev/null || true
    
    xcodebuild \
        -project "${XCODE_PROJECT}" \
        -scheme "${PROJECT_NAME}" \
        -configuration "${config}" \
        -derivedDataPath "${build_dir}" \
        SYMROOT="${BUILD_DIR}" \
        OBJROOT="${BUILD_DIR}/Intermediates" \
        build
    
    # Find the built binary
    local binary_path="${BUILD_DIR}/${config}/${PROJECT_NAME}"
    if [ -f "${binary_path}" ]; then
        log_success "Built: ${binary_path}"
        return 0
    fi
    
    # Try alternative locations
    binary_path=$(find "${build_dir}" -name "${PROJECT_NAME}" -type f -perm +001 2>/dev/null | head -1)
    if [ -f "${binary_path}" ]; then
        log_success "Built: ${binary_path}"
        return 0
    fi
    
    # Also search the entire build directory
    binary_path=$(find "${BUILD_DIR}" -name "${PROJECT_NAME}" -type f -perm +001 2>/dev/null | head -1)
    if [ -f "${binary_path}" ]; then
        log_success "Built: ${binary_path}"
        return 0
    fi
    
    log_error "Could not find built binary in ${build_dir}"
    return 1
}

build_with_swiftc() {
    local config="${1:-Release}"
    local output_dir="${BUILD_DIR}/swiftc/${config}"
    local binary_path="${output_dir}/${PROJECT_NAME}"
    
    log_info "Building with swiftc (${config} configuration)..."
    
    mkdir -p "${output_dir}"
    
    local swiftc_flags=(
        "-o" "${binary_path}"
        "${SOURCE_FILE}"
    )
    
    # Add optimization based on configuration
    if [ "${config}" = "Release" ]; then
        swiftc_flags+=("-O" "-DNDEBUG")
    else
        swiftc_flags+=("-Onone" "-g")
    fi
    
    # Add frameworks
    for framework in "${FRAMEWORKS[@]}"; do
        swiftc_flags+=("-framework" "${framework}")
    done
    
    log_info "Running: swiftc ${swiftc_flags[*]}"
    swiftc "${swiftc_flags[@]}"
    
    if [ -f "${binary_path}" ]; then
        log_success "Built: ${binary_path}"
        return 0
    fi
    
    log_error "swiftc build failed"
    return 1
}

clean_build() {
    log_info "Cleaning build artifacts..."
    
    # Remove Xcode derived data
    rm -rf "${BUILD_DIR}/xcodebuild"
    rm -rf "${BUILD_DIR}/Release"
    rm -rf "${BUILD_DIR}/Debug"
    rm -rf "${BUILD_DIR}/Intermediates"
    
    # Remove swiftc builds
    rm -rf "${BUILD_DIR}/swiftc"
    
    # Remove Xcode user data
    rm -rf "${SCRIPT_DIR}/*.xcodeproj/*/xcuserdata"
    
    # Remove DS_Store files in build dir
    find "${BUILD_DIR}" -name ".DS_Store" -delete 2>/dev/null || true
    
    log_success "Cleaned build directory"
}

install_binary() {
    local config="${1:-Release}"
    local source_binary=""
    
    # Try to find the most recent build
    if [ -f "${RELEASE_DIR}/${PROJECT_NAME}" ]; then
        source_binary="${RELEASE_DIR}/${PROJECT_NAME}"
    else
        # Search for any built binary
        source_binary=$(find "${BUILD_DIR}" -name "${PROJECT_NAME}" -type f -perm +001 2>/dev/null | head -1)
    fi
    
    if [ -z "${source_binary}" ] || [ ! -f "${source_binary}" ]; then
        log_error "No built binary found. Run 'build' first."
        return 1
    fi
    
    local install_path="${INSTALL_PREFIX}/bin/${PROJECT_NAME}"
    
    log_info "Installing ${source_binary} to ${install_path}"
    
    # Create install directory if needed
    if [ ! -d "${INSTALL_PREFIX}/bin" ]; then
        log_info "Creating directory: ${INSTALL_PREFIX}/bin"
        mkdir -p "${INSTALL_PREFIX}/bin"
    fi
    
    # Copy binary
    cp "${source_binary}" "${install_path}"
    
    # Set executable permissions
    chmod +x "${install_path}"
    
    log_success "Installed: ${install_path}"
    
    # Check if we need sudo for system directories
    if [ -w "${INSTALL_PREFIX}/bin" ]; then
        log_info "Installation directory is writable by current user"
    else
        log_warning "You may need sudo to install to ${INSTALL_PREFIX}/bin"
        log_warning "Re-run with: sudo $(basename "$0") install"
    fi
}

uninstall_binary() {
    local install_path="${INSTALL_PREFIX}/bin/${PROJECT_NAME}"
    
    if [ -f "${install_path}" ]; then
        log_info "Removing ${install_path}"
        rm "${install_path}"
        log_success "Uninstalled ${PROJECT_NAME}"
    else
        log_info "${install_path} not found. Already uninstalled?"
    fi
}

test_binary() {
    local binary_path="${RELEASE_DIR}/${PROJECT_NAME}"
    
    if [ ! -f "${binary_path}" ]; then
        # Try to find any built binary
        binary_path=$(find "${BUILD_DIR}" -name "${PROJECT_NAME}" -type f -perm +001 2>/dev/null | head -1)
    fi
    
    if [ -z "${binary_path}" ] || [ ! -f "${binary_path}" ]; then
        log_error "No built binary found. Run 'build' first."
        return 1
    fi
    
    log_info "Running test with: ${binary_path}"
    
    # Test: Show help
    log_info "Testing help flag..."
    "${binary_path}" -h
    
    # Test: List devices
    log_info "Testing device listing..."
    "${binary_path}" -l
    
    log_success "Tests completed"
}

list_devices() {
    local binary_path="${RELEASE_DIR}/${PROJECT_NAME}"
    
    if [ ! -f "${binary_path}" ]; then
        binary_path=$(find "${BUILD_DIR}" -name "${PROJECT_NAME}" -type f -perm +001 2>/dev/null | head -1)
    fi
    
    if [ -z "${binary_path}" ] || [ ! -f "${binary_path}" ]; then
        log_error "No built binary found. Run 'build' first."
        return 1
    fi
    
    log_info "Available video devices:"
    "${binary_path}" -l
}

#######################################
# Main
#######################################

main() {
    # Parse command
    local command="${1:-build}"
    local config="Release"
    
    case "${command}" in
        -h|--help)
            usage
            exit 0
            ;;
        -v|--verbose)
            set -x
            command="${2:-build}"
            ;;
        build:debug|build:release)
            local tmp_config="${command#build:}"
            # Capitalize first letter (bash 3.2 compatible)
            config="$(echo "${tmp_config:0:1}" | tr '[:lower:]' '[:upper:]')${tmp_config:1}"
            command="build"
            ;;
        build)
            # Check for config flags
            if [[ "${2:-}" == "-d" || "${2:-}" == "--debug" ]]; then
                config="Debug"
            elif [[ "${2:-}" == "-r" || "${2:-}" == "--release" ]]; then
                config="Release"
            fi
            ;;
    esac
    
    # Check dependencies
    check_dependencies
    
    # Check project exists
    check_xcode_project
    
    case "${command}" in
        build)
            log_info "Building ${PROJECT_NAME} (${config} configuration)..."
            build_with_xcodebuild "${config}"
            ;;
        direct)
            build_with_swiftc "${config}"
            ;;
        clean)
            clean_build
            ;;
        install)
            build_with_xcodebuild "Release"
            install_binary
            ;;
        uninstall)
            uninstall_binary
            ;;
        test)
            test_binary
            ;;
        list-devices)
            list_devices
            ;;
        *)
            log_error "Unknown command: ${command}"
            echo ""
            usage
            exit 1
            ;;
    esac
}

# Run main with all arguments
main "$@"
