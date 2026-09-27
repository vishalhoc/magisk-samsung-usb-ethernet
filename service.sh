#!/system/bin/sh
# ============================================================
# Magisk Module service.sh
# Samsung USB Ethernet Drivers - SM-M326B
# AUTO-FIX: Renames usb0 → eth0 for Samsung EthernetManager
#
# ROOT CAUSE: Samsung EthernetManager only tracks eth\d+ interfaces.
# RTL8156 (r8152 driver) creates "usb0" instead of "eth0".
# Fix: rename usb0 → eth0 so Samsung auto-detects it.
# ============================================================

MODDIR="${0%/*}"
LOG="/data/local/tmp/usbeth.log"

log() { echo "[$(date '+%H:%M:%S')] [usbeth] $*" >> "$LOG"; }

# Wait for boot to complete
until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 2; done
sleep 3

log "=== USB Ethernet Service Starting ($(getprop ro.product.model)) ==="

# ── Load external .ko modules if any ───────────────────────
MODDIR_MODS="$MODDIR/system/lib/modules"
for ko in "$MODDIR_MODS"/*.ko; do
    [ -f "$ko" ] || continue
    name=$(basename "$ko" .ko)
    if ! grep -q "^${name} " /proc/modules 2>/dev/null; then
        insmod "$ko" 2>/dev/null && log "Loaded: $name" || log "Failed: $name"
    fi
done

# ── Function: fix interface name ────────────────────────────
fix_usb_eth_name() {
    local iface="$1"
    
    # Check if eth0 already exists (another adapter)
    if ip link show eth0 > /dev/null 2>&1; then
        # eth0 taken, try eth1
        local target="eth1"
    else
        local target="eth0"
    fi
    
    log "Renaming $iface → $target (Samsung EthernetManager fix)"
    ip link set "$iface" down 2>/dev/null
    ip link set "$iface" name "$target" 2>/dev/null
    ip link set "$target" up 2>/dev/null
    
    if ip link show "$target" > /dev/null 2>&1; then
        log "Renamed $iface → $target ✓"
        log "$target MAC: $(cat /sys/class/net/$target/address 2>/dev/null)"
        # Samsung EthernetManager will auto-detect eth0/eth1 and run DHCP
        # No manual DHCP needed!
    else
        log "Rename failed for $iface"
    fi
}

# ── USB Hotplug Monitor ─────────────────────────────────────
log "Starting USB ethernet hotplug monitor..."

(
    PREV=$(ls /sys/class/net/ 2>/dev/null | tr '\n' ' ')
    
    while true; do
        sleep 3
        CURR=$(ls /sys/class/net/ 2>/dev/null | tr '\n' ' ')
        
        if [ "$CURR" != "$PREV" ]; then
            # Find new interfaces
            for iface in $CURR; do
                case "$iface" in
                    usb[0-9]*)
                        # New usb interface appeared — RTL8152/RTL8156/ASIX etc
                        if ! echo "$PREV" | grep -q "$iface"; then
                            log "New USB ethernet interface: $iface"
                            sleep 2  # wait for driver init
                            fix_usb_eth_name "$iface"
                        fi
                        ;;
                    eth[0-9]*)
                        # eth interface appeared — already named correctly
                        if ! echo "$PREV" | grep -q "$iface"; then
                            log "New ethernet interface: $iface (already eth*)"
                            ip link set "$iface" up 2>/dev/null
                        fi
                        ;;
                esac
            done
            PREV="$CURR"
        fi
    done
) &

# ── Also fix any usb* interfaces already present at boot ────
for iface in $(ls /sys/class/net/ 2>/dev/null); do
    case "$iface" in
        usb[0-9]*)
            log "Found existing USB ethernet at boot: $iface"
            fix_usb_eth_name "$iface"
            ;;
    esac
done

log "=== USB Ethernet Service Ready ==="
