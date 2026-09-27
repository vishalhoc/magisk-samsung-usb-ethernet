#!/system/bin/sh
# ============================================================
# USB Ethernet Setup Script - Samsung Galaxy M32 5G
# RTL8156 (0BDA:8156) via r8152 driver → usb0 interface
# Sets up ethernet tethering: Phone internet → usb0 → Laptop
# Confirmed working: 2026-09-19
# ============================================================

LOG="/data/local/tmp/usbeth.log"
PHONE_IP="192.168.42.1"
DHCP_START="192.168.42.2"
DHCP_END="192.168.42.254"
SUBNET="24"
DNS1="8.8.8.8"
DNS2="8.8.4.4"

log() { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG"; }
log "=== USB Ethernet Setup Start ==="

# ── Load external .ko modules (built-in ones load automatically) ──
load_module() {
    local name="$1"
    local path="$MODDIR/system/lib/modules/${name}.ko"
    
    # Skip if already loaded
    if grep -q "^${name} " /proc/modules 2>/dev/null; then
        log "$name: already loaded"
        return 0
    fi
    
    # Skip if built into kernel (=y)
    if zcat /proc/config.gz 2>/dev/null | grep -q "^CONFIG_.*=y" 2>/dev/null; then
        : # kernel handles it
    fi
    
    if [ -f "$path" ]; then
        insmod "$path" 2>/dev/null
        if [ $? -eq 0 ]; then
            log "$name: loaded OK"
        else
            log "$name: load FAILED"
        fi
    fi
}

# Load external modules (those NOT built into kernel)
load_module "lan78xx"
load_module "dm9601"
load_module "sr9700"
load_module "sr9800"
load_module "mcs7830"
load_module "aqc111"

# ── Wait for ethernet interface to appear ───────────────────
wait_for_eth() {
    local timeout=15
    local i=0
    while [ $i -lt $timeout ]; do
        ETH=$(ip link show 2>/dev/null | awk -F': ' '/^[0-9]+: eth|usb[0-9]|enp/{print $2; exit}')
        if [ -n "$ETH" ]; then
            log "Interface found: $ETH"
            echo "$ETH"
            return 0
        fi
        sleep 1
        i=$((i+1))
    done
    log "No ethernet interface found after ${timeout}s"
    return 1
}

# ── Configure interface ──────────────────────────────────────
setup_interface() {
    local iface="$1"
    
    log "Configuring $iface..."
    
    # Bring up interface
    ip link set "$iface" up 2>/dev/null
    log "$iface: link up"
    
    # Kill any existing dhcpcd/busybox dhcp on this interface
    kill $(cat /data/local/tmp/usbeth_dhcp.pid 2>/dev/null) 2>/dev/null
    
    # Try dhcpcd first (available on most Android)
    if command -v dhcpcd >/dev/null 2>&1; then
        dhcpcd -b -t 30 "$iface" &
        echo $! > /data/local/tmp/usbeth_dhcp.pid
        log "dhcpcd started on $iface (PID=$!)"
        
    # Fallback: busybox udhcpc
    elif command -v busybox >/dev/null 2>&1; then
        busybox udhcpc -i "$iface" -s /system/bin/usbeth_dhcp.sh -b -p /data/local/tmp/usbeth_dhcp.pid &
        log "udhcpc started on $iface"
        
    # Fallback: try ndc (Android network daemon client)
    else
        ndc network create 200 2>/dev/null
        ndc network interface add 200 "$iface" 2>/dev/null
        ndc interface setcfg "$iface" up 2>/dev/null
        log "ndc config applied to $iface"
    fi
    
    # Set DNS if DHCP doesn't
    sleep 3
    IP=$(ip -4 addr show "$iface" 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1)
    if [ -n "$IP" ]; then
        log "$iface got IP: $IP"
        
        # Route: add default via ethernet (optional — may override mobile data)
        GW=$(ip route show dev "$iface" 2>/dev/null | awk '/default/{print $3}')
        if [ -n "$GW" ]; then
            log "$iface gateway: $GW"
        fi
        
        # Notify Android
        am broadcast -a android.net.conn.CONNECTIVITY_CHANGE 2>/dev/null
        
        # Show notification
        /system/bin/usbeth_notify.sh "$iface" "$IP" 2>/dev/null &
    else
        log "$iface: no IP assigned"
    fi
}

# ── Main ────────────────────────────────────────────────────
ETH=$(wait_for_eth)
if [ -n "$ETH" ]; then
    setup_interface "$ETH"
else
    log "No USB ethernet adapter detected"
    log "Supported: RTL8152/8150, ASIX AX88179, CDC-Ethernet, SMSC, LAN78xx, DM9601"
fi

log "=== USB Ethernet Setup Done ==="
