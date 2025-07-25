#!/usr/bin/env python3
"""
Network Interface Manager Web Application
A comprehensive web interface for managing network interfaces including LAN, WiFi, and USB tethering
"""

from flask import Flask, render_template, jsonify, request, send_from_directory
import subprocess
import os
import json
import re
import time
import threading
from datetime import datetime
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

class NetworkManager:
    def __init__(self):
        self.interface_stats_cache = {}
        self.last_update = 0
        self.cache_duration = 2  # seconds
    
    def run_command(self, cmd, timeout=10):
        """Execute shell command and return output"""
        try:
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
            return {
                'success': result.returncode == 0,
                'output': result.stdout.strip(),
                'error': result.stderr.strip(),
                'returncode': result.returncode
            }
        except subprocess.TimeoutExpired:
            return {'success': False, 'output': '', 'error': 'Command timeout', 'returncode': -1}
        except Exception as e:
            return {'success': False, 'output': '', 'error': str(e), 'returncode': -1}

    def get_network_interfaces(self):
        """Get all network interfaces with their details"""
        current_time = time.time()
        
        # Use cache if recent
        if current_time - self.last_update < self.cache_duration:
            return self.interface_stats_cache
        
        interfaces = {}
        
        # Get interface list
        result = self.run_command("ip link show")
        if not result['success']:
            return interfaces
        
        # Parse interfaces
        for line in result['output'].split('\n'):
            if ':' in line and not line.startswith(' '):
                parts = line.split(':')
                if len(parts) >= 2:
                    iface_num = parts[0].strip()
                    iface_name = parts[1].strip().split('@')[0]
                    
                    # Skip virtual docker interfaces but keep important ones
                    if 'veth' in iface_name or 'br-' in iface_name:
                        continue
                    
                    # Get interface details
                    flags = re.search(r'<([^>]+)>', line)
                    flags_list = flags.group(1).split(',') if flags else []
                    
                    interfaces[iface_name] = {
                        'name': iface_name,
                        'index': iface_num,
                        'flags': flags_list,
                        'state': 'UP' if 'UP' in flags_list else 'DOWN',
                        'type': self.get_interface_type(iface_name),
                        'addresses': [],
                        'stats': {},
                        'mtu': self.get_interface_mtu(iface_name),
                        'speed': self.get_interface_speed(iface_name),
                        'carrier': self.get_interface_carrier(iface_name)
                    }
        
        # Get IP addresses
        addr_result = self.run_command("ip addr show")
        if addr_result['success']:
            current_iface = None
            for line in addr_result['output'].split('\n'):
                if ':' in line and not line.startswith(' '):
                    parts = line.split(':')
                    if len(parts) >= 2:
                        current_iface = parts[1].strip().split('@')[0]
                elif line.strip().startswith('inet') and current_iface in interfaces:
                    addr_match = re.search(r'inet6?\s+([^\s]+)', line)
                    if addr_match:
                        addr_info = {
                            'address': addr_match.group(1),
                            'type': 'IPv6' if 'inet6' in line else 'IPv4'
                        }
                        
                        # Extract scope for IPv6
                        if 'scope' in line:
                            scope_match = re.search(r'scope\s+(\w+)', line)
                            if scope_match:
                                addr_info['scope'] = scope_match.group(1)
                        
                        interfaces[current_iface]['addresses'].append(addr_info)
        
        # Get interface statistics
        for iface_name in interfaces:
            stats = self.get_interface_stats(iface_name)
            interfaces[iface_name]['stats'] = stats
            
            # Get gateway information
            interfaces[iface_name]['gateway'] = self.get_interface_gateway(iface_name)
            
            # Get DNS information
            interfaces[iface_name]['dns'] = self.get_interface_dns(iface_name)
        
        self.interface_stats_cache = interfaces
        self.last_update = current_time
        return interfaces

    def get_interface_type(self, iface_name):
        """Determine interface type"""
        if iface_name == 'lo':
            return 'loopback'
        elif iface_name.startswith('enp') or iface_name.startswith('eth'):
            return 'ethernet'
        elif iface_name.startswith('wlp') or iface_name.startswith('wlan'):
            return 'wireless'
        elif iface_name.startswith('docker') or iface_name.startswith('br-'):
            return 'bridge'
        elif 'tailscale' in iface_name or iface_name.startswith('tun'):
            return 'vpn'
        elif iface_name.startswith('usb') or iface_name.startswith('rndis') or 'usb' in iface_name.lower():
            return 'usb_tethering'
        elif iface_name.startswith('ppp'):
            return 'ppp'
        else:
            return 'other'

    def get_interface_mtu(self, iface_name):
        """Get interface MTU"""
        try:
            result = self.run_command(f"cat /sys/class/net/{iface_name}/mtu")
            if result['success']:
                return int(result['output'])
        except:
            pass
        return None

    def get_interface_speed(self, iface_name):
        """Get interface speed"""
        try:
            result = self.run_command(f"cat /sys/class/net/{iface_name}/speed 2>/dev/null")
            if result['success'] and result['output'].isdigit():
                speed = int(result['output'])
                if speed > 0:
                    return f"{speed} Mbps"
        except:
            pass
        return "Unknown"

    def get_interface_carrier(self, iface_name):
        """Get interface carrier status"""
        try:
            result = self.run_command(f"cat /sys/class/net/{iface_name}/carrier 2>/dev/null")
            if result['success']:
                return result['output'] == '1'
        except:
            pass
        return None

    def get_interface_stats(self, iface_name):
        """Get interface statistics"""
        stats = {}
        try:
            # Get RX/TX bytes
            rx_result = self.run_command(f"cat /sys/class/net/{iface_name}/statistics/rx_bytes 2>/dev/null")
            tx_result = self.run_command(f"cat /sys/class/net/{iface_name}/statistics/tx_bytes 2>/dev/null")
            
            if rx_result['success'] and tx_result['success']:
                stats['rx_bytes'] = int(rx_result['output']) if rx_result['output'].isdigit() else 0
                stats['tx_bytes'] = int(tx_result['output']) if tx_result['output'].isdigit() else 0
                
                # Format human readable
                stats['rx_formatted'] = self.format_bytes(stats['rx_bytes'])
                stats['tx_formatted'] = self.format_bytes(stats['tx_bytes'])
            
            # Get packet statistics
            rx_packets = self.run_command(f"cat /sys/class/net/{iface_name}/statistics/rx_packets 2>/dev/null")
            tx_packets = self.run_command(f"cat /sys/class/net/{iface_name}/statistics/tx_packets 2>/dev/null")
            
            if rx_packets['success'] and tx_packets['success']:
                stats['rx_packets'] = int(rx_packets['output']) if rx_packets['output'].isdigit() else 0
                stats['tx_packets'] = int(tx_packets['output']) if tx_packets['output'].isdigit() else 0
            
            # Get error statistics
            rx_errors = self.run_command(f"cat /sys/class/net/{iface_name}/statistics/rx_errors 2>/dev/null")
            tx_errors = self.run_command(f"cat /sys/class/net/{iface_name}/statistics/tx_errors 2>/dev/null")
            
            if rx_errors['success'] and tx_errors['success']:
                stats['rx_errors'] = int(rx_errors['output']) if rx_errors['output'].isdigit() else 0
                stats['tx_errors'] = int(tx_errors['output']) if tx_errors['output'].isdigit() else 0
                
        except Exception as e:
            logger.error(f"Error getting stats for {iface_name}: {e}")
            
        return stats

    def get_interface_gateway(self, iface_name):
        """Get gateway for interface"""
        result = self.run_command(f"ip route show dev {iface_name} | grep default")
        if result['success'] and result['output']:
            for line in result['output'].split('\n'):
                if 'default via' in line:
                    gateway = line.split('via')[1].split()[0]
                    return gateway
        return None

    def get_interface_dns(self, iface_name):
        """Get DNS servers for interface"""
        dns_servers = []
        
        # Check systemd-resolved
        result = self.run_command(f"systemd-resolve --status {iface_name} 2>/dev/null")
        if result['success']:
            for line in result['output'].split('\n'):
                if 'DNS Servers:' in line:
                    dns = line.split(':')[1].strip()
                    if dns:
                        dns_servers.append(dns)
                elif line.strip() and re.match(r'^\s*\d+\.\d+\.\d+\.\d+', line):
                    dns_servers.append(line.strip())
        
        # Fallback to resolv.conf
        if not dns_servers:
            result = self.run_command("cat /etc/resolv.conf")
            if result['success']:
                for line in result['output'].split('\n'):
                    if line.startswith('nameserver'):
                        dns = line.split()[1]
                        dns_servers.append(dns)
        
        return dns_servers

    def format_bytes(self, bytes_val):
        """Format bytes to human readable format"""
        if bytes_val == 0:
            return "0 B"
        
        units = ['B', 'KB', 'MB', 'GB', 'TB']
        i = 0
        while bytes_val >= 1024 and i < len(units) - 1:
            bytes_val /= 1024
            i += 1
        
        return f"{bytes_val:.2f} {units[i]}"

    def set_interface_state(self, iface_name, state):
        """Set interface up or down"""
        if state not in ['up', 'down']:
            return {'success': False, 'error': 'Invalid state. Use "up" or "down"'}
        
        result = self.run_command(f"sudo ip link set {iface_name} {state}")
        if result['success']:
            return {'success': True, 'message': f'Interface {iface_name} set {state}'}
        else:
            return {'success': False, 'error': result['error']}

    def set_interface_ip(self, iface_name, ip_address, netmask=None):
        """Set IP address for interface"""
        if netmask:
            address = f"{ip_address}/{netmask}"
        else:
            address = ip_address
            
        # Remove existing IP addresses
        self.run_command(f"sudo ip addr flush dev {iface_name}")
        
        # Add new IP address
        result = self.run_command(f"sudo ip addr add {address} dev {iface_name}")
        if result['success']:
            return {'success': True, 'message': f'IP address {address} set on {iface_name}'}
        else:
            return {'success': False, 'error': result['error']}

    def get_wireless_networks(self, iface_name):
        """Scan for wireless networks"""
        if not iface_name.startswith('wl'):
            return {'success': False, 'error': 'Not a wireless interface'}
        
        result = self.run_command(f"sudo iwlist {iface_name} scan")
        if not result['success']:
            return {'success': False, 'error': result['error']}
        
        networks = []
        current_network = {}
        
        for line in result['output'].split('\n'):
            line = line.strip()
            if 'Cell' in line and 'Address:' in line:
                if current_network:
                    networks.append(current_network)
                current_network = {'bssid': line.split('Address: ')[1]}
            elif 'ESSID:' in line:
                essid = line.split('ESSID:')[1].strip('"')
                current_network['ssid'] = essid
            elif 'Quality=' in line:
                quality_match = re.search(r'Quality=(\d+/\d+)', line)
                if quality_match:
                    current_network['quality'] = quality_match.group(1)
                signal_match = re.search(r'Signal level=(-?\d+)', line)
                if signal_match:
                    current_network['signal'] = f"{signal_match.group(1)} dBm"
            elif 'Encryption key:' in line:
                current_network['encrypted'] = 'on' in line.lower()
        
        if current_network:
            networks.append(current_network)
        
        return {'success': True, 'networks': networks}

    def get_system_info(self):
        """Get system network information"""
        info = {}
        
        # Get hostname
        result = self.run_command("hostname")
        if result['success']:
            info['hostname'] = result['output']
        
        # Get kernel version
        result = self.run_command("uname -r")
        if result['success']:
            info['kernel'] = result['output']
        
        # Get uptime
        result = self.run_command("uptime -p")
        if result['success']:
            info['uptime'] = result['output']
        
        # Get default route
        result = self.run_command("ip route show default")
        if result['success']:
            info['default_route'] = result['output']
        
        return info

# Initialize network manager
network_manager = NetworkManager()

@app.route('/')
def index():
    """Main dashboard page"""
    return render_template('index.html')

@app.route('/api/interfaces')
def api_interfaces():
    """API endpoint to get all network interfaces"""
    interfaces = network_manager.get_network_interfaces()
    return jsonify(interfaces)

@app.route('/api/interface/<iface_name>')
def api_interface_detail(iface_name):
    """API endpoint to get specific interface details"""
    interfaces = network_manager.get_network_interfaces()
    if iface_name in interfaces:
        return jsonify(interfaces[iface_name])
    else:
        return jsonify({'error': 'Interface not found'}), 404

@app.route('/api/interface/<iface_name>/state', methods=['POST'])
def api_set_interface_state(iface_name):
    """API endpoint to set interface state"""
    data = request.get_json()
    if not data or 'state' not in data:
        return jsonify({'error': 'State parameter required'}), 400
    
    result = network_manager.set_interface_state(iface_name, data['state'])
    return jsonify(result)

@app.route('/api/interface/<iface_name>/ip', methods=['POST'])
def api_set_interface_ip(iface_name):
    """API endpoint to set interface IP address"""
    data = request.get_json()
    if not data or 'ip' not in data:
        return jsonify({'error': 'IP address required'}), 400
    
    result = network_manager.set_interface_ip(
        iface_name, 
        data['ip'], 
        data.get('netmask')
    )
    return jsonify(result)

@app.route('/api/interface/<iface_name>/scan')
def api_scan_wireless(iface_name):
    """API endpoint to scan for wireless networks"""
    result = network_manager.get_wireless_networks(iface_name)
    return jsonify(result)

@app.route('/api/system')
def api_system_info():
    """API endpoint to get system information"""
    info = network_manager.get_system_info()
    return jsonify(info)

@app.route('/static/<path:filename>')
def static_files(filename):
    """Serve static files"""
    return send_from_directory('static', filename)

if __name__ == '__main__':
    print("🌐 Network Interface Manager")
    print("=" * 50)
    print("Starting web server on port 5020...")
    print("Access the interface at: http://localhost:5020")
    print("=" * 50)
    
    # Check if running as root for some operations
    if os.geteuid() != 0:
        print("⚠️  Warning: Not running as root. Some operations may require sudo.")
    
    app.run(host='0.0.0.0', port=5020, debug=True)