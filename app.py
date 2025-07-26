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
        elif iface_name == 'Meta' or iface_name.startswith('mihomo'):
            return 'mihomo_tun'
        elif 'tailscale' in iface_name or iface_name.startswith('tun'):
            return 'vpn'
        elif (iface_name.startswith('usb') or iface_name.startswith('rndis') or 
              'usb' in iface_name.lower() or iface_name.startswith('enx')):
            # Check if it's actually a USB tethering interface
            if self.is_usb_tethering_interface(iface_name):
                return 'usb_tethering'
            elif iface_name.startswith('enx'):
                return 'usb_tethering'  # enx interfaces are typically USB ethernet
            else:
                return 'usb_tethering'
        elif iface_name.startswith('ppp'):
            return 'ppp'
        else:
            return 'other'

    def is_usb_tethering_interface(self, iface_name):
        """Check if interface is USB tethering by examining system info"""
        try:
            # Check if interface is associated with USB device
            usb_check = self.run_command(f"readlink /sys/class/net/{iface_name}/device 2>/dev/null")
            if usb_check['success'] and 'usb' in usb_check['output']:
                return True
            
            # Check dmesg for RNDIS or USB tethering mentions
            dmesg_check = self.run_command(f"dmesg | grep -i '{iface_name}' | grep -i 'rndis\\|usb'")
            if dmesg_check['success'] and dmesg_check['output']:
                return True
            
            # Check if interface name pattern suggests USB tethering
            if (iface_name.startswith('enx') or 'usb' in iface_name.lower() or 
                iface_name.startswith('rndis')):
                return True
                
        except Exception as e:
            logger.error(f"Error checking USB tethering for {iface_name}: {e}")
        
        return False

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
        # First try to get interface-specific default route
        result = self.run_command(f"ip route show dev {iface_name} | grep default")
        if result['success'] and result['output']:
            for line in result['output'].split('\n'):
                if 'default via' in line:
                    gateway = line.split('via')[1].split()[0]
                    return gateway
        
        # If no interface-specific route, check for load balancing configuration
        result = self.run_command("ip route show default")
        if result['success'] and result['output']:
            lines = result['output'].split('\n')
            for line in lines:
                # Check for nexthop configuration with this interface
                if 'nexthop via' in line and f'dev {iface_name}' in line:
                    # Extract gateway from nexthop line
                    parts = line.split()
                    for i, part in enumerate(parts):
                        if part == 'via' and i + 1 < len(parts):
                            return parts[i + 1]
                # Check for simple default via configuration
                elif 'default via' in line and f'dev {iface_name}' in line:
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
    def test_interface_connectivity(self, iface_name):
        """Test interface connectivity and routing"""
        result = {
            'interface': iface_name,
            'ping_gateway': False,
            'ping_dns': False,
            'http_test': False,
            'public_ip': None,
            'gateway': None,
            'errors': []
        }
        
        try:
            # Get interface gateway
            gateway = self.get_interface_gateway(iface_name)
            result['gateway'] = gateway
            
            if gateway:
                # Test gateway ping
                ping_result = self.run_command(f"ping -c 2 -W 3 -I {iface_name} {gateway}")
                result['ping_gateway'] = ping_result['success']
                if not ping_result['success']:
                    result['errors'].append(f"Gateway ping failed: {ping_result['error']}")
            
            # Test DNS ping
            dns_result = self.run_command(f"ping -c 2 -W 3 -I {iface_name} 8.8.8.8")
            result['ping_dns'] = dns_result['success']
            if not dns_result['success']:
                result['errors'].append(f"DNS ping failed: {dns_result['error']}")
            
            # Test HTTP connectivity and get public IP
            http_result = self.run_command(f"curl -s --connect-timeout 10 --interface {iface_name} http://httpbin.org/ip")
            if http_result['success']:
                try:
                    import json
                    ip_data = json.loads(http_result['output'])
                    result['public_ip'] = ip_data.get('origin', 'Unknown')
                    result['http_test'] = True
                except:
                    result['errors'].append("Failed to parse HTTP response")
            else:
                result['errors'].append(f"HTTP test failed: {http_result['error']}")
                
        except Exception as e:
            result['errors'].append(f"Test error: {str(e)}")
        
        return result

    def check_routing_health(self):
        """Check routing table health and identify issues"""
        issues = []
        suggestions = []
        
        # Get routing table
        route_result = self.run_command("ip route show")
        if not route_result['success']:
            return {'issues': ['Cannot read routing table'], 'suggestions': []}
        
        routes = route_result['output'].split('\n')
        default_routes = [r for r in routes if r.startswith('default')]
        
        # Check for incomplete default routes (but exclude load balancing configuration)
        incomplete_routes = []
        nexthop_routes = [r for r in routes if 'nexthop' in r]
        
        for route in default_routes:
            route_stripped = route.strip()
            # Only consider it incomplete if it's just "default" and there are no nexthop routes
            if route_stripped == 'default' and not nexthop_routes:
                incomplete_routes.append(route)
            # Also check for other incomplete patterns (default without via or nexthop)
            elif route_stripped != 'default' and 'via' not in route and 'nexthop' not in route and route_stripped != '':
                incomplete_routes.append(route)
        
        if incomplete_routes:
            issues.append(f"Found {len(incomplete_routes)} incomplete default route(s)")
            suggestions.append("Remove incomplete routes with: sudo ip route del default")
        
        # Check for too many default routes (but account for load balancing)
        if len(default_routes) > 3 and not nexthop_routes:
            issues.append(f"Too many default routes ({len(default_routes)})")
            suggestions.append("Consider cleaning up redundant routes")
        
        # Check for load balancing route
        if not nexthop_routes and len(default_routes) > 1:
            issues.append("Multiple default routes without load balancing")
            suggestions.append("Configure proper load balancing with nexthop")
        
        # Check gateway connectivity
        gateways = []
        
        # Extract gateways from both regular default routes and nexthop routes
        for route in default_routes:
            if 'via' in route:
                parts = route.split()
                for i, part in enumerate(parts):
                    if part == 'via' and i + 1 < len(parts):
                        gateways.append(parts[i + 1])
        
        # Extract gateways from nexthop routes
        for route in nexthop_routes:
            if 'via' in route:
                parts = route.split()
                for i, part in enumerate(parts):
                    if part == 'via' and i + 1 < len(parts):
                        gateways.append(parts[i + 1])
        
        for gw in set(gateways):
            ping_result = self.run_command(f"ping -c 1 -W 2 {gw}")
            if not ping_result['success']:
                issues.append(f"Gateway {gw} is not reachable")
                suggestions.append(f"Check connection to gateway {gw}")
        
        return {
            'issues': issues,
            'suggestions': suggestions,
            'default_routes_count': len(default_routes),
            'load_balancing_active': len(nexthop_routes) > 0
        }
    def auto_fix_routing(self):
        """Automatically detect and fix routing issues"""
        result = {
            'success': False,
            'actions_taken': [],
            'errors': [],
            'before': {},
            'after': {}
        }
        
        try:
            # Get current routing state
            health_before = self.check_routing_health()
            result['before'] = health_before
            
            # Get current routes
            route_result = self.run_command("ip route show")
            if not route_result['success']:
                result['errors'].append("Cannot read routing table")
                return result
            
            routes = route_result['output'].split('\n')
            default_routes = [r for r in routes if r.startswith('default')]
            
            # Remove incomplete default routes
            incomplete_routes = [r for r in default_routes if r.strip() == 'default']
            if incomplete_routes:
                remove_result = self.run_command("sudo ip route del default")
                if remove_result['success']:
                    result['actions_taken'].append("Removed incomplete default routes")
                else:
                    result['errors'].append(f"Failed to remove incomplete routes: {remove_result['error']}")
            
            # Detect available gateways
            gateways = self.detect_available_gateways()
            
            if len(gateways) >= 2:
                # Setup load balancing with detected gateways
                nexthops = []
                for gw_info in gateways:
                    nexthops.append(f"nexthop via {gw_info['gateway']} dev {gw_info['interface']} weight 1")
                
                lb_command = f"sudo ip route add default {' '.join(nexthops)}"
                lb_result = self.run_command(lb_command)
                
                if lb_result['success']:
                    result['actions_taken'].append(f"Configured load balancing with {len(gateways)} gateways")
                    result['success'] = True
                else:
                    result['errors'].append(f"Failed to setup load balancing: {lb_result['error']}")
            
            elif len(gateways) == 1:
                # Setup single default route
                gw_info = gateways[0]
                single_route_cmd = f"sudo ip route add default via {gw_info['gateway']} dev {gw_info['interface']}"
                single_result = self.run_command(single_route_cmd)
                
                if single_result['success']:
                    result['actions_taken'].append(f"Configured single default route via {gw_info['interface']}")
                    result['success'] = True
                else:
                    result['errors'].append(f"Failed to setup default route: {single_result['error']}")
            
            else:
                result['errors'].append("No available gateways detected")
            
            # Get routing state after fix
            health_after = self.check_routing_health()
            result['after'] = health_after
            
        except Exception as e:
            result['errors'].append(f"Auto-fix error: {str(e)}")
        
        return result

    def detect_available_gateways(self):
        """Detect available gateways from active interfaces"""
        gateways = []
        
        # Get all UP interfaces
        interfaces = self.get_network_interfaces()
        
        for name, iface in interfaces.items():
            if iface['state'] == 'UP' and iface['type'] not in ['loopback', 'bridge', 'mihomo_tun']:
                # Try to find gateway for this interface
                gateway = self.get_interface_gateway(name)
                
                if not gateway:
                    # Try to detect gateway from network
                    for addr in iface['addresses']:
                        if addr['type'] == 'IPv4' and '/' in addr['address']:
                            ip_addr = addr['address'].split('/')[0]
                            network_parts = ip_addr.split('.')
                            if len(network_parts) == 4:
                                # Try common gateway patterns
                                possible_gateways = [
                                    f"{network_parts[0]}.{network_parts[1]}.{network_parts[2]}.1",
                                    f"{network_parts[0]}.{network_parts[1]}.{network_parts[2]}.254"
                                ]
                                
                                for possible_gw in possible_gateways:
                                    ping_result = self.run_command(f"ping -c 1 -W 2 {possible_gw}")
                                    if ping_result['success']:
                                        gateway = possible_gw
                                        break
                
                if gateway:
                    # Verify gateway is reachable
                    ping_result = self.run_command(f"ping -c 1 -W 2 {gateway}")
                    if ping_result['success']:
                        gateways.append({
                            'interface': name,
                            'gateway': gateway,
                            'type': iface['type']
                        })
        
        return gateways

    def refresh_interface_config(self):
        """Refresh interface configuration and detect changes"""
        result = {
            'success': False,
            'changes_detected': [],
            'new_interfaces': [],
            'changed_ips': [],
            'actions_taken': []
        }
        
        try:
            # Get current interfaces
            old_interfaces = self.interface_stats_cache.copy()
            
            # Force refresh
            self.last_update = 0
            new_interfaces = self.get_network_interfaces()
            
            # Detect new interfaces
            for name in new_interfaces:
                if name not in old_interfaces:
                    result['new_interfaces'].append(name)
                    result['changes_detected'].append(f"New interface detected: {name}")
            
            # Detect IP changes
            for name, new_iface in new_interfaces.items():
                if name in old_interfaces:
                    old_addrs = {addr['address'] for addr in old_interfaces[name].get('addresses', [])}
                    new_addrs = {addr['address'] for addr in new_iface.get('addresses', [])}
                    
                    if old_addrs != new_addrs:
                        result['changed_ips'].append({
                            'interface': name,
                            'old_ips': list(old_addrs),
                            'new_ips': list(new_addrs)
                        })
                        result['changes_detected'].append(f"IP changed on {name}")
            
            # If changes detected, suggest routing refresh
            if result['changes_detected']:
                result['actions_taken'].append("Interface changes detected - routing may need refresh")
                result['success'] = True
            else:
                result['success'] = True
                result['actions_taken'].append("No interface changes detected")
                
        except Exception as e:
            result['errors'] = [f"Refresh error: {str(e)}"]
        
        return result
    def get_mihomo_info(self):
        """Get Mihomo proxy service information"""
        info = {
            'running': False,
            'config_path': '/etc/mihomo/config.yaml',
            'tun_interface': None,
            'configured_interfaces': [],
            'load_balance_group': None
        }
        
        # Check if Mihomo service is running
        result = self.run_command("systemctl is-active mihomo 2>/dev/null || pgrep -f mihomo")
        if result['success'] and ('active' in result['output'] or result['output'].strip()):
            info['running'] = True
        
        # Check for TUN interface
        tun_result = self.run_command("ip link show | grep Meta")
        if tun_result['success'] and tun_result['output']:
            info['tun_interface'] = 'Meta'
        
        # Try to read Mihomo config to get interface information
        try:
            config_result = self.run_command("cat /etc/mihomo/config.yaml 2>/dev/null")
            if config_result['success']:
                config_content = config_result['output']
                
                # Look for interface-name configurations
                import re
                interface_matches = re.findall(r'interface-name:\s*["\']?([^"\'\\s]+)["\']?', config_content)
                info['configured_interfaces'] = list(set(interface_matches))
                
                # Check for load balance configuration
                if 'load-balance' in config_content and 'LB-LAN-USB' in config_content:
                    info['load_balance_group'] = 'LB-LAN-USB'
                    
        except Exception as e:
            logger.error(f"Error reading Mihomo config: {e}")
        
        return info

    def enable_dhcp(self, iface_name):
        """Enable DHCP on the interface"""
        # Flush existing IPs
        self.run_command(f"sudo ip addr flush dev {iface_name}")
        # Start dhclient
        result = self.run_command(f"sudo dhclient {iface_name}")
        if result['success']:
            return {'success': True, 'message': f'DHCP enabled on {iface_name}'}
        else:
            return {'success': False, 'error': result['error']}

    def disable_dhcp(self, iface_name):
        """Disable DHCP on the interface"""
        # Stop dhclient
        result = self.run_command(f"sudo dhclient -r {iface_name}")
        if result['success']:
            return {'success': True, 'message': f'DHCP released on {iface_name}'}
        else:
            return {'success': False, 'error': result['error']}

    def set_interface_mode(self, iface_name, mode, ip=None, netmask=None):
        """Set interface mode to DHCP or Static"""
        if mode == 'dhcp':
            # Disable any static IP, enable DHCP
            return self.enable_dhcp(iface_name)
        elif mode == 'static':
            # Disable DHCP, set static IP
            self.disable_dhcp(iface_name)
            if ip:
                return self.set_interface_ip(iface_name, ip, netmask)
            else:
                return {'success': False, 'error': 'IP address required for static mode'}
        else:
            return {'success': False, 'error': 'Invalid mode. Use "dhcp" or "static"'}

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

@app.route('/api/interface/<iface_name>/mode', methods=['POST'])
def api_set_interface_mode(iface_name):
    """API endpoint to set interface mode (DHCP/Static)"""
    data = request.get_json()
    if not data or 'mode' not in data:
        return jsonify({'error': 'Mode parameter required'}), 400
    mode = data['mode']
    ip = data.get('ip')
    netmask = data.get('netmask')
    result = network_manager.set_interface_mode(iface_name, mode, ip, netmask)
    return jsonify(result)

@app.route('/api/interface/<iface_name>/scan')
def api_scan_wireless(iface_name):
    """API endpoint to scan for wireless networks"""
    result = network_manager.get_wireless_networks(iface_name)
    return jsonify(result)

@app.route('/api/routing/fix', methods=['POST'])
def api_fix_routing():
    """API endpoint to automatically fix routing issues"""
    result = network_manager.auto_fix_routing()
    return jsonify(result)

@app.route('/api/interfaces/refresh', methods=['POST'])
def api_refresh_interfaces():
    """API endpoint to refresh interface configuration and detect changes"""
    result = network_manager.refresh_interface_config()
    return jsonify(result)

@app.route('/api/routing/gateways')
def api_detect_gateways():
    """API endpoint to detect available gateways"""
    gateways = network_manager.detect_available_gateways()
    return jsonify({'gateways': gateways})

@app.route('/api/interface/<iface_name>/test')
def api_test_interface(iface_name):
    """API endpoint to test interface connectivity"""
    result = network_manager.test_interface_connectivity(iface_name)
    return jsonify(result)

@app.route('/api/routing/health')
def api_routing_health():
    """API endpoint to check routing health"""
    health = network_manager.check_routing_health()
    return jsonify(health)

@app.route('/api/mihomo')
def api_mihomo_info():
    """API endpoint to get Mihomo service information"""
    info = network_manager.get_mihomo_info()
    return jsonify(info)

@app.route('/api/system')
def api_system_info():
    """API endpoint to get system information"""
    info = network_manager.get_system_info()
    # Add Mihomo information to system info
    info['mihomo'] = network_manager.get_mihomo_info()
    return jsonify(info)

@app.route('/static/<path:filename>')
def static_files(filename):
    """Serve static files"""
    return send_from_directory('static', filename)

@app.route('/api/usb-tethering/configure', methods=['POST'])
def configure_usb_tethering():
    """Configure USB tethering interfaces automatically"""
    try:
        result = subprocess.run(['/home/acer/network-interface-manager/configure-usb-tethering.sh'], 
                              capture_output=True, text=True, timeout=30)
        
        if result.returncode == 0:
            return jsonify({
                'success': True,
                'message': 'USB tethering configured successfully',
                'output': result.stdout
            })
        else:
            return jsonify({
                'success': False,
                'error': f'Configuration failed: {result.stderr}',
                'output': result.stdout
            })
    except subprocess.TimeoutExpired:
        return jsonify({
            'success': False,
            'error': 'Configuration timeout - process took too long'
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': f'Configuration error: {str(e)}'
        })

@app.route('/api/usb-tethering/setup-load-balancing', methods=['POST'])
def setup_load_balancing():
    """Setup load balancing for USB tethering"""
    try:
        result = subprocess.run(['/home/acer/network-interface-manager/setup-load-balancing.sh'], 
                              capture_output=True, text=True, timeout=30)
        
        if result.returncode == 0:
            return jsonify({
                'success': True,
                'message': 'Load balancing configured successfully',
                'output': result.stdout
            })
        else:
            return jsonify({
                'success': False,
                'error': f'Load balancing setup failed: {result.stderr}',
                'output': result.stdout
            })
    except subprocess.TimeoutExpired:
        return jsonify({
            'success': False,
            'error': 'Load balancing setup timeout'
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': f'Load balancing error: {str(e)}'
        })

@app.route('/api/usb-tethering/monitor', methods=['POST'])
def monitor_usb_tethering():
    """Monitor USB tethering interfaces and detect changes"""
    try:
        result = subprocess.run(['/home/acer/network-interface-manager/usb-monitor.sh', 'check'], 
                              capture_output=True, text=True, timeout=30)
        
        changes_detected = 'reconfiguring' in result.stdout.lower() or 'change detected' in result.stdout.lower()
        
        return jsonify({
            'success': True,
            'message': 'USB tethering monitoring completed',
            'output': result.stdout,
            'changes_detected': changes_detected
        })
    except subprocess.TimeoutExpired:
        return jsonify({
            'success': False,
            'error': 'Monitoring timeout'
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': f'Monitoring error: {str(e)}'
        })

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