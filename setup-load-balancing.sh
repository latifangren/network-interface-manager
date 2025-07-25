#!/bin/bash

# Setup Load Balancing for New USB Tethering Interface
echo "🔄 Setting up load balancing for USB tethering..."

# Get current interfaces
LAN_IF="enp0s25"
USB_IF="usb-tether"

# Get IP addresses and gateways
LAN_IP=$(ip addr show $LAN_IF 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
USB_IP=$(ip addr show $USB_IF 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d'/' -f1)

# Get gateways
LAN_GW=$(ip route show dev $LAN_IF | grep default | awk '{print $3}' | head -1)
if [ -z "$LAN_GW" ]; then
    # Try to get from network
    LAN_GW=$(ip route | grep "default.*$LAN_IF" | awk '{print $3}' | head -1)
    if [ -z "$LAN_GW" ]; then
        # Calculate gateway from IP
        LAN_NETWORK=$(echo $LAN_IP | cut -d'.' -f1-3)
        LAN_GW="${LAN_NETWORK}.1"
    fi
fi

USB_GW=$(ip route show dev $USB_IF | grep default | awk '{print $3}' | head -1)
if [ -z "$USB_GW" ]; then
    # Try to get from DHCP lease
    USB_GW=$(grep "option routers" /var/lib/dhcp/dhclient.leases | tail -1 | awk '{print $3}' | tr -d ';')
    if [ -z "$USB_GW" ]; then
        # Calculate gateway from IP
        USB_NETWORK=$(echo $USB_IP | cut -d'.' -f1-3)
        USB_GW="${USB_NETWORK}.1"
    fi
fi

echo "📊 Interface Information:"
echo "  LAN ($LAN_IF): IP=$LAN_IP, Gateway=$LAN_GW"
echo "  USB ($USB_IF): IP=$USB_IP, Gateway=$USB_GW"

if [ -n "$LAN_IP" ] && [ -n "$USB_IP" ] && [ -n "$LAN_GW" ] && [ -n "$USB_GW" ]; then
    echo "🔧 Configuring load balancing..."
    
    # Remove all existing default routes
    echo "  Removing existing default routes..."
    sudo ip route del default 2>/dev/null || true
    
    # Add routing tables for each interface
    echo "  Setting up routing tables..."
    
    # Table for LAN
    LAN_NETWORK=$(echo $LAN_IP | cut -d'.' -f1-3)
    if [ -n "$LAN_NETWORK" ] && [ "$LAN_NETWORK" != "" ]; then
        sudo ip route add ${LAN_NETWORK}.0/24 dev $LAN_IF src $LAN_IP table 1 2>/dev/null || true
        sudo ip route add default via $LAN_GW table 1 2>/dev/null || true
    fi
    
    # Table for USB
    USB_NETWORK=$(echo $USB_IP | cut -d'.' -f1-3)
    if [ -n "$USB_NETWORK" ] && [ "$USB_NETWORK" != "" ]; then
        sudo ip route add ${USB_NETWORK}.0/24 dev $USB_IF src $USB_IP table 2 2>/dev/null || true
        sudo ip route add default via $USB_GW table 2 2>/dev/null || true
    fi
    
    # Rules for source-based routing
    sudo ip rule add from $LAN_IP table 1
    sudo ip rule add from $USB_IP table 2
    
    # Main routing table with load balancing
    LAN_NETWORK=$(echo $LAN_IP | cut -d'.' -f1-3)
    USB_NETWORK=$(echo $USB_IP | cut -d'.' -f1-3)
    
    if [ -n "$LAN_NETWORK" ] && [ "$LAN_NETWORK" != "" ]; then
        sudo ip route add ${LAN_NETWORK}.0/24 dev $LAN_IF src $LAN_IP 2>/dev/null || true
    fi
    
    if [ -n "$USB_NETWORK" ] && [ "$USB_NETWORK" != "" ]; then
        sudo ip route add ${USB_NETWORK}.0/24 dev $USB_IF src $USB_IP 2>/dev/null || true
    fi
    
    # Load balanced default route
    sudo ip route add default \
        nexthop via $LAN_GW dev $LAN_IF weight 1 \
        nexthop via $USB_GW dev $USB_IF weight 1
    
    echo "✅ Load balancing configured successfully!"
    
    # Test connectivity
    echo "🧪 Testing connectivity..."
    if ping -c 2 8.8.8.8 >/dev/null 2>&1; then
        echo "✅ Internet connectivity: OK"
    else
        echo "❌ Internet connectivity: FAILED"
    fi
    
    # Show current routing
    echo "📋 Current routing table:"
    ip route | head -10
    
else
    echo "❌ Missing interface information. Cannot configure load balancing."
    echo "   LAN_IP: $LAN_IP"
    echo "   USB_IP: $USB_IP" 
    echo "   LAN_GW: $LAN_GW"
    echo "   USB_GW: $USB_GW"
fi