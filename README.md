# Network Interface Manager

A comprehensive web-based network interface management tool for Linux systems. This application provides an intuitive interface to monitor, configure, and manage network interfaces including Ethernet, WiFi, USB tethering, and VPN connections.

## Features

### 🌐 Interface Management
- **Real-time monitoring** of all network interfaces
- **Enable/Disable** interfaces with one click
- **IP configuration** with CIDR notation support
- **Interface statistics** (RX/TX bytes, packets, errors)
- **MTU and speed information**

### 📡 Wireless Support
- **WiFi network scanning** for wireless interfaces
- **Signal strength** and security information
- **Network quality** metrics

### 📊 System Overview
- **Total interface count** and active interfaces
- **Aggregate data usage** statistics
- **Real-time connection status**
- **Auto-refresh** every 30 seconds

### 🎨 Modern Interface
- **Responsive design** for desktop and mobile
- **Dark theme** with professional styling
- **Interactive modals** for detailed configuration
- **Toast notifications** for user feedback
- **Search and filtering** capabilities

## Supported Interface Types

- **Ethernet** (enp*, eth*)
- **Wireless** (wlp*, wlan*)
- **USB Tethering** (usb*, rndis*)
- **VPN/Tunnel** (tun*, tailscale*)
- **Bridge** (br-*, docker*)
- **Loopback** (lo)
- **PPP** (ppp*)

## Installation

### Prerequisites
- Linux system with network interfaces
- Python 3.7 or higher
- pip3 package manager
- sudo access (for interface configuration)

### Quick Start

1. **Clone or download** the application:
   ```bash
   cd /home/acer/network-interface-manager
   ```

2. **Run the startup script**:
   ```bash
   ./start.sh
   ```

3. **Access the web interface**:
   Open your browser and navigate to `http://localhost:5020`

### Manual Installation

1. **Create virtual environment**:
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   ```

2. **Install dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

3. **Run the application**:
   ```bash
   python3 app.py
   ```

## Usage

### Web Interface

The web interface is accessible at `http://localhost:5020` and provides:

- **Dashboard**: Overview of all network interfaces with real-time statistics
- **Interface Cards**: Individual cards for each interface showing:
  - Interface type and status
  - IP addresses (IPv4/IPv6)
  - Data usage statistics
  - Quick action buttons

### Interface Actions

#### Enable/Disable Interface
- Click the **Enable** or **Disable** button on any interface card
- Requires sudo privileges

#### Configure IP Address
1. Click **Configure IP** on an interface card
2. Enter the IP address and netmask (CIDR notation)
3. Click **Apply Configuration**

#### View Detailed Information
- Click **Details** to see comprehensive interface information:
  - Basic properties (MTU, speed, carrier status)
  - All IP addresses with scope information
  - Detailed statistics (packets, errors)
  - Gateway and DNS information

#### Scan Wireless Networks
- Available for wireless interfaces
- Click **Scan WiFi** to discover nearby networks
- Shows SSID, signal strength, security status, and BSSID

### Filtering and Search

- **Filter by Type**: Select interface type from dropdown
- **Filter by Status**: Show only active or inactive interfaces
- **Search**: Type interface name to quickly find specific interfaces

## API Endpoints

The application provides a REST API for programmatic access:

### Interface Management
- `GET /api/interfaces` - Get all interfaces
- `GET /api/interface/<name>` - Get specific interface details
- `POST /api/interface/<name>/state` - Set interface state (up/down)
- `POST /api/interface/<name>/ip` - Configure IP address

### Wireless Operations
- `GET /api/interface/<name>/scan` - Scan for wireless networks

### System Information
- `GET /api/system` - Get system network information

## Configuration

### Port Configuration
To change the default port (5020), modify the `app.run()` call in `app.py`:

```python
app.run(host='0.0.0.0', port=YOUR_PORT, debug=False)
```

### Security Considerations

1. **Sudo Access**: Many network operations require root privileges
2. **Network Exposure**: The application binds to `0.0.0.0` by default
3. **Authentication**: No built-in authentication (add reverse proxy if needed)

### Production Deployment

For production use, consider:

1. **Use a WSGI server** like Gunicorn:
   ```bash
   pip install gunicorn
   gunicorn -w 4 -b 0.0.0.0:5020 app:app
   ```

2. **Add reverse proxy** (nginx/Apache) for SSL and authentication

3. **Create systemd service** for automatic startup:
   ```ini
   [Unit]
   Description=Network Interface Manager
   After=network.target

   [Service]
   Type=simple
   User=root
   WorkingDirectory=/home/acer/network-interface-manager
   ExecStart=/home/acer/network-interface-manager/venv/bin/python app.py
   Restart=always

   [Install]
   WantedBy=multi-user.target
   ```

## Troubleshooting

### Common Issues

1. **Permission Denied**: Ensure sudo access for network operations
2. **Interface Not Found**: Check if interface exists with `ip link show`
3. **Port Already in Use**: Change port in app.py or kill existing process
4. **Missing Dependencies**: Run `pip install -r requirements.txt`

### Logs and Debugging

- Application logs are printed to console
- Enable debug mode by setting `debug=True` in `app.run()`
- Check browser console for JavaScript errors

### Network Interface Issues

- **Interface won't come up**: Check cable connection and driver support
- **No IP address**: Verify DHCP server or configure static IP
- **Wireless scan fails**: Ensure wireless interface supports scanning

## Development

### Project Structure
```
network-interface-manager/
├── app.py                 # Main Flask application
├── templates/
│   └── index.html        # Main HTML template
├── static/
│   ├── css/
│   │   └── style.css     # Application styles
│   └── js/
│       └── app.js        # Frontend JavaScript
├── requirements.txt       # Python dependencies
├── start.sh              # Startup script
└── README.md             # This file
```

### Adding Features

1. **New Interface Types**: Modify `get_interface_type()` in `app.py`
2. **Additional Statistics**: Extend `get_interface_stats()` method
3. **New API Endpoints**: Add routes to Flask application
4. **UI Enhancements**: Modify templates and static files

## License

This project is open source and available under the MIT License.

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review application logs
3. Verify system requirements
4. Test with minimal configuration

---

**Network Interface Manager** - Professional network interface management for Linux systems.