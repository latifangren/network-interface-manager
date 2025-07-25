#!/bin/bash

# USB Tethering Interface Renaming Script
# Renames existing USB tethering interfaces to "usb-tether"

echo "🔄 USB Tethering Interface Renaming"
echo "=================================="

# Function to find current USB tethering interface
find_usb_interface() {
    # Look for RNDIS or enx interfaces
    local interfaces=$(ip link show | grep -E "(enx[0-9a-f]+|rndis)" | awk -F': ' '{print $2}' | cut -d'@' -f1)
    echo "$interfaces"
}

# Function to check if interface is USB tethering
is_usb_tethering() {
    local iface=$1
    
    # Check if it's RNDIS driver
    local driver=$(readlink /sys/class/net/$iface/device/driver 2>/dev/null | xargs basename)
    if [ "$driver" = "rndis_host" ]; then
        return 0
    fi
    
    # Check if it's enx pattern (USB ethernet)
    if [[ $iface =~ ^enx[0-9a-f]+$ ]]; then
        return 0
    fi
    
    return 1
}

# Function to rename interface
rename_interface() {
    local old_name=$1
    local new_name="usb-tether"
    
    echo "📱 Renaming interface: $old_name -> $new_name"
    
    # Check if target name already exists
    if ip link show "$new_name" >/dev/null 2>&1; then
        echo "⚠️  Interface $new_name already exists"
        return 1
    fi
    
    # Get current IP and routes before renaming
    local ip_addr=$(ip addr show "$old_name" 2>/dev/null | grep "inet " | awk '{print $2}')
    local gateway=$(ip route show dev "$old_name" | grep default | awk '{print $3}')
    
    echo "  Current IP: $ip_addr"
    echo "  Current Gateway: $gateway"
    
    # Bring interface down
    echo "  Bringing interface down..."
    sudo ip link set "$old_name" down
    
    # Rename interface
    echo "  Renaming interface..."
    sudo ip link set "$old_name" name "$new_name"
    
    # Bring interface up
    echo "  Bringing interface up..."
    sudo ip link set "$new_name" up
    
    # Restore IP address if it existed
    if [ -n "$ip_addr" ]; then
        echo "  Restoring IP address: $ip_addr"
        sudo ip addr add "$ip_addr" dev "$new_name"
    fi
    
    # Restore default route if it existed
    if [ -n "$gateway" ]; then
        echo "  Restoring gateway: $gateway"
        sudo ip route add default via "$gateway" dev "$new_name" 2>/dev/null || true
    fi
    
    echo "✅ Interface renamed successfully!"
    return 0
}

# Function to setup load balancing with new name
setup_load_balancing_new() {
    echo "⚖️ Setting up load balancing with usb-tether..."
    
    # Get LAN interface info
    local lan_ip=$(ip addr show enp0s25 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
    local lan_gw=$(ip route | grep "default.*enp0s25" | awk '{print $3}' | head -1)
    
    # Get USB interface info
    local usb_ip=$(ip addr show usb-tether 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
    local usb_gw=$(ip route | grep "default.*usb-tether" | awk '{print $3}' | head -1)
    
    if [ -n "$lan_ip" ] && [ -n "$usb_ip" ] && [ -n "$lan_gw" ] && [ -n "$usb_gw" ]; then
        echo "  LAN: $lan_ip via $lan_gw"
        echo "  USB: $usb_ip via $usb_gw"
        
        # Remove existing default routes
        sudo ip route del default 2>/dev/null || true
        
        # Add load balanced route
        sudo ip route add default \
            nexthop via "$lan_gw" dev enp0s25 weight 1 \
            nexthop via "$usb_gw" dev usb-tether weight 1
        
        echo "✅ Load balancing configured!"
    else
        echo "❌ Missing interface information for load balancing"
    fi
}

# Main execution
main() {
    echo "Searching for USB tethering interfaces..."
    
    local usb_interfaces=$(find_usb_interface)
    
    if [ -z "$usb_interfaces" ]; then
        echo "❌ No USB tethering interfaces found"
        exit 1
    fi
    
    echo "Found interfaces: $usb_interfaces"
    
    local renamed=false
    for iface in $usb_interfaces; do
        if [ "$iface" = "usb-tether" ]; then
            echo "✅ Interface $iface already has correct name"
            continue
        fi
        
        if is_usb_tethering "$iface"; then
            echo "🔍 $iface is a USB tethering interface"
            if rename_interface "$iface"; then
                renamed=true
            fi
        else
            echo "⏭️  $iface is not a USB tethering interface, skipping"
        fi
    done
    
    if [ "$renamed" = true ]; then
        echo ""
        echo "🔄 Setting up networking..."
        
        # Wait a moment for interface to stabilize
        sleep 2
        
        # Try to get IP via DHCP if needed
        if ! ip addr show usb-tether | grep "inet " >/dev/null; then
            echo "📡 Requesting IP via DHCP..."
            sudo dhclient usb-tether
        fi
        
        # Setup load balancing
        setup_load_balancing_new
        
        # Test connectivity
        echo ""
        echo "🧪 Testing connectivity..."
        if ping -c 2 8.8.8.8 >/dev/null 2>&1; then
            echo "✅ Internet connectivity: OK"
        else
            echo "❌ Internet connectivity: FAILED"
        fi
        
        echo ""
        echo "📊 Current interface status:"
        ip addr show usb-tether 2>/dev/null || echo "usb-tether interface not found"
        
        echo ""
        echo "🛣️  Current routing:"
        ip route | head -5
        
    else
        echo "ℹ️  No interfaces were renamed"
    fi
    
    echo ""
    echo "🎉 USB tethering interface setup completed!"
}

# Run main function
main "$@"