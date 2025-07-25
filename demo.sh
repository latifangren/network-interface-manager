#!/bin/bash

# Network Interface Manager Demo Script

echo "🌐 Network Interface Manager - Demo"
echo "===================================="
echo ""

# Check current network interfaces
echo "📡 Current Network Interfaces:"
echo "------------------------------"
ip link show | grep -E "^[0-9]+:" | while read line; do
    iface_name=$(echo "$line" | cut -d: -f2 | sed 's/^ *//' | cut -d@ -f1)
    state=$(echo "$line" | grep -o "state [A-Z]*" | cut -d' ' -f2)
    echo "  • $iface_name ($state)"
done

echo ""
echo "📊 Network Statistics:"
echo "---------------------"
total_rx=0
total_tx=0

for iface in $(ip link show | grep -E "^[0-9]+:" | cut -d: -f2 | sed 's/^ *//' | cut -d@ -f1); do
    if [ -f "/sys/class/net/$iface/statistics/rx_bytes" ]; then
        rx=$(cat /sys/class/net/$iface/statistics/rx_bytes 2>/dev/null || echo 0)
        tx=$(cat /sys/class/net/$iface/statistics/tx_bytes 2>/dev/null || echo 0)
        total_rx=$((total_rx + rx))
        total_tx=$((total_tx + tx))
    fi
done

echo "  • Total Downloaded: $(numfmt --to=iec $total_rx)B"
echo "  • Total Uploaded: $(numfmt --to=iec $total_tx)B"

echo ""
echo "🚀 Starting Network Interface Manager..."
echo "   Web Interface: http://localhost:5020"
echo "   Features Available:"
echo "     ✓ Real-time interface monitoring"
echo "     ✓ Enable/Disable interfaces"
echo "     ✓ IP address configuration"
echo "     ✓ Wireless network scanning"
echo "     ✓ Detailed statistics and information"
echo ""
echo "Press Ctrl+C to stop the server"
echo "===================================="

# Start the application
exec ./start.sh