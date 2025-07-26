#!/bin/bash

# Optimized USB Tethering Monitor and Auto-Reconfiguration Script
# Improved performance, error handling, and resource usage

SCRIPT_DIR="/home/acer/network-interface-manager"
LOG_FILE="$SCRIPT_DIR/usb-monitor.log"
LAST_USB_INTERFACE_FILE="$SCRIPT_DIR/.last_usb_interface"
LOCK_FILE="$SCRIPT_DIR/.usb-monitor.lock"
MAX_LOG_SIZE=1048576  # 1MB

# Function to manage log file size
manage_log_size() {
    if [ -f "$LOG_FILE" ] && [ $(stat -c%s "$LOG_FILE") -gt $MAX_LOG_SIZE ]; then
        tail -n 500 "$LOG_FILE" > "${LOG_FILE}.tmp"
        mv "${LOG_FILE}.tmp" "$LOG_FILE"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Log rotated due to size limit" >> "$LOG_FILE"
    fi
}

# Function to log messages with log rotation
log_message() {
    manage_log_size
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to acquire lock
acquire_lock() {
    if [ -f "$LOCK_FILE" ]; then
        local lock_pid=$(cat "$LOCK_FILE" 2>/dev/null)
        if [ -n "$lock_pid" ] && kill -0 "$lock_pid" 2>/dev/null; then
            return 1
        else
            rm -f "$LOCK_FILE"
        fi
    fi
    echo $$ > "$LOCK_FILE"
    return 0
}

# Function to release lock
release_lock() {
    rm -f "$LOCK_FILE"
}

# Cleanup function
cleanup() {
    release_lock
    exit 0
}

# Set up signal handlers
trap cleanup EXIT INT TERM

# Function to detect current USB tethering interfaces (optimized)
detect_usb_interfaces() {
    local interfaces=""
    
    # Check for standard usb-tether name first (fastest check)
    if [ -d "/sys/class/net/usb-tether" ]; then
        local state=$(cat "/sys/class/net/usb-tether/operstate" 2>/dev/null)
        if [[ "$state" == "up" ]]; then
            interfaces="usb-tether"
        fi
    fi
    
    # If no usb-tether found, look for enx pattern interfaces
    if [ -z "$interfaces" ]; then
        for iface in /sys/class/net/enx*; do
            if [ -d "$iface" ]; then
                local iface_name=$(basename "$iface")
                local state=$(cat "$iface/operstate" 2>/dev/null)
                if [[ "$state" == "up" ]]; then
                    interfaces="$interfaces $iface_name"
                fi
            fi
        done
        interfaces=$(echo "$interfaces" | xargs)  # trim whitespace
    fi
    
    echo "$interfaces"
}

# Function to get interface with IP address (optimized)
get_active_usb_interface() {
    local usb_interfaces=$(detect_usb_interfaces)
    for iface in $usb_interfaces; do
        if [ -f "/sys/class/net/$iface/address" ]; then
            # Quick check if interface has IP
            local ip=$(ip -4 addr show "$iface" 2>/dev/null | grep -o 'inet [0-9.]*' | cut -d' ' -f2)
            if [ -n "$ip" ]; then
                echo "$iface"
                return 0
            fi
        fi
    done
    return 1
}

# Function to check if interface changed (optimized)
check_interface_change() {
    local current_interface=$(get_active_usb_interface)
    local last_interface=""
    
    if [ -f "$LAST_USB_INTERFACE_FILE" ]; then
        last_interface=$(cat "$LAST_USB_INTERFACE_FILE" 2>/dev/null)
    fi
    
    if [ "$current_interface" != "$last_interface" ]; then
        log_message "USB interface change detected: '$last_interface' -> '$current_interface'"
        echo "$current_interface" > "$LAST_USB_INTERFACE_FILE"
        return 0
    fi
    
    return 1
}

# Function to reconfigure routing for new interface (optimized)
reconfigure_routing() {
    local new_interface="$1"
    
    log_message "Reconfiguring routing for interface: $new_interface"
    
    # Use optimized configuration script if available
    local config_script="$SCRIPT_DIR/configure-usb-tethering.sh"
    if [ -f "$SCRIPT_DIR/configure-usb-tethering-optimized.sh" ]; then
        config_script="$SCRIPT_DIR/configure-usb-tethering-optimized.sh"
    fi
    
    if [ -f "$config_script" ]; then
        log_message "Running USB tethering configuration..."
        timeout 60 "$config_script" >> "$LOG_FILE" 2>&1
        
        if [ $? -eq 0 ]; then
            log_message "USB tethering configuration completed successfully"
        else
            log_message "USB tethering configuration failed or timed out"
            return 1
        fi
    fi
    
    # Use optimized load balancing script if available
    local lb_script="$SCRIPT_DIR/setup-load-balancing.sh"
    if [ -f "$SCRIPT_DIR/setup-load-balancing-optimized.sh" ]; then
        lb_script="$SCRIPT_DIR/setup-load-balancing-optimized.sh"
    fi
    
    if [ -f "$lb_script" ]; then
        log_message "Setting up load balancing..."
        timeout 30 "$lb_script" >> "$LOG_FILE" 2>&1
        
        if [ $? -eq 0 ]; then
            log_message "Load balancing setup completed successfully"
        else
            log_message "Load balancing setup failed or timed out"
        fi
    fi
    
    # Quick connectivity test
    log_message "Testing connectivity..."
    if timeout 10 ping -c 2 8.8.8.8 >/dev/null 2>&1; then
        log_message "✅ Internet connectivity: OK"
    else
        log_message "❌ Internet connectivity: FAILED"
    fi
    
    return 0
}

# Function to show current status (optimized)
show_status() {
    log_message "=== USB Tethering Status ==="
    
    local usb_interfaces=$(detect_usb_interfaces)
    if [ -n "$usb_interfaces" ]; then
        log_message "Active USB interfaces: $usb_interfaces"
        
        for iface in $usb_interfaces; do
            local ip=$(ip -4 addr show "$iface" 2>/dev/null | grep -o 'inet [0-9.]*' | cut -d' ' -f2)
            local gw=$(ip route show dev "$iface" 2>/dev/null | grep default | awk '{print $3}' | head -1)
            log_message "  $iface: IP=${ip:-N/A}, Gateway=${gw:-N/A}"
        done
    else
        log_message "No active USB tethering interfaces found"
    fi
    
    local routes=$(ip route 2>/dev/null | grep -E "(usb|enx)" | wc -l)
    log_message "USB-related routes: $routes"
    
    log_message "=== End Status ==="
}

# Function to monitor continuously (optimized)
monitor_mode() {
    log_message "Starting optimized USB tethering monitor (continuous mode)"
    
    # Acquire lock to prevent multiple instances
    if ! acquire_lock; then
        log_message "Another monitor instance is already running"
        exit 1
    fi
    
    local check_count=0
    local last_check_time=0
    
    while true; do
        local current_time=$(date +%s)
        
        # Adaptive checking interval (more frequent when changes detected)
        local check_interval=10
        if [ $((current_time - last_check_time)) -lt 60 ]; then
            check_interval=5
        fi
        
        if check_interface_change; then
            local current_interface=$(get_active_usb_interface)
            if [ -n "$current_interface" ]; then
                reconfigure_routing "$current_interface"
                last_check_time=$current_time
            else
                log_message "No active USB interface found after change"
            fi
        fi
        
        # Periodic status check (every 100 iterations)
        check_count=$((check_count + 1))
        if [ $((check_count % 100)) -eq 0 ]; then
            show_status
            manage_log_size
        fi
        
        sleep $check_interval
    done
}

# Function to run once (optimized)
check_once() {
    log_message "Running optimized USB tethering check (single run)"
    
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
        echo "  monitor       - Continuously monitor for changes (optimized)"
        echo "  status        - Show current USB tethering status"
        echo "  force-reconfig - Force reconfiguration of current interface"
        exit 1
        ;;
esac