#!/bin/bash

# USB Tethering Monitor and Auto-Reconfiguration Script
# Monitors for USB tethering interface changes and automatically reconfigures

SCRIPT_DIR="/home/acer/network-interface-manager"
LOG_FILE="$SCRIPT_DIR/usb-monitor.log"
LAST_USB_INTERFACE_FILE="$SCRIPT_DIR/.last_usb_interface"

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to detect current USB tethering interfaces
detect_usb_interfaces() {
    # Look for USB tethering interfaces (prioritize usb-tether name, then fallback to enx pattern)
    local interfaces=""
    
    # Check for standard usb-tether name first
    if ip link show usb-tether >/dev/null 2>&1; then
        local state=$(ip link show usb-tether | grep -o "state [A-Z]*" | cut -d' ' -f2)
        if [[ "$state" == "UP" ]] || ip link show usb-tether | grep "UP" >/dev/null; then
            interfaces="usb-tether"
        fi
    fi
    
    # If no usb-tether found, look for enx pattern interfaces
    if [ -z "$interfaces" ]; then
        interfaces=$(ip link show | grep -E "(usb|enx)" | grep "UP" | awk -F': ' '{print $2}' | cut -d'@' -f1)
    fi
    
    echo "$interfaces"
}

# Function to get interface with IP address
get_active_usb_interface() {
    local usb_interfaces=$(detect_usb_interfaces)
    for iface in $usb_interfaces; do
        local ip=$(ip addr show "$iface" 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
        if [ -n "$ip" ]; then
            echo "$iface"
            return 0
        fi
    done
    return 1
}

# Function to check if interface changed
check_interface_change() {
    local current_interface=$(get_active_usb_interface)
    local last_interface=""
    
    if [ -f "$LAST_USB_INTERFACE_FILE" ]; then
        last_interface=$(cat "$LAST_USB_INTERFACE_FILE")
    fi
    
    if [ "$current_interface" != "$last_interface" ]; then
        log_message "USB interface change detected: '$last_interface' -> '$current_interface'"
        echo "$current_interface" > "$LAST_USB_INTERFACE_FILE"
        return 0
    fi
    
    return 1
}

# Function to reconfigure routing for new interface
reconfigure_routing() {
    local new_interface="$1"
    
    log_message "Reconfiguring routing for interface: $new_interface"
    
    # Run the auto-configuration script
    if [ -f "$SCRIPT_DIR/configure-usb-tethering.sh" ]; then
        log_message "Running USB tethering configuration..."
        "$SCRIPT_DIR/configure-usb-tethering.sh" >> "$LOG_FILE" 2>&1
        
        if [ $? -eq 0 ]; then
            log_message "USB tethering configuration completed successfully"
        else
            log_message "USB tethering configuration failed"
            return 1
        fi
    fi
    
    # Setup load balancing
    if [ -f "$SCRIPT_DIR/setup-load-balancing.sh" ]; then
        log_message "Setting up load balancing..."
        "$SCRIPT_DIR/setup-load-balancing.sh" >> "$LOG_FILE" 2>&1
        
        if [ $? -eq 0 ]; then
            log_message "Load balancing setup completed successfully"
        else
            log_message "Load balancing setup failed"
        fi
    fi
    
    # Test connectivity
    log_message "Testing connectivity..."
    if ping -c 2 8.8.8.8 >/dev/null 2>&1; then
        log_message "✅ Internet connectivity: OK"
    else
        log_message "❌ Internet connectivity: FAILED"
    fi
    
    return 0
}

# Function to show current status
show_status() {
    log_message "=== USB Tethering Status ==="
    
    local usb_interfaces=$(detect_usb_interfaces)
    if [ -n "$usb_interfaces" ]; then
        log_message "Active USB interfaces: $usb_interfaces"
        
        for iface in $usb_interfaces; do
            local ip=$(ip addr show "$iface" 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
            local gw=$(ip route show dev "$iface" | grep default | awk '{print $3}')
            log_message "  $iface: IP=$ip, Gateway=$gw"
        done
    else
        log_message "No active USB tethering interfaces found"
    fi
    
    local routes=$(ip route | grep -E "(usb|enx)" | wc -l)
    log_message "USB-related routes: $routes"
    
    log_message "=== End Status ==="
}

# Function to monitor continuously
monitor_mode() {
    log_message "Starting USB tethering monitor (continuous mode)"
    
    while true; do
        if check_interface_change; then
            local current_interface=$(get_active_usb_interface)
            if [ -n "$current_interface" ]; then
                reconfigure_routing "$current_interface"
            else
                log_message "No active USB interface found after change"
            fi
        fi
        
        sleep 10  # Check every 10 seconds
    done
}

# Function to run once
check_once() {
    log_message "Running USB tethering check (single run)"
    
    if check_interface_change; then
        local current_interface=$(get_active_usb_interface)
        if [ -n "$current_interface" ]; then
            reconfigure_routing "$current_interface"
        else
            log_message "No active USB interface found"
        fi
    else
        log_message "No USB interface changes detected"
    fi
    
    show_status
}

# Main execution
case "${1:-check}" in
    "monitor")
        monitor_mode
        ;;
    "check")
        check_once
        ;;
    "status")
        show_status
        ;;
    "force-reconfig")
        current_interface=$(get_active_usb_interface)
        if [ -n "$current_interface" ]; then
            log_message "Force reconfiguring interface: $current_interface"
            reconfigure_routing "$current_interface"
        else
            log_message "No active USB interface to reconfigure"
        fi
        ;;
    *)
        echo "Usage: $0 {check|monitor|status|force-reconfig}"
        echo "  check         - Check once for changes and reconfigure if needed"
        echo "  monitor       - Continuously monitor for changes"
        echo "  status        - Show current USB tethering status"
        echo "  force-reconfig - Force reconfiguration of current interface"
        exit 1
        ;;
esac