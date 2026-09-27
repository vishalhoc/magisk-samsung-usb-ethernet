# Samsung USB Ethernet Fix (RTL8156 / Realtek / ASIX)

[![Magisk](https://img.shields.io/badge/Magisk-v24.0+-brightgreen.svg)](https://github.com/topjohnwu/Magisk)
[![Android](https://img.shields.io/badge/Android-11%20|%2012%20|%2013-blue.svg)](https://developer.android.com)
[![Device](https://img.shields.io/badge/Samsung-Galaxy%20M32%205G-orange.svg)](https://www.samsung.com)

A systemless Magisk module that enables native **Ethernet Tethering** and wired network connectivity on Samsung One UI devices (tested on Samsung Galaxy M32 5G / SM-M326B Android 13) when using Realtek RTL8156 (2.5 Gbps), RTL8153, RTL8152, or ASIX USB-to-Ethernet adapters.

---

## 📌 Problem Description
On Samsung Galaxy devices running One UI (Android 11, 12, 13), when a USB Ethernet adapter is plugged into the USB-C port:
1. The Linux kernel assigns the network interface name `usb0` (via `cdc_ncm` or `r8152` driver).
2. Samsung's proprietary `EthernetManager` and `ConnectivityService` explicitly scan for network interfaces matching the regex `^eth[0-9]+`.
3. Because the adapter is named `usb0`, Android One UI ignores it, leaving the **Ethernet** setting grayed out or missing under *Settings > Connections > More connection settings > Ethernet*.
4. Furthermore, Ethernet tethering cannot be toggled because Android framework requires an active `eth0` interface.

---

## 🚀 Solution
This module installs a lightweight background monitor service (`service.sh` and helper scripts in `/system/bin/`):
- **Dynamic Interface Detection**: Monitors network link events via `ip monitor link` or udev netlink socket.
- **Interface Renaming**: When `usb0` is brought up, the daemon immediately brings the interface down, renames `usb0` to `eth0` using `ip link set usb0 name eth0`, and brings `eth0` back up.
- **Permission & Policy Fixes**: Includes custom SELinux rules (`sepolicy.rules`) and framework permissions (`android.hardware.ethernet.xml`) so Samsung framework processes can manage the interface without restriction.
- **DHCP Client & Routing**: Spawns Android's native DHCP client (`net.dns` & default gateway) to guarantee immediate Internet access upon cable insertion.

---

## 💻 Supported Chipsets
- **Realtek RTL8156 / RTL8156B / RTL8156BG** (USB 3.0 / 2.5 Gigabit Ethernet, VID:PID `0BDA:8156`)
- **Realtek RTL8153 / RTL8153B** (USB 3.0 / Gigabit Ethernet, VID:PID `0BDA:8153`)
- **Realtek RTL8152** (USB 2.0 / 100Mbps Ethernet, VID:PID `0BDA:8152`)
- **ASIX AX88179 / AX88179A** (USB 3.0 / Gigabit Ethernet)
- Standard CDC-NCM / CDC-ECM USB network interfaces

---

## 📦 Installation

### Method 1: Magisk App / KernelSU / APatch
1. Download the latest `Samsung_USB_Ethernet_Fix_v1.0.zip` from the Releases section.
2. Open the **Magisk** (or KernelSU / APatch) app on your rooted device.
3. Navigate to the **Modules** tab and tap **Install from storage**.
4. Select the `.zip` package and allow installation.
5. Reboot your device.

### Method 2: Manual Sideload via ADB
```bash
adb push Samsung_USB_Ethernet_Fix_v1.0.zip /data/local/tmp/
adb shell "su -c 'magisk --install-module /data/local/tmp/Samsung_USB_Ethernet_Fix_v1.0.zip'"
adb reboot
```

---

## 🔍 Verification

Connect your USB-to-Ethernet adapter to your phone via USB-C OTG and connect an active LAN cable. Run:

```bash
# Check if eth0 exists
adb shell ip addr show eth0

# Check routing table
adb shell ip route show

# Verify internet access over eth0
adb shell ping -I eth0 -c 4 8.8.8.8
```

Open **Settings > Connections > More connection settings**:
- The **Ethernet** toggle will now be available and active!

---

## 📜 License
Distributed under the MIT License. See `LICENSE` for details.
