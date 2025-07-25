#!/bin/bash

# Comprehensive Interface Connectivity Test for Mihomo Setup

echo "🧪 Mihomo Interface Connectivity Test"
echo "====================================="
echo ""

# Test routing health first
echo "🔍 Checking Routing Health:"
echo "---------------------------"

# Check for routing issues
default_routes=$(ip route show | grep "^default" | wc -l)
incomplete_routes=$(ip route show | grep "^default$" | wc -l)
lb_routes=$(ip route show | grep "nexthop" | wc -l)

echo "📊 Routing Status:"
echo "   Default routes: $default_routes"
echo "   Incomplete routes: $incomplete_routes"
echo "   Load balancing routes: $lb_routes"

if [ $incomplete_routes -gt 0 ]; then
    echo "   ❌ Found incomplete routing - needs fixing"
else
    echo "   ✅ Routing table looks good"
fi

echo ""
echo "🌐 Testing Interface Connectivity:"
echo "----------------------------------"

# Test LAN interface
echo "1. Testing LAN Interface (enp0s25):"
if ip link show enp0s25 >/dev/null 2>&1; then
    # Get interface details
    status=$(ip link show enp0s25 | grep -o "state [A-Z]*" | cut -d' ' -f2)
    ip_addr=$(ip addr show enp0s25 | grep "inet " | awk '{print $2}' | head -1)
    gateway=$(ip route show | grep "192.168.100.0/24" | grep "proto kernel" | awk '{print $1}' | sed 's|/24||').1
    
    echo "   Interface: enp0s25 ($status)"
    echo "   Local IP: $ip_addr"
    echo "   Gateway: $gateway"
    
    # Test gateway ping
    echo -n "   Gateway ping: "
    if ping -c 2 -W 3 -I enp0s25 $gateway >/dev/null 2>&1; then
        echo "✅ OK"
    else
        echo "❌ FAILED"
    fi
    
    # Test DNS ping
    echo -n "   DNS ping: "
    if ping -c 2 -W 3 -I enp0s25 8.8.8.8 >/dev/null 2>&1; then
        echo "✅ OK"
    else
        echo "❌ FAILED"
    fi
    
    # Test HTTP and get public IP
    echo -n "   HTTP test: "
    public_ip=$(curl -s --connect-timeout 10 --interface enp0s25 http://httpbin.org/ip 2>/dev/null | grep -o '"origin": "[^"]*"' | cut -d'"' -f4)
    if [ -n "$public_ip" ]; then
        echo "✅ OK (Public IP: $public_ip)"
    else
        echo "❌ FAILED"
    fi
else
    echo "   ❌ Interface enp0s25 not found"
fi

echo ""

# Test USB Tethering interface
echo "2. Testing USB Tethering Interface (usb-tether):"
if ip link show usb-tether >/dev/null 2>&1; then
    # Get interface details
    status=$(ip link show usb-tether | grep -o "state [A-Z]*" | cut -d' ' -f2)
    ip_addr=$(ip addr show usb-tether | grep "inet " | awk '{print $2}' | head -1)
    gateway=$(ip route show | grep "usb-tether proto dhcp" | grep "via" | awk '{print $3}' | head -1)
    
    echo "   Interface: usb-tether ($status)"
    echo "   Local IP: $ip_addr"
    echo "   Gateway: $gateway"
    
    # Test gateway ping
    echo -n "   Gateway ping: "
    if [ -n "$gateway" ] && ping -c 2 -W 3 -I usb-tether $gateway >/dev/null 2>&1; then
        echo "✅ OK"
    else
        echo "❌ FAILED"
    fi
    
    # Test DNS ping
    echo -n "   DNS ping: "
    if ping -c 2 -W 3 -I usb-tether 8.8.8.8 >/dev/null 2>&1; then
        echo "✅ OK"
    else
        echo "❌ FAILED"
    fi
    
    # Test HTTP and get public IP
    echo -n "   HTTP test: "
    public_ip=$(curl -s --connect-timeout 10 --interface usb-tether http://httpbin.org/ip 2>/dev/null | grep -o '"origin": "[^"]*"' | cut -d'"' -f4)
    if [ -n "$public_ip" ]; then
        echo "✅ OK (Public IP: $public_ip)"
    else
        echo "❌ FAILED"
    fi
else
    echo "   ❌ Interface usb-tether not found"
fi

echo ""

# Test Mihomo TUN interface
echo "3. Testing Mihomo TUN Interface (Meta):"
if ip link show Meta >/dev/null 2>&1; then
    # Get interface details
    status=$(ip link show Meta | grep -o "state [A-Z]*" | cut -d' ' -f2)
    ip_addr=$(ip addr show Meta | grep "inet " | awk '{print $2}' | head -1)
    
    echo "   Interface: Meta ($status)"
    echo "   Local IP: $ip_addr"
    
    # Test Mihomo controller
    echo -n "   Mihomo controller: "
    if curl -s --connect-timeout 5 http://127.0.0.1:9090 >/dev/null 2>&1; then
        echo "✅ OK"
    else
        echo "❌ FAILED"
    fi
    
    # Test SOCKS proxy
    echo -n "   SOCKS proxy: "
    proxy_ip=$(curl -s --connect-timeout 10 --proxy socks5://127.0.0.1:7891 http://httpbin.org/ip 2>/dev/null | grep -o '"origin": "[^"]*"' | cut -d'"' -f4)
    if [ -n "$proxy_ip" ]; then
        echo "✅ OK (Proxy IP: $proxy_ip)"
    else
        echo "❌ FAILED"
    fi
    
    # Test HTTP proxy
    echo -n "   HTTP proxy: "
    http_proxy_ip=$(curl -s --connect-timeout 10 --proxy http://127.0.0.1:7890 http://httpbin.org/ip 2>/dev/null | grep -o '"origin": "[^"]*"' | cut -d'"' -f4)
    if [ -n "$http_proxy_ip" ]; then
        echo "✅ OK (HTTP Proxy IP: $http_proxy_ip)"
    else
        echo "❌ FAILED"
    fi
else
    echo "   ❌ Interface Meta not found"
fi

echo ""
echo "🔧 Mihomo Configuration Test:"
echo "-----------------------------"

# Check Mihomo service
echo -n "Mihomo service: "
if systemctl is-active --quiet mihomo 2>/dev/null; then
    echo "✅ RUNNING"
else
    echo "❌ NOT RUNNING"
fi

# Check Mihomo config
echo -n "Mihomo config: "
if [ -f "/etc/mihomo/config.yaml" ]; then
    echo "✅ FOUND"
    
    # Check for interface configurations
    echo "   Configured interfaces:"
    grep -E "interface-name:" /etc/mihomo/config.yaml 2>/dev/null | while read line; do
        iface=$(echo "$line" | sed 's/.*interface-name:[[:space:]]*["\'"'"']*\([^"'"'"'[:space:]]*\)["\'"'"']*.*/\1/')
        if ip link show "$iface" >/dev/null 2>&1; then
            echo "     - $iface ✅"
        else
            echo "     - $iface ❌"
        fi
    done
    
    # Check load balancing
    if grep -q "load-balance" /etc/mihomo/config.yaml 2>/dev/null; then
        echo "   Load balancing: ✅ CONFIGURED"
    else
        echo "   Load balancing: ❌ NOT CONFIGURED"
    fi
else
    echo "❌ NOT FOUND"
fi

echo ""
echo "📊 Summary:"
echo "----------"

# Count successful tests
lan_ok=0
usb_ok=0
tun_ok=0

# Check LAN
if ip link show enp0s25 >/dev/null 2>&1 && ping -c 1 -W 2 -I enp0s25 8.8.8.8 >/dev/null 2>&1; then
    lan_ok=1
fi

# Check USB
if ip link show usb-tether >/dev/null 2>&1 && ping -c 1 -W 2 -I usb-tether 8.8.8.8 >/dev/null 2>&1; then
    usb_ok=1
fi

# Check TUN
if ip link show Meta >/dev/null 2>&1 && curl -s --connect-timeout 5 --proxy socks5://127.0.0.1:7891 http://httpbin.org/ip >/dev/null 2>&1; then
    tun_ok=1
fi

total_score=$((lan_ok + usb_ok + tun_ok))

echo "Interface Status:"
echo "  🔌 LAN (enp0s25): $([ $lan_ok -eq 1 ] && echo "✅ WORKING" || echo "❌ ISSUES")"
echo "  🔗 USB Tethering: $([ $usb_ok -eq 1 ] && echo "✅ WORKING" || echo "❌ ISSUES")"
echo "  🚀 Mihomo TUN: $([ $tun_ok -eq 1 ] && echo "✅ WORKING" || echo "❌ ISSUES")"

echo ""
echo "Overall Score: $total_score/3"

if [ $total_score -eq 3 ]; then
    echo "🎉 All interfaces working perfectly!"
elif [ $total_score -eq 2 ]; then
    echo "⚠️  Most interfaces working, minor issues detected"
else
    echo "❌ Significant issues detected, check configuration"
fi

echo ""
echo "🚀 Start Network Interface Manager:"
echo "   ./start.sh"
echo "   Access: http://localhost:5020"