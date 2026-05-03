#!/bin/bash
# ============================================================================
# Resurgam OS - i686-elf Cross Compiler Auto-Installer
# ============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Resurgam OS Cross Compiler Installer${NC}"
echo "====================================="
echo ""

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
elif type lsb_release >/dev/null 2>&1; then
    OS=$(lsb_release -si)
else
    OS=$(uname -s)
fi

echo "Detected OS: $OS"
echo ""

# Check if already installed
if command -v i686-elf-gcc &> /dev/null; then
    echo -e "${GREEN}i686-elf-gcc is already installed!${NC}"
    i686-elf-gcc --version | head -n 1
    exit 0
fi

# Function to install on Debian/Ubuntu
install_debian() {
    echo -e "${YELLOW}Installing dependencies...${NC}"
    sudo apt-get update
    sudo apt-get install -y build-essential bison flex libgmp3-dev libmpc-dev         libmpfr-dev texinfo nasm qemu-system-x86 xorriso grub-common

    echo -e "${YELLOW}Building cross compiler (this may take 30-60 minutes)...${NC}"

    export PREFIX="$HOME/opt/cross"
    export TARGET=i686-elf
    export PATH="$PREFIX/bin:$PATH"

    mkdir -p $PREFIX
    mkdir -p /tmp/cross-build
    cd /tmp/cross-build

    # Download sources
    echo "Downloading binutils..."
    wget -q https://ftp.gnu.org/gnu/binutils/binutils-2.40.tar.xz
    echo "Downloading gcc..."
    wget -q https://ftp.gnu.org/gnu/gcc/gcc-13.2.0/gcc-13.2.0.tar.xz

    # Build binutils
    echo "Building binutils..."
    tar -xf binutils-2.40.tar.xz
    mkdir build-binutils
    cd build-binutils
    ../binutils-2.40/configure --target=$TARGET --prefix="$PREFIX"         --with-sysroot --disable-nls --disable-werror
    make -j$(nproc)
    make install
    cd ..

    # Build GCC
    echo "Building GCC..."
    tar -xf gcc-13.2.0.tar.xz
    mkdir build-gcc
    cd build-gcc
    ../gcc-13.2.0/configure --target=$TARGET --prefix="$PREFIX"         --disable-nls --enable-languages=c,c++ --without-headers
    make -j$(nproc) all-gcc
    make -j$(nproc) all-target-libgcc
    make install-gcc
    make install-target-libgcc
    cd ..

    # Add to PATH
    if ! grep -q "$PREFIX/bin" ~/.bashrc; then
        echo "export PATH=\"$PREFIX/bin:\$PATH\"" >> ~/.bashrc
    fi

    echo -e "${GREEN}Installation complete!${NC}"
    echo "Please run: source ~/.bashrc"
}

# Function to install on Arch Linux
install_arch() {
    echo -e "${YELLOW}Installing from AUR...${NC}"
    if command -v yay &> /dev/null; then
        yay -S i686-elf-gcc i686-elf-binutils
    elif command -v paru &> /dev/null; then
        paru -S i686-elf-gcc i686-elf-binutils
    else
        echo -e "${RED}Please install yay or paru first${NC}"
        exit 1
    fi
}

# Function to install on macOS
install_macos() {
    echo -e "${YELLOW}Installing via Homebrew...${NC}"
    if ! command -v brew &> /dev/null; then
        echo -e "${RED}Please install Homebrew first: https://brew.sh${NC}"
        exit 1
    fi
    brew install i686-elf-gcc i686-elf-binutils
}

# Main installation logic
case $OS in
    *Ubuntu*|*Debian*|*Linux\ Mint*|*Pop!_OS*)
        install_debian
        ;;
    *Arch*|*Manjaro*)
        install_arch
        ;;
    *Darwin*|*Mac*)
        install_macos
        ;;
    *)
        echo -e "${RED}Unsupported OS: $OS${NC}"
        echo "Please install i686-elf-gcc manually:"
        echo "  https://wiki.osdev.org/GCC_Cross-Compiler"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}Done! You can now build Resurgam OS with 'make run'${NC}"
