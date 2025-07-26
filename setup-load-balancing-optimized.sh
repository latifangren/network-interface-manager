#!/bin/bash

# Optimized Load Balancing Setup for USB Tethering
# Fixes routing errors and improves performance

set -e

echo "🔄 Setting up optimized load balancing for USB tethering..."

# Get current interfaces with better error handling
LAN_IF="enp0s25"
USB_IF="usb-tether"

# Function to safely get IP address
get_interface_ip() {
    local interface=$1
    ip addr show "$interface" 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d'/' -f1 | head -1
}

# Function to safely get gateway
get_interface_gateway() {
    local interface=$1
    local gateway=""
    
    # Try multiple methods to get gateway
    gateway=$(ip route show dev "$interface" 2>/dev/null | grep default | awk '{print $3}' | head -1)
    
    if [ -z "$gateway" ]; then
        # Try from main routing table
        gateway=$(ip route 2>/dev/null | grep "default.*$interface" | awk '{print $3}' | head -1)
    fi
    
    if [ -z "$gateway" ]; then
        # Calculate gateway from IP (assume .1 or .129 for USB tethering)
        local ip=$(get_interface_ip "$interface")
        if [ -n "$ip" ]; then
            local network=$(echo "$ip" | cut -d'.' -f1-3)
            if [[ "$interface" == *"usb"* ]] || [[ "$interface" == *"enx"* ]]; then
                # Common USB tethering gateways
                if ping -c 1 -W 1 "${network}.129" >/dev/null 2>&1; then
                    gateway="${network}.129"
                elif ping -c 1 -W 1 "${network}.1" >/dev/null 2>&1; then
                    gateway="${network}.1"
                fi
            else
                gateway="${network}.1"
            fi
        fi
    fi
    
    echo "$gateway"
}

# Function to validate network format
validate_network() {
    local network=$1
    if [[ "$network" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "${network}.0/24"
    else
        echo ""
    fi
}

# Get IP addresses and gateways with validation
LAN_IP=$(get_interface_ip "$LAN_IF")
USB_IP=$(get_interface_ip "$USB_IF")
LAN_GW=$(get_interface_gateway "$LAN_IF")
USB_GW=$(get_interface_gateway "$USB_IF")

echo "📊 Interface Information:"
echo "  LAN ($LAN_IF): IP=${LAN_IP:-N/A}, Gateway=${LAN_GW:-N/A}"
echo "  USB ($USB_IF): IP=${USB_IP:-N/A}, Gateway=${USB_GW:-N/A}"

# Check if we have minimum required information
if [ -z "$USB_IP" ]; then
    echo "❌ USB interface not found or has no IP address"
    exit 1
fi

if [ -z "$USB_GW" ]; then
    echo "⚠️  USB gateway not detected, trying to configure anyway..."
fi

echo "🔧 Configuring optimized load balancing..."

# Clean up existing routes and rules
echo "  Cleaning up existing configuration..."
sudo ip route flush table 1 2>/dev/null || true
sudo ip route flush table 2 2>/dev/null || true
sudo ip rule del from "$LAN_IP" table 1 2>/dev/null || true
sudo ip rule del from "$USB_IP" table 2 2>/dev/null || true

# Remove existing default routes
sudo ip route del default 2>/dev/null || true

# Setup routing tables if we have valid IPs and gateways
if [ -n "$LAN_IP" ] && [ -n "$LAN_GW" ]; then
    echo "  Setting up LAN routing table..."
    LAN_NETWORK=$(validate_network "$(echo "$LAN_IP" | cut -d'.' -f1-3)")
    if [ -n "$LAN_NETWORK" ]; then
        sudo ip route add "$LAN_NETWORK" dev "$LAN_IF" src "$LAN_IP" table 1
        sudo ip route add default via "$LAN_GW" table 1
        sudo ip rule add from "$LAN_IP" table 1
    fi
fi

if [ -n "$USB_IP" ] && [ -n "$USB_GW" ]; then
    echo "  Setting up USB routing table..."
    USB_NETWORK=$(validate_network "$(echo "$USB_IP" | cut -d'.' -f1-3)")
    if [ -n "$USB_NETWORK" ]; then
        sudo ip route add "$USB_NETWORK" dev "$USB_IF" src "$USB_IP" table 2
        sudo ip route add default via "$USB_GW" table 2
        sudo ip rule add from "$USB_IP" table 2
    fi
fi

# Setup main routing table with load balancing
echo "  Setting up main routing table..."

# Add local network routes
if [ -n "$LAN_IP" ]; then
    LAN_NETWORK=$(validate_network "$(echo "$LAN_IP" | cut -d'.' -f1-3)")
    if [ -n "$LAN_NETWORK" ]; then
        sudo ip route add "$LAN_NETWORK" dev "$LAN_IF" src "$LAN_IP" 2>/dev/null || true
    fi
fi

if [ -n "$USB_IP" ]; then
    USB_NETWORK=$(validate_network "$(echo "$USB_IP" | cut -d'.' -f1-3)")
    if [ -n "$USB_NETWORK" ]; then
        sudo ip route add "$USB_NETWORK" dev "$USB_IF" src "$USB_IP" 2>/dev/null || true
    fi
fi

# Add load balanced default route
if [ -n "$LAN_GW" ] && [ -n "$USB_GW" ]; then
    echo "  Adding load balanced default route..."
    sudo ip route add default \
        nexthop via "$LAN_GW" dev "$LAN_IF" weight 1 \
        nexthop via "$USB_GW" dev "$USB_IF" weight 1
    echo "✅ Load balancing configured: LAN ($LAN_GW) + USB ($USB_GW)"
elif [ -n "$USB_GW" ]; then
    echo "  Adding USB-only default route..."
    sudo ip route add default via "$USB_GW" dev "$USB_IF"
    echo "✅ Default route set via USB: $USB_GW"
elif [ -n "$LAN_GW" ]; then
    echo "  Adding LAN-only default route..."
    sudo ip route add default via "$LAN_GW" dev "$LAN_IF"
    echo "✅ Default route set via LAN: $LAN_GW"
else
    echo "❌ No valid gateways found for routing"
fi

# Test connectivity with timeout
echo "🧪 Testing connectivity..."
if timeout 5 ping -c 2 8.8.8.8 >/dev/null 2>&1; then
    echo "✅ Internet connectivity: OK"
else
    echo "⚠️  Internet connectivity: Limited or failed"
fi

# Show current routing (limited output)
echo "📋 Current routing table (top 5 routes):"
ip route | head -5

echo "✅ Optimized load balancing setup completed!"