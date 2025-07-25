# USB Tethering Auto-Configuration Guide

## Overview
The Network Interface Manager now includes comprehensive USB tethering support with automatic detection, configuration, and monitoring capabilities.

## Features

### 1. Automatic Interface Detection
- **Enhanced Type Detection**: Automatically detects `enx*` interfaces as USB tethering
- **RNDIS Support**: Recognizes RNDIS-based USB tethering devices
- **Multi-vendor Support**: Works with various phone manufacturers (Sony, Samsung, etc.)

### 2. Auto-Configuration Scripts

#### configure-usb-tethering.sh
```bash
./configure-usb-tethering.sh
```
- Detects USB tethering interfaces
- Configures IP addresses via DHCP
- Sets up network connectivity
- Tests internet connection

#### setup-load-balancing.sh
```bash
./setup-load-balancing.sh
```
- Configures dual-WAN load balancing
- Balances traffic between LAN and USB tethering
- Sets up proper routing tables
- Ensures redundancy

#### usb-monitor.sh
```bash
# Check for changes once
./usb-monitor.sh check

# Monitor continuously
./usb-monitor.sh monitor

# Show current status
./usb-monitor.sh status

# Force reconfiguration
./usb-monitor.sh force-reconfig
```

### 3. Web Interface Controls

#### New Buttons Added:
- **Configure USB Tethering**: Automatically detect and configure USB interfaces
- **Setup Load Balancing**: Configure dual-WAN load balancing
- **Monitor USB Tethering**: Check for changes and reconfigure if needed

### 4. API Endpoints

#### USB Tethering Configuration
```bash
curl -X POST http://localhost:5020/api/usb-tethering/configure
```

#### Load Balancing Setup
```bash
curl -X POST http://localhost:5020/api/usb-tethering/setup-load-balancing
```

#### USB Monitoring
```bash
curl -X POST http://localhost:5020/api/usb-tethering/monitor
```

## Usage Scenarios

### Scenario 1: Phone Change
When you change phones or USB tethering devices:

1. **Automatic Detection**: New interface (e.g., `enx0e8e457defe7`) is automatically detected
2. **Web Interface**: Click "Configure USB Tethering" button
3. **Manual**: Run `./configure-usb-tethering.sh`

### Scenario 2: IP Address Changes
When phone gets new IP address:

1. **Web Interface**: Click "Monitor USB Tethering" button
2. **Manual**: Run `./usb-monitor.sh check`
3. **Automatic**: Set up continuous monitoring with `./usb-monitor.sh monitor`

### Scenario 3: Load Balancing Issues
When routing needs reconfiguration:

1. **Web Interface**: Click "Setup Load Balancing" button
2. **Manual**: Run `./setup-load-balancing.sh`
3. **Check Health**: Use "Check Routing" button

## Interface Types Detected

The system now recognizes these USB tethering patterns:
- `usb-*` (traditional USB interface names)
- `enx*` (USB Ethernet interfaces with MAC-based naming)
- `rndis*` (RNDIS-based interfaces)
- Interfaces with "usb" in the name

## Current Configuration

### Active Interface
- **Name**: `enx0e8e457defe7`
- **Type**: `usb_tethering` ✅
- **IP**: `192.168.42.52/24`
- **Gateway**: `192.168.42.129`
- **Status**: Active and configured

### Load Balancing
- **LAN**: `enp0s25` (192.168.100.50) via 192.168.100.1
- **USB**: `enx0e8e457defe7` (192.168.42.52) via 192.168.42.129
- **Mode**: Dual-WAN with equal weight routing

## Troubleshooting

### Interface Not Detected
```bash
# Check system logs
sudo dmesg | grep -i usb | tail -10

# Check interface list
ip link show | grep -E "(usb|enx)"

# Force refresh
./usb-monitor.sh force-reconfig
```

### Routing Issues
```bash
# Check routing table
ip route

# Check routing health
curl http://localhost:5020/api/routing/health

# Fix routing
curl -X POST http://localhost:5020/api/routing/fix
```

### Connectivity Problems
```bash
# Test interface connectivity
curl -X POST http://localhost:5020/api/interface/enx0e8e457defe7/test

# Manual connectivity test
ping -I enx0e8e457defe7 8.8.8.8
```

## Monitoring and Logs

### Log Files
- **USB Monitor**: `usb-monitor.log`
- **Flask App**: Console output
- **System**: `/var/log/syslog`

### Continuous Monitoring
```bash
# Start background monitoring
nohup ./usb-monitor.sh monitor > monitor.log 2>&1 &

# Check monitoring status
tail -f monitor.log
```

## Best Practices

1. **Regular Monitoring**: Use the web interface monitoring button regularly
2. **Log Checking**: Monitor `usb-monitor.log` for automatic changes
3. **Backup Configuration**: Keep routing configuration backups
4. **Test Connectivity**: Regularly test both LAN and USB connections

## Integration with Mihomo

The USB tethering system works seamlessly with Mihomo proxy:
- **TUN Interface**: `Meta` interface remains active
- **Load Balancing**: Traffic distributed across LAN and USB
- **Failover**: Automatic failover if one connection fails
- **Proxy Routing**: Mihomo routes traffic through available connections