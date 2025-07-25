#!/bin/bash

# Mihomo Integration Test Script

echo "🚀 Network Interface Manager - Mihomo Integration Test"
echo "======================================================"
echo ""

# Check Mihomo service status
echo "📡 Checking Mihomo Service Status:"
echo "-----------------------------------"
if systemctl is-active --quiet mihomo 2>/dev/null || pgrep -f mihomo >/dev/null 2>&1; then
    echo "  ✅ Mihomo service is RUNNING"
    
    # Check TUN interface
    if ip link show Meta >/dev/null 2>&1; then
        echo "  ✅ TUN interface 'Meta' is ACTIVE"
        
        # Get TUN interface details
        tun_info=$(ip addr show Meta 2>/dev/null | head -2)
        echo "  📊 TUN Interface Details:"
        echo "$tun_info" | sed 's/^/      /'
    else
        echo "  ❌ TUN interface 'Meta' not found"
    fi
    
    # Check configured interfaces from Mihomo config
    echo ""
    echo "  🔧 Mihomo Configuration:"
    if [ -f "/etc/mihomo/config.yaml" ]; then
        echo "    • Config file: /etc/mihomo/config.yaml ✅"
        
        # Extract interface names from config
        interfaces=$(grep -E "interface-name:" /etc/mihomo/config.yaml 2>/dev/null | sed 's/.*interface-name:[[:space:]]*["\'"'"']*\([^"'"'"'[:space:]]*\)["\'"'"']*.*/\1/' | sort -u)
        if [ -n "$interfaces" ]; then
            echo "    • Configured interfaces for load balancing:"
            echo "$interfaces" | while read iface; do
                if [ -n "$iface" ]; then
                    if ip link show "$iface" >/dev/null 2>&1; then
                        status=$(ip link show "$iface" | grep -o "state [A-Z]*" | cut -d' ' -f2)
                        echo "      - $iface ($status) ✅"
                    else
                        echo "      - $iface (NOT FOUND) ❌"
                    fi
                fi
            done
        fi
        
        # Check load balancing configuration
        if grep -q "load-balance" /etc/mihomo/config.yaml 2>/dev/null; then
            echo "    • Load balancing: CONFIGURED ✅"
            lb_group=$(grep -A 5 "LB-LAN-USB" /etc/mihomo/config.yaml 2>/dev/null | grep -E "type:|strategy:" | head -2)
            if [ -n "$lb_group" ]; then
                echo "      Load balance details:"
                echo "$lb_group" | sed 's/^/        /'
            fi
        else
            echo "    • Load balancing: NOT CONFIGURED ❌"
        fi
    else
        echo "    • Config file: NOT FOUND ❌"
    fi
    
else
    echo "  ❌ Mihomo service is NOT RUNNING"
    echo "     Try: sudo systemctl start mihomo"
fi

echo ""
echo "🌐 Current Network Interfaces:"
echo "------------------------------"
ip link show | grep -E "^[0-9]+:" | while read line; do
    iface_name=$(echo "$line" | cut -d: -f2 | sed 's/^ *//' | cut -d@ -f1)
    state=$(echo "$line" | grep -o "state [A-Z]*" | cut -d' ' -f2)
    
    # Determine interface type
    case "$iface_name" in
        lo) type="loopback" ;;
        enp*|eth*) type="ethernet" ;;
        wlp*|wlan*) type="wireless" ;;
        usb*|rndis*) type="usb_tethering" ;;
        Meta) type="mihomo_tun" ;;
        tun*|tailscale*) type="vpn" ;;
        docker*|br-*) type="bridge" ;;
        *) type="other" ;;
    esac
    
    # Color coding for status
    if [ "$state" = "UP" ]; then
        status_icon="🟢"
    else
        status_icon="🔴"
    fi
    
    # Special icon for Mihomo TUN
    if [ "$type" = "mihomo_tun" ]; then
        type_icon="🚀"
    elif [ "$type" = "ethernet" ]; then
        type_icon="🔌"
    elif [ "$type" = "wireless" ]; then
        type_icon="📶"
    elif [ "$type" = "usb_tethering" ]; then
        type_icon="🔗"
    else
        type_icon="🔧"
    fi
    
    echo "  $type_icon $iface_name ($type) $status_icon $state"
done

echo ""
echo "🚀 Starting Network Interface Manager with Mihomo Support..."
echo "   Web Interface: http://localhost:5020"
echo "   Features:"
echo "     ✅ Mihomo TUN interface detection"
echo "     ✅ Load balancing interface monitoring"
echo "     ✅ Real-time proxy status"
echo "     ✅ Interface management for dual-WAN setup"
echo ""
echo "Press Ctrl+C to stop the server"
echo "======================================================"

# Start the application
cd "$(dirname "$0")"
exec ./start.sh