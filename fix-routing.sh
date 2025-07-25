#!/bin/bash

# Mihomo Routing Troubleshoot and Fix Script

echo "🔧 Mihomo Routing Troubleshoot & Fix Tool"
echo "=========================================="
echo ""

# Check current routing issues
echo "📊 Current Routing Analysis:"
echo "----------------------------"

echo "1. Default Routes:"
ip route show | grep default | nl

echo ""
echo "2. Interface Status:"
echo "   LAN (enp0s25):"
if ip link show enp0s25 >/dev/null 2>&1; then
    status=$(ip link show enp0s25 | grep -o "state [A-Z]*" | cut -d' ' -f2)
    ip_addr=$(ip addr show enp0s25 | grep "inet " | awk '{print $2}' | head -1)
    echo "     Status: $status"
    echo "     IP: $ip_addr"
    
    # Test gateway
    gateway=$(ip route show | grep "192.168.100.0/24" | grep "proto kernel" | awk '{print $1}' | sed 's|/24||').1
    echo "     Gateway: $gateway"
    ping_result=$(ping -c 1 -W 2 $gateway 2>/dev/null && echo "OK" || echo "FAILED")
    echo "     Gateway ping: $ping_result"
else
    echo "     Status: NOT FOUND"
fi

echo ""
echo "   USB Tethering (usb-tether):"
if ip link show usb-tether >/dev/null 2>&1; then
    status=$(ip link show usb-tether | grep -o "state [A-Z]*" | cut -d' ' -f2)
    ip_addr=$(ip addr show usb-tether | grep "inet " | awk '{print $2}' | head -1)
    echo "     Status: $status"
    echo "     IP: $ip_addr"
    
    # Get gateway from DHCP route
    gateway=$(ip route show | grep "usb-tether proto dhcp" | grep "via" | awk '{print $3}' | head -1)
    echo "     Gateway: $gateway"
    if [ -n "$gateway" ]; then
        ping_result=$(ping -c 1 -W 2 $gateway 2>/dev/null && echo "OK" || echo "FAILED")
        echo "     Gateway ping: $ping_result"
    fi
else
    echo "     Status: NOT FOUND"
fi

echo ""
echo "3. Mihomo TUN Interface:"
if ip link show Meta >/dev/null 2>&1; then
    status=$(ip link show Meta | grep -o "state [A-Z]*" | cut -d' ' -f2)
    ip_addr=$(ip addr show Meta | grep "inet " | awk '{print $2}' | head -1)
    echo "   Status: $status"
    echo "   IP: $ip_addr"
else
    echo "   Status: NOT FOUND"
fi

echo ""
echo "🔍 Routing Problems Detected:"
echo "-----------------------------"

# Check for incomplete default route
incomplete_routes=$(ip route show | grep "^default$" | wc -l)
if [ $incomplete_routes -gt 0 ]; then
    echo "❌ Found $incomplete_routes incomplete default route(s)"
fi

# Check for multiple default routes
default_count=$(ip route show | grep "^default" | wc -l)
echo "📊 Total default routes: $default_count"

# Check for load balancing route
lb_route=$(ip route show | grep "nexthop" | head -1)
if [ -n "$lb_route" ]; then
    echo "⚖️  Load balancing route found:"
    echo "   $lb_route"
    
    # Verify nexthop gateways
    echo ""
    echo "🔍 Verifying Load Balance Gateways:"
    echo "$lb_route" | grep -o "via [0-9.]*" | while read via_part; do
        gw=$(echo $via_part | cut -d' ' -f2)
        ping_result=$(ping -c 1 -W 2 $gw 2>/dev/null && echo "✅ $gw OK" || echo "❌ $gw FAILED")
        echo "   $ping_result"
    done
else
    echo "❌ No load balancing route found"
fi

echo ""
echo "🛠️  Suggested Fixes:"
echo "-------------------"

# Suggest fixes
if [ $incomplete_routes -gt 0 ]; then
    echo "1. Remove incomplete default routes:"
    echo "   sudo ip route del default"
fi

if [ $default_count -gt 2 ]; then
    echo "2. Too many default routes, consider cleaning up"
fi

# Check if Mihomo service is affecting routing
if systemctl is-active --quiet mihomo; then
    echo "3. Mihomo service is running - check if TUN interface is interfering"
    echo "   Consider restarting Mihomo: sudo systemctl restart mihomo"
fi

echo ""
echo "🔧 Auto-Fix Options:"
echo "-------------------"
read -p "Do you want to fix routing issues automatically? (y/n): " fix_choice

if [ "$fix_choice" = "y" ] || [ "$fix_choice" = "Y" ]; then
    echo ""
    echo "🔄 Applying fixes..."
    
    # Remove incomplete default routes
    echo "1. Removing incomplete default routes..."
    sudo ip route del default 2>/dev/null || true
    
    # Get gateway information
    lan_gw="192.168.100.1"
    usb_gw=$(ip route show | grep "usb-tether proto dhcp" | grep "via" | awk '{print $3}' | head -1)
    
    if [ -n "$usb_gw" ]; then
        echo "2. Setting up load balancing route..."
        sudo ip route add default \
            nexthop via $lan_gw dev enp0s25 weight 1 \
            nexthop via $usb_gw dev usb-tether weight 1
        
        echo "✅ Load balancing route configured"
        echo "   LAN Gateway: $lan_gw"
        echo "   USB Gateway: $usb_gw"
    else
        echo "❌ Could not determine USB gateway"
    fi
    
    echo ""
    echo "3. Testing connectivity..."
    echo "   Testing LAN interface:"
    ping -c 2 -I enp0s25 8.8.8.8 | tail -2
    
    echo "   Testing USB interface:"
    ping -c 2 -I usb-tether 8.8.8.8 | tail -2
    
    echo ""
    echo "✅ Routing fix completed!"
    
else
    echo "Skipping auto-fix."
fi

echo ""
echo "📋 Current Routes After Fix:"
echo "----------------------------"
ip route show | head -10

echo ""
echo "🎯 Testing Mihomo Proxies:"
echo "--------------------------"

# Test if we can reach Mihomo controller
if curl -s --connect-timeout 5 http://127.0.0.1:9090 >/dev/null 2>&1; then
    echo "✅ Mihomo controller accessible"
    
    # Test proxy endpoints if available
    if command -v curl >/dev/null 2>&1; then
        echo "🔍 Testing proxy connectivity through Mihomo..."
        
        # Test through different proxy groups
        echo "   Testing direct connections:"
        curl -s --connect-timeout 5 --proxy socks5://127.0.0.1:7891 http://httpbin.org/ip 2>/dev/null | grep -o '"origin": "[^"]*"' || echo "   ❌ SOCKS proxy test failed"
    fi
else
    echo "❌ Mihomo controller not accessible"
    echo "   Check if Mihomo is running: systemctl status mihomo"
fi

echo ""
echo "🎉 Troubleshooting completed!"
echo "Check the Network Interface Manager at: http://localhost:5020"