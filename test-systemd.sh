#!/bin/bash

# SystemD Services Test Script
# Tests if services are properly configured for auto-start

echo "🧪 SystemD Services Test"
echo "========================"
echo ""

echo "📊 Service Status Check:"
echo "------------------------"

# Check if services are enabled
echo "1. Service Auto-start Status:"
NETWORK_ENABLED=$(systemctl is-enabled network-manager.service 2>/dev/null)
USB_ENABLED=$(systemctl is-enabled usb-monitor.service 2>/dev/null)

if [ "$NETWORK_ENABLED" = "enabled" ]; then
    echo "   ✅ network-manager.service: enabled (will start on boot)"
else
    echo "   ❌ network-manager.service: $NETWORK_ENABLED"
fi

if [ "$USB_ENABLED" = "enabled" ]; then
    echo "   ✅ usb-monitor.service: enabled (will start on boot)"
else
    echo "   ❌ usb-monitor.service: $USB_ENABLED"
fi

echo ""
echo "2. Current Service Status:"
NETWORK_ACTIVE=$(systemctl is-active network-manager.service 2>/dev/null)
USB_ACTIVE=$(systemctl is-active usb-monitor.service 2>/dev/null)

if [ "$NETWORK_ACTIVE" = "active" ]; then
    echo "   ✅ network-manager.service: running"
else
    echo "   ❌ network-manager.service: $NETWORK_ACTIVE"
fi

if [ "$USB_ACTIVE" = "active" ]; then
    echo "   ✅ usb-monitor.service: running"
else
    echo "   ❌ usb-monitor.service: $USB_ACTIVE"
fi

echo ""
echo "🌐 Web Interface Test:"
echo "---------------------"
if curl -s http://localhost:5020/api/interfaces >/dev/null 2>&1; then
    echo "✅ Web interface accessible at: http://localhost:5020"
    
    # Test API endpoints
    INTERFACE_COUNT=$(curl -s http://localhost:5020/api/interfaces | python3 -c "import sys, json; print(len(json.load(sys.stdin)))" 2>/dev/null)
    echo "   Interfaces detected: $INTERFACE_COUNT"
    
    USB_DETECTED=$(curl -s http://localhost:5020/api/interfaces | python3 -c "import sys, json; print('usb-tether' in json.load(sys.stdin))" 2>/dev/null)
    if [ "$USB_DETECTED" = "True" ]; then
        echo "   ✅ USB tethering interface detected"
    else
        echo "   ❌ USB tethering interface not detected"
    fi
else
    echo "❌ Web interface not accessible"
fi

echo ""
echo "📱 USB Monitoring Test:"
echo "----------------------"
if [ -f "/home/acer/network-interface-manager/usb-monitor.log" ]; then
    LAST_LOG=$(tail -n 1 /home/acer/network-interface-manager/usb-monitor.log 2>/dev/null)
    echo "✅ USB monitoring log active"
    echo "   Last entry: $LAST_LOG"
else
    echo "❌ USB monitoring log not found"
fi

# Check if USB interface is being monitored
if ip link show usb-tether >/dev/null 2>&1; then
    echo "✅ USB tethering interface 'usb-tether' is active"
    USB_IP=$(ip addr show usb-tether | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
    echo "   IP Address: $USB_IP"
else
    echo "⚠️  USB tethering interface 'usb-tether' not found"
fi

echo ""
echo "🔄 Reboot Simulation Test:"
echo "-------------------------"
echo "To test auto-start after reboot:"
echo "1. Stop services: sudo systemctl stop network-manager.service usb-monitor.service"
echo "2. Start services: sudo systemctl start network-manager.service usb-monitor.service"
echo "3. Or reboot system: sudo reboot"

echo ""
echo "📚 Service Management Commands:"
echo "==============================="
echo "• View web service logs: journalctl -u network-manager.service -f"
echo "• View USB monitor logs: journalctl -u usb-monitor.service -f"
echo "• Restart web service: sudo systemctl restart network-manager.service"
echo "• Restart USB monitor: sudo systemctl restart usb-monitor.service"
echo "• Stop all services: sudo systemctl stop network-manager.service usb-monitor.service"
echo "• Start all services: sudo systemctl start network-manager.service usb-monitor.service"
echo "• Disable auto-start: sudo systemctl disable network-manager.service usb-monitor.service"

echo ""
if [ "$NETWORK_ENABLED" = "enabled" ] && [ "$USB_ENABLED" = "enabled" ] && [ "$NETWORK_ACTIVE" = "active" ] && [ "$USB_ACTIVE" = "active" ]; then
    echo "🎉 SystemD Integration: SUCCESSFUL"
    echo "   All services are enabled and running"
    echo "   System will auto-start services on reboot"
else
    echo "⚠️  SystemD Integration: INCOMPLETE"
    echo "   Some services may not start automatically on reboot"
fi