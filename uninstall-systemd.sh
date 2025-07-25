#!/bin/bash

# SystemD Uninstall Script for Network Interface Manager
# Removes systemd services and stops automatic startup

echo "🗑️  Network Interface Manager - SystemD Uninstall"
echo "================================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ This script needs to be run as root for systemd operations"
    echo "   Please run: sudo ./uninstall-systemd.sh"
    exit 1
fi

SYSTEMD_DIR="/etc/systemd/system"

echo "🛑 Stopping services..."

# Stop services
systemctl stop network-manager.service 2>/dev/null
if [ $? -eq 0 ]; then
    echo "   ✅ network-manager.service stopped"
else
    echo "   ⚠️  network-manager.service was not running"
fi

systemctl stop usb-monitor.service 2>/dev/null
if [ $? -eq 0 ]; then
    echo "   ✅ usb-monitor.service stopped"
else
    echo "   ⚠️  usb-monitor.service was not running"
fi

echo ""
echo "🚫 Disabling auto-start..."

# Disable services
systemctl disable network-manager.service 2>/dev/null
if [ $? -eq 0 ]; then
    echo "   ✅ network-manager.service disabled"
else
    echo "   ⚠️  network-manager.service was not enabled"
fi

systemctl disable usb-monitor.service 2>/dev/null
if [ $? -eq 0 ]; then
    echo "   ✅ usb-monitor.service disabled"
else
    echo "   ⚠️  usb-monitor.service was not enabled"
fi

echo ""
echo "🗂️  Removing service files..."

# Remove service files
if [ -f "$SYSTEMD_DIR/network-manager.service" ]; then
    rm "$SYSTEMD_DIR/network-manager.service"
    echo "   ✅ network-manager.service file removed"
else
    echo "   ⚠️  network-manager.service file not found"
fi

if [ -f "$SYSTEMD_DIR/usb-monitor.service" ]; then
    rm "$SYSTEMD_DIR/usb-monitor.service"
    echo "   ✅ usb-monitor.service file removed"
else
    echo "   ⚠️  usb-monitor.service file not found"
fi

echo ""
echo "🔄 Reloading systemd daemon..."
systemctl daemon-reload
if [ $? -eq 0 ]; then
    echo "   ✅ SystemD daemon reloaded"
else
    echo "   ❌ Failed to reload systemd daemon"
fi

echo ""
echo "📊 Final Status:"
echo "==============="

# Check if services still exist
if systemctl list-unit-files | grep -q "network-manager.service"; then
    echo "❌ network-manager.service still exists"
else
    echo "✅ network-manager.service removed"
fi

if systemctl list-unit-files | grep -q "usb-monitor.service"; then
    echo "❌ usb-monitor.service still exists"
else
    echo "✅ usb-monitor.service removed"
fi

echo ""
echo "📝 Manual Operations:"
echo "===================="
echo "To manually start services (without auto-start):"
echo "• Web interface: cd /home/acer/network-interface-manager && python3 app.py"
echo "• USB monitor: cd /home/acer/network-interface-manager && ./usb-monitor.sh monitor"
echo ""
echo "To reinstall systemd integration:"
echo "• Run: sudo ./install-systemd.sh"

echo ""
echo "✨ SystemD services uninstalled successfully!"
echo "   Services will no longer start automatically on boot."