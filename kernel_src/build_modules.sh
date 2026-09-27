#!/bin/bash
# ============================================================
# Build USB Ethernet Kernel Modules for Samsung Galaxy M32 5G
# SM-M326B / MT6853 / Kernel 4.14.186-27095505 / aarch64
#
# REQUIREMENTS:
#   - Linux host (Ubuntu 20.04+ recommended)
#   - Android NDK r23+ OR ARM64 cross-compiler
#   - Samsung kernel source for SM-M326B
#
# USAGE:
#   chmod +x build_modules.sh
#   ./build_modules.sh [--download-source] [--build] [--package]
# ============================================================

set -e

# ── Configuration ────────────────────────────────────────────
KERNEL_VER="4.14.186-27095505"
DEVICE="SM-M326B"
ARCH="arm64"
CROSS_COMPILE="aarch64-linux-android-"
JOBS=$(nproc)

# Kernel source - download from Samsung Open Source
KERNEL_SRC_DIR="./kernel_source"
KERNEL_SRC_URL="https://opensource.samsung.com/uploadSearch?searchValue=SM-M326B"

# NDK path - adjust to your NDK location
NDK_PATH="${ANDROID_NDK_HOME:-$HOME/android-ndk-r25c}"
TOOLCHAIN="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64"
CLANG="$TOOLCHAIN/bin/clang"

# Output
OUT_DIR="./out_modules"
MODULE_DIR="../magisk_ethernet/system/lib/modules"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERR]${NC} $*"; exit 1; }

# ── Check tools ──────────────────────────────────────────────
check_deps() {
    info "Checking build dependencies..."
    for tool in make git wget unzip aarch64-linux-gnu-gcc; do
        if ! command -v $tool &>/dev/null; then
            warn "Missing: $tool"
            echo "Install with: sudo apt-get install build-essential gcc-aarch64-linux-gnu git wget"
        fi
    done
}

# ── Download Kernel Source ───────────────────────────────────
download_source() {
    info "Samsung kernel source for SM-M326B / MT6853"
    info "Download URL: https://opensource.samsung.com/uploadSearch?searchValue=SM-M326B"
    echo ""
    echo "Steps:"
    echo "  1. Go to: https://opensource.samsung.com"
    echo "  2. Search: SM-M326B"
    echo "  3. Download the kernel source .zip"
    echo "  4. Extract to: $KERNEL_SRC_DIR"
    echo ""
    
    # Also check GitHub for community kernel source
    info "Checking GitHub for community kernel source..."
    GITHUB_REPOS=(
        "https://github.com/samsung-mt6853/android_kernel_samsung_mt6853"
        "https://github.com/LineageOS/android_kernel_samsung_mt6853"
        "https://github.com/MoKee/android_kernel_samsung_a32x"
    )
    for repo in "${GITHUB_REPOS[@]}"; do
        echo "  Try: git clone --depth=1 $repo $KERNEL_SRC_DIR"
    done
    
    if [ ! -d "$KERNEL_SRC_DIR" ]; then
        warn "Kernel source not found at $KERNEL_SRC_DIR"
        warn "Please download it manually and re-run with --build"
        exit 1
    fi
}

# ── Setup kernel for external module build ───────────────────
prepare_kernel() {
    info "Preparing kernel for module build..."
    
    cd "$KERNEL_SRC_DIR"
    
    # Apply Samsung defconfig for a32x
    if [ -f "arch/arm64/configs/a32x_defconfig" ]; then
        make ARCH=arm64 a32x_defconfig
    elif [ -f "arch/arm64/configs/mt6853_defconfig" ]; then
        make ARCH=arm64 mt6853_defconfig
    else
        # Use a generic config and enable our modules
        make ARCH=arm64 defconfig
    fi
    
    # Enable the missing ethernet drivers as modules
    cat >> .config << 'EOF'
# USB Ethernet drivers - enable as modules
CONFIG_USB_LAN78XX=m
CONFIG_USB_NET_DM9601=m
CONFIG_USB_NET_SR9700=m
CONFIG_USB_NET_SR9800=m
CONFIG_USB_NET_MCS7830=m
# Already built-in but keeping for reference:
# CONFIG_USB_USBNET=y
# CONFIG_USB_RTL8152=y
# CONFIG_USB_RTL8150=y
# CONFIG_USB_NET_AX8817X=y
# CONFIG_USB_NET_AX88179_178A=y
# CONFIG_USB_NET_CDCETHER=y
# CONFIG_USB_NET_CDC_NCM=y
# CONFIG_USB_NET_CDC_EEM=y
# CONFIG_USB_NET_SMSC75XX=y
# CONFIG_USB_NET_SMSC95XX=y
EOF
    
    make ARCH=arm64 olddefconfig
    
    # Build kernel (to generate Module.symvers)
    info "Building kernel (this takes ~30 mins)..."
    make ARCH=arm64 \
         CROSS_COMPILE="aarch64-linux-gnu-" \
         CC="${CLANG:-aarch64-linux-gnu-gcc}" \
         -j"$JOBS" \
         Image.gz 2>&1 | tail -20
    
    success "Kernel prepared"
    cd - > /dev/null
}

# ── Build missing .ko modules ────────────────────────────────
build_modules() {
    info "Building USB ethernet modules..."
    mkdir -p "$OUT_DIR"
    
    MAKE_ARGS=(
        ARCH=arm64
        CROSS_COMPILE="aarch64-linux-gnu-"
        M="$PWD/module_src"
        -C "$KERNEL_SRC_DIR"
        modules
    )
    
    # Build each missing module
    for mod in lan78xx dm9601 sr9700 sr9800 mcs7830; do
        info "Building $mod.ko..."
        
        # Create temp module_src directory
        mkdir -p module_src
        
        # Copy driver source from kernel tree
        case $mod in
            lan78xx)  src="drivers/net/usb/lan78xx.c" ;;
            dm9601)   src="drivers/net/usb/dm9601.c" ;;
            sr9700)   src="drivers/net/usb/sr9700.c" ;;
            sr9800)   src="drivers/net/usb/sr9800.c" ;;
            mcs7830)  src="drivers/net/usb/mcs7830.c" ;;
        esac
        
        if [ -f "$KERNEL_SRC_DIR/$src" ]; then
            cp "$KERNEL_SRC_DIR/$src" "module_src/${mod}.c"
            # Write Makefile
            echo "obj-m := ${mod}.o" > module_src/Makefile
            
            make "${MAKE_ARGS[@]}" 2>&1
            
            if [ -f "module_src/${mod}.ko" ]; then
                # Strip debug symbols to reduce size
                aarch64-linux-gnu-strip --strip-debug "module_src/${mod}.ko" 2>/dev/null || true
                cp "module_src/${mod}.ko" "$OUT_DIR/"
                cp "$OUT_DIR/${mod}.ko" "$MODULE_DIR/"
                success "$mod.ko built and copied!"
            else
                warn "$mod.ko build failed"
            fi
        else
            warn "Source not found: $KERNEL_SRC_DIR/$src"
        fi
        
        rm -rf module_src/
    done
}

# ── Build AQC111 (external driver, not in kernel tree) ───────
build_aqc111() {
    info "Building aqc111.ko (Aquantia AQC111 2.5GbE)..."
    
    AQC_DIR="./aqc111_src"
    
    if [ ! -d "$AQC_DIR" ]; then
        git clone --depth=1 \
            https://github.com/chenhaiq/AQtion-usb-linux \
            "$AQC_DIR" 2>/dev/null || \
        git clone --depth=1 \
            https://github.com/Aquantia/AQtion-usb \
            "$AQC_DIR" 2>/dev/null || {
            warn "Could not download AQC111 source. Skipping."
            return
        }
    fi
    
    make -C "$AQC_DIR" \
        KERNELDIR="$KERNEL_SRC_DIR" \
        ARCH=arm64 \
        CROSS_COMPILE="aarch64-linux-gnu-" \
        KBUILD_EXTRA_SYMBOLS="$KERNEL_SRC_DIR/Module.symvers" \
        2>&1
    
    if [ -f "$AQC_DIR/aqc111.ko" ]; then
        cp "$AQC_DIR/aqc111.ko" "$OUT_DIR/"
        cp "$OUT_DIR/aqc111.ko" "$MODULE_DIR/"
        success "aqc111.ko built!"
    else
        warn "aqc111.ko build failed"
    fi
}

# ── Package into Magisk zip ──────────────────────────────────
package_module() {
    info "Packaging Magisk module..."
    cd ..
    
    # Remove old zip
    rm -f "samsung_usbeth_drivers.zip"
    
    # Create zip
    cd magisk_ethernet
    zip -r9 "../samsung_usbeth_drivers.zip" . \
        -x "*.DS_Store" \
        -x "__MACOSX/*" \
        -x "*.git/*" \
        2>/dev/null
    cd ..
    
    if [ -f "samsung_usbeth_drivers.zip" ]; then
        SIZE=$(du -sh "samsung_usbeth_drivers.zip" | cut -f1)
        success "Module packaged: samsung_usbeth_drivers.zip ($SIZE)"
        echo ""
        echo "  Install via Magisk Manager:"
        echo "  1. Open Magisk"
        echo "  2. Modules → Install from storage"
        echo "  3. Select samsung_usbeth_drivers.zip"
        echo "  4. Reboot"
    fi
}

# ── Main ─────────────────────────────────────────────────────
case "${1:-}" in
    --download-source) check_deps; download_source ;;
    --prepare-kernel)  prepare_kernel ;;
    --build)           build_modules; build_aqc111 ;;
    --package)         package_module ;;
    --all)             check_deps; download_source; prepare_kernel; build_modules; build_aqc111; package_module ;;
    *)
        echo "Usage: $0 [--download-source | --prepare-kernel | --build | --package | --all]"
        echo ""
        echo "  --download-source  Show how to get Samsung kernel source"
        echo "  --prepare-kernel   Configure kernel for module building"
        echo "  --build            Compile missing .ko modules"
        echo "  --package          Package everything into Magisk zip"
        echo "  --all              Run all steps in order"
        echo ""
        echo "Kernel vermagic required:"
        echo "  4.14.186-27095505 SMP preempt mod_unload modversions aarch64"
        ;;
esac
