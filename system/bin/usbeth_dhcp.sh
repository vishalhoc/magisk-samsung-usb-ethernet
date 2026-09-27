#!/system/bin/sh
# udhcpc / dhcpcd hook script for USB ethernet
# Called by busybox udhcpc when lease is obtained

case "$1" in
    bound|renew)
        ip addr flush dev "$interface" 2>/dev/null
        ip addr add "${ip}/${mask}" dev "$interface" 2>/dev/null
        [ -n "$router" ] && ip route add default via "$router" dev "$interface" metric 200 2>/dev/null
        
        # Set DNS
        if [ -n "$dns" ]; then
            for d in $dns; do
                echo "nameserver $d" >> /data/local/tmp/usbeth_resolv.conf
            done
            ndc resolver setnetdns 200 "" $dns 2>/dev/null
        fi
        
        echo "USB-ETH bound: if=$interface ip=$ip gw=$router dns=$dns" >> /data/local/tmp/usbeth.log
        ;;
    deconfig)
        ip addr flush dev "$interface" 2>/dev/null
        ;;
esac
