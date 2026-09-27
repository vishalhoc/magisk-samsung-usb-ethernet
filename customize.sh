#!/system/bin/sh
# ============================================================
# Magisk Module Installer - Samsung USB Ethernet Fix
# ============================================================

SKIPUNZIP=1

# Extract module files
unzip -o "$ZIPFILE" -x 'META-INF/*' -d "$MODPATH" >&2

# Set permissions
set_perm_recursive "$MODPATH" root root 0755 0644
set_perm "$MODPATH/service.sh" root root 0755
set_perm "$MODPATH/system/etc/permissions/android.hardware.ethernet.xml" root root 0644

ui_print ""
ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ui_print "  Samsung USB Ethernet Fix v1.0"
ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ui_print ""
ui_print "  ✓ Auto-rename: usb0 → eth0"
ui_print "  ✓ Samsung EthernetManager fix"
ui_print "  ✓ RTL8156 (Ausha adapter) support"
ui_print "  ✓ Ethernet tethering enabled"
ui_print "  ✓ USB hotplug monitor"
ui_print ""
ui_print "  Device:  $(getprop ro.product.model)"
ui_print "  Android: $(getprop ro.build.version.release)"
ui_print ""
ui_print "  After reboot: plug in USB ethernet"
ui_print "  adapter → Settings → Ethernet"
ui_print "  will show automatically!"
ui_print ""
ui_print "  Log: /data/local/tmp/usbeth.log"
ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
