#!/bin/bash

# USB Tethering Auto-Configuration Script
# Detects and configures new USB tethering interfaces automatically

echo "🔍 USB Tethering Auto-Configuration"
echo "=================================="

# Function to detect USB tethering interfaces
detect_usb_interfaces() {
    echo "Detecting USB tethering interfaces..."
    
    # Look for interfaces that match USB tethering patterns (prioritize usb-tether name)
    local usb_interfaces=""
    
    # Check for standard usb-tether name first
    if ip link show usb-tether >/dev/null 2>&1; then
        usb_interfaces="usb-tether"
    else
        # Fallback to enx pattern interfaces
        usb_interfaces=$(ip link show | grep -E "(usb|enx)" | awk -F': ' '{print $2}' | cut -d'@' -f1)
    fi
    
    if [ -z "$usb_interfaces" ]; then
        echo "❌ No USB tethering interfaces found"
        return 1
    fi
    
    echo "📱 Found USB interfaces:"
    echo "$usb_interfaces"
    return 0
}

# Function to configure USB interface
configure_usb_interface() {
    local interface=$1
    echo "🔧 Configuring interface: $interface"
    
    # Check if interface is up
    local state=$(ip link show "$interface" 2>/dev/null | grep -o "state [A-Z]*" | cut -d' ' -f2)
    
    if [ "$state" != "UP" ]; then
        echo "📶 Bringing up interface $interface..."
        sudo ip link set "$interface" up
        sleep 2
    fi
    
    # Try to get IP via DHCP
    echo "🌐 Requesting IP address via DHCP..."
    sudo dhclient "$interface" -v
    
    sleep 5
    
    # Check if we got an IP
    local ip=$(ip addr show "$interface" | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
    
    if [ -n "$ip" ]; then
        echo "✅ Interface $interface configured with IP: $ip"
        
        # Get gateway
        local gateway=$(ip route show dev "$interface" | grep default | awk '{print $3}')
        if [ -n "$gateway" ]; then
            echo "🚪 Gateway detected: $gateway"
        fi
        
        return 0
    else
        echo "❌ Failed to get IP address for $interface"
        return 1
    fi
}

# Function to setup load balancing
setup_load_balancing() {
    echo "⚖️ Setting up load balancing..."
    
    # Get LAN interface (enp0s25)
    local lan_ip=$(ip addr show enp0s25 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
    local lan_gw=$(ip route show dev enp0s25 | grep default | awk '{print $3}')
    
    # Get USB tethering interfaces
    local usb_interfaces=""
    
    # Check for standard usb-tether name first
    if ip link show usb-tether >/dev/null 2>&1; then
        usb_interfaces="usb-tether"
    else
        # Fallback to enx pattern interfaces
        usb_interfaces=$(ip link show | grep -E "enx" | awk -F': ' '{print $2}' | cut -d'@' -f1)
    fi
    
    for usb_if in $usb_interfaces; do
        local usb_ip=$(ip addr show "$usb_if" 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
        local usb_gw=$(ip route show dev "$usb_if" | grep default | awk '{print $3}')
        
        if [ -n "$usb_ip" ] && [ -n "$usb_gw" ]; then
            echo "🔗 Setting up load balancing for $usb_if (IP: $usb_ip, GW: $usb_gw)"
            
            # Remove existing default routes
            sudo ip route del default 2>/dev/null || true
            
            # Add load balanced default routes
            if [ -n "$lan_gw" ]; then
                sudo ip route add default nexthop via "$lan_gw" dev enp0s25 weight 1 nexthop via "$usb_gw" dev "$usb_if" weight 1
                echo "✅ Load balancing configured: LAN ($lan_gw) + USB ($usb_gw)"
            else
                sudo ip route add default via "$usb_gw" dev "$usb_if"
                echo "✅ Default route set via USB: $usb_gw"
            fi
            
            break
        fi
    done
}

# Function to test connectivity
test_connectivity() {
    echo "🧪 Testing connectivity..."
    
    # Test basic connectivity
    if ping -c 2 8.8.8.8 >/dev/null 2>&1; then
        echo "✅ Internet connectivity: OK"
    else
        echo "❌ Internet connectivity: FAILED"
    fi
    
    # Test DNS resolution
    if nslookup google.com >/dev/null 2>&1; then
        echo "✅ DNS resolution: OK"
    else
        echo "❌ DNS resolution: FAILED"
    fi
}

# Function to show current status
show_status() {
    echo ""
    echo "📊 Current Network Status"
    echo "========================"
    
    echo "🔌 Network Interfaces:"
    ip addr show | grep -E "^[0-9]+:|inet " | sed 's/^/  /'
    
    echo ""
    echo "🛣️ Routing Table:"
    ip route | sed 's/^/  /'
    
    echo ""
    echo "🌐 Active Connections:"
    ss -tuln | head -10 | sed 's/^/  /'
}

# Main execution
main() {
    echo "Starting USB tethering auto-configuration..."
    
    # Detect USB interfaces
    if ! detect_usb_interfaces; then
        echo "No USB tethering interfaces to configure"
        exit 1
    fi
    
    # Configure each USB interface
    local configured=false
    local usb_interfaces=""
    
    # Check for standard usb-tether name first
    if ip link show usb-tether >/dev/null 2>&1; then
        usb_interfaces="usb-tether"
    else
        # Fallback to enx pattern interfaces
        usb_interfaces=$(ip link show | grep -E "enx" | awk -F': ' '{print $2}' | cut -d'@' -f1)
    fi
    
    for interface in $usb_interfaces; do
        if configure_usb_interface "$interface"; then
            configured=true
        fi
    done
    
    if [ "$configured" = true ]; then
        # Setup load balancing
        setup_load_balancing
        
        # Test connectivity
        test_connectivity
        
        # Show status
        show_status
        
        echo ""
        echo "🎉 USB tethering configuration completed!"
        echo "📱 You can now access the web interface at: http://localhost:5020"
    else
        echo "❌ Failed to configure USB tethering interfaces"
        exit 1
    fi
}

# Run main function
main "$@"