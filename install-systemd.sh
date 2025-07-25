#!/bin/bash

# SystemD Integration Script for Network Interface Manager
# Installs and configures systemd services for automatic startup

echo "🔧 Network Interface Manager - SystemD Integration"
echo "=================================================="
echo ""

# Check if running as root for systemd operations
if [ "$EUID" -ne 0 ]; then
    echo "❌ This script needs to be run as root for systemd integration"
    echo "   Please run: sudo ./install-systemd.sh"
    exit 1
fi

SCRIPT_DIR="/home/acer/network-interface-manager"
SYSTEMD_DIR="/etc/systemd/system"

echo "📋 Installing systemd services..."

# Install web application service
echo "1. Installing Network Manager Web Service..."
cp "$SCRIPT_DIR/network-manager.service" "$SYSTEMD_DIR/"
if [ $? -eq 0 ]; then
    echo "   ✅ network-manager.service installed"
else
    echo "   ❌ Failed to install network-manager.service"
    exit 1
fi

# Install USB monitoring service
echo "2. Installing USB Monitor Service..."
cp "$SCRIPT_DIR/usb-monitor.service" "$SYSTEMD_DIR/"
if [ $? -eq 0 ]; then
    echo "   ✅ usb-monitor.service installed"
else
    echo "   ❌ Failed to install usb-monitor.service"
    exit 1
fi

# Reload systemd daemon
echo "3. Reloading systemd daemon..."
systemctl daemon-reload
if [ $? -eq 0 ]; then
    echo "   ✅ SystemD daemon reloaded"
else
    echo "   ❌ Failed to reload systemd daemon"
    exit 1
fi

# Enable services for auto-start
echo "4. Enabling services for auto-start..."

systemctl enable network-manager.service
if [ $? -eq 0 ]; then
    echo "   ✅ network-manager.service enabled"
else
    echo "   ❌ Failed to enable network-manager.service"
fi

systemctl enable usb-monitor.service
if [ $? -eq 0 ]; then
    echo "   ✅ usb-monitor.service enabled"
else
    echo "   ❌ Failed to enable usb-monitor.service"
fi

echo ""
echo "🚀 Starting services..."

# Start web application service
systemctl start network-manager.service
if [ $? -eq 0 ]; then
    echo "   ✅ network-manager.service started"
else
    echo "   ❌ Failed to start network-manager.service"
    echo "   Check logs: journalctl -u network-manager.service -f"
fi

# Start USB monitoring service
systemctl start usb-monitor.service
if [ $? -eq 0 ]; then
    echo "   ✅ usb-monitor.service started"
else
    echo "   ❌ Failed to start usb-monitor.service"
    echo "   Check logs: journalctl -u usb-monitor.service -f"
fi

echo ""
echo "📊 Service Status:"
echo "=================="

echo "Network Manager Web Service:"
systemctl is-active network-manager.service
systemctl is-enabled network-manager.service

echo ""
echo "USB Monitor Service:"
systemctl is-active usb-monitor.service
systemctl is-enabled usb-monitor.service

echo ""
echo "🔍 Quick Status Check:"
echo "====================="

# Check if web interface is accessible
sleep 5
if curl -s http://localhost:5020/api/interfaces >/dev/null 2>&1; then
    echo "✅ Web interface accessible at: http://localhost:5020"
else
    echo "❌ Web interface not accessible"
    echo "   Check service status: systemctl status network-manager.service"
fi

# Check USB monitoring
if systemctl is-active --quiet usb-monitor.service; then
    echo "✅ USB monitoring service is running"
else
    echo "❌ USB monitoring service not running"
    echo "   Check service status: systemctl status usb-monitor.service"
fi

echo ""
echo "📚 Useful Commands:"
echo "=================="
echo "• Check web service status: systemctl status network-manager.service"
echo "• Check USB monitor status: systemctl status usb-monitor.service"
echo "• View web service logs: journalctl -u network-manager.service -f"
echo "• View USB monitor logs: journalctl -u usb-monitor.service -f"
echo "• Restart web service: systemctl restart network-manager.service"
echo "• Restart USB monitor: systemctl restart usb-monitor.service"
echo "• Stop all services: systemctl stop network-manager.service usb-monitor.service"
echo "• Disable auto-start: systemctl disable network-manager.service usb-monitor.service"

echo ""
echo "✨ SystemD integration completed!"
echo "   Services will now start automatically on system boot."
echo "   Web interface: http://localhost:5020"