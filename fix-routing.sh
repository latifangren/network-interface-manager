#!/bin/bash

echo "🌐 Network Route Checker & Fixer"
echo "=================================="

# Interface
lan_if="enp0s25"
usb_if="usb-tether"
tun_if="Meta"

# Cek keberadaan interface
echo "🔍 Checking Interfaces..."
for if in "$lan_if" "$usb_if" "$tun_if"; do
    ip link show "$if" > /dev/null 2>&1
    if [[ $? -eq 0 ]]; then
        echo "   ✅ $if detected"
    else
        echo "   ❌ $if not found or down"
    fi
done

# Ambil gateway untuk LAN dan USB tether
lan_gw=$(ip route show dev "$lan_if" | awk '/default via/ {print $3; exit}')
usb_gw=$(ip route show dev "$usb_if" | awk '/default via/ {print $3; exit}')

echo -e "\n🔌 Gateways:"
echo "   LAN: $lan_gw"
echo "   USB: $usb_gw"

# Tes ping ke gateway
echo -e "\n📡 Pinging gateways..."
for gw in "$lan_gw" "$usb_gw"; do
    if [[ -n "$gw" ]]; then
        ping -c 1 -W 1 "$gw" > /dev/null
        [[ $? -eq 0 ]] && echo "   ✅ $gw reachable" || echo "   ⚠️  $gw unreachable"
    fi
done

# Hapus semua default route secara komprehensif
echo -e "\n🧹 Cleaning up existing default routes..."
# Hapus semua default route (termasuk yang dengan metric)
while sudo ip route del default 2>/dev/null; do
    echo "   Removed default route"
done

# Hapus default route dengan metric tertentu jika masih ada
sudo ip route del default metric 100 2>/dev/null || true
sudo ip route del default metric 200 2>/dev/null || true
sudo ip route del default metric 300 2>/dev/null || true

# Hapus default route dengan proto dhcp jika masih ada
sudo ip route del default proto dhcp 2>/dev/null || true

# Tambah nexthop default route jika keduanya aktif
if [[ -n "$lan_gw" && -n "$usb_gw" ]]; then
    echo "🛠️  Adding load-balanced default route via LAN + USB..."
    sudo ip route add default \
        nexthop via "$lan_gw" dev "$lan_if" weight 1 \
        nexthop via "$usb_gw" dev "$usb_if" weight 1
elif [[ -n "$lan_gw" ]]; then
    echo "🛠️  Adding default route via LAN only..."
    sudo ip route add default via "$lan_gw" dev "$lan_if"
elif [[ -n "$usb_gw" ]]; then
    echo "🛠️  Adding default route via USB only..."
    sudo ip route add default via "$usb_gw" dev "$usb_if"
else
    echo "❌ No gateway available for default route!"
    exit 1
fi

# Cek Mihomo (Meta) interface
if ip a | grep -q "$tun_if"; then
    echo -e "\n🌐 Checking Mihomo (Meta) Interface..."
    mihomo_ip=$(ip a show "$tun_if" | awk '/inet / {print $2}')
    echo "   ✅ $tun_if found with IP: $mihomo_ip"

    echo -e "   🔎 Testing SOCKS5 127.0.0.1:7891 via curl..."
    curl --socks5 127.0.0.1:7891 https://www.google.com -m 5 -s -o /dev/null && \
        echo "   ✅ SOCKS5 working" || echo "   ⚠️  SOCKS5 test failed"
else
    echo -e "\n⚠️  $tun_if interface not found"
fi

echo -e "\n✅ Routing fix completed.\n"
