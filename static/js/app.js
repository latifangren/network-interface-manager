// Network Interface Manager JavaScript

let networkManager;

class NetworkInterfaceManager {
    constructor() {
        this.interfaces = {};
        this.currentInterface = null;
        this.refreshInterval = null;
        this.init();
    }

    init() {
        this.loadInterfaces();
        this.setupEventListeners();
        this.startAutoRefresh();
    }

    setupEventListeners() {
        // Modal close events
        window.addEventListener('click', (e) => {
            if (e.target.classList.contains('modal')) {
                this.closeModal();
                this.closeWirelessModal();
                this.closeIpModal();
                this.closeModeModal(); // Added for mode modal
            }
        });

        // IP configuration form
        document.getElementById('ipConfigForm').addEventListener('submit', (e) => {
            e.preventDefault();
            this.configureIP();
        });

        // Keyboard shortcuts
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') {
                this.closeModal();
                this.closeWirelessModal();
                this.closeIpModal();
                this.closeModeModal(); // Added for mode modal
            }
            if (e.key === 'F5' || (e.ctrlKey && e.key === 'r')) {
                e.preventDefault();
                this.refreshData();
            }
        });
    }

    async loadInterfaces() {
        try {
            this.showLoading();
            const response = await fetch('/api/interfaces');
            if (!response.ok) throw new Error('Failed to fetch interfaces');
            
            this.interfaces = await response.json();
            this.renderInterfaces();
            this.updateSystemStats();
            this.updateConnectionStatus(true);
        } catch (error) {
            console.error('Error loading interfaces:', error);
            this.showToast('Failed to load network interfaces', 'error');
            this.updateConnectionStatus(false);
        }
    }

    renderInterfaces() {
        const grid = document.getElementById('interfacesGrid');
        
        if (Object.keys(this.interfaces).length === 0) {
            grid.innerHTML = `
                <div class="loading-card">
                    <i class="fas fa-exclamation-triangle" style="font-size: 3rem; color: var(--warning); margin-bottom: 1rem;"></i>
                    <p>No network interfaces found</p>
                </div>
            `;
            return;
        }

        grid.innerHTML = Object.entries(this.interfaces)
            .map(([name, iface]) => this.createInterfaceCard(name, iface))
            .join('');
    }

    createInterfaceCard(name, iface) {
        const typeIcon = this.getTypeIcon(iface.type);
        const statusClass = iface.state === 'UP' ? 'status-up' : 'status-down';
        const statusIcon = iface.state === 'UP' ? 'fa-arrow-up' : 'fa-arrow-down';
        
        const addresses = iface.addresses.map(addr => `
            <div class="address-item">
                <span>${addr.address}</span>
                <span class="address-type ${addr.type.toLowerCase()}">${addr.type}</span>
            </div>
        `).join('');

        const stats = iface.stats || {};
        const rxFormatted = stats.rx_formatted || '0 B';
        const txFormatted = stats.tx_formatted || '0 B';

        return `
            <div class="interface-card" data-interface="${name}" data-type="${iface.type}" data-status="${iface.state}">
                <div class="interface-header">
                    <div class="interface-name">
                        <i class="${typeIcon}"></i>
                        <div>
                            <h3>${name}</h3>
                            <span class="interface-type type-${iface.type}">${iface.type.replace('_', ' ')}</span>
                        </div>
                    </div>
                    <div class="interface-status ${statusClass}">
                        <i class="fas ${statusIcon}"></i>
                        <span>${iface.state}</span>
                    </div>
                </div>
                <div class="interface-body">
                    <div class="interface-info">
                        <div class="info-item">
                            <div class="info-label">MTU</div>
                            <div class="info-value">${iface.mtu || 'Unknown'}</div>
                        </div>
                        <div class="info-item">
                            <div class="info-label">Speed</div>
                            <div class="info-value">${iface.speed || 'Unknown'}</div>
                        </div>
                        <div class="info-item">
                            <div class="info-label">Downloaded</div>
                            <div class="info-value">${rxFormatted}</div>
                        </div>
                        <div class="info-item">
                            <div class="info-label">Uploaded</div>
                            <div class="info-value">${txFormatted}</div>
                        </div>
                    </div>
                    
                    ${addresses ? `
                        <div class="addresses-section">
                            <h4>IP Addresses</h4>
                            ${addresses}
                        </div>
                    ` : ''}
                    
                    <div class="interface-actions">
                        <button class="btn btn-primary btn-small" onclick="networkManager.showInterfaceDetails('${name}')">
                            <i class="fas fa-info-circle"></i>
                            Details
                        </button>
                        <button class="btn btn-info btn-small" onclick="networkManager.testInterfaceConnectivity('${name}')">
                            <i class="fas fa-network-wired"></i>
                            Test
                        </button>
                        ${iface.state === 'UP' ? 
                            `<button class="btn btn-danger btn-small" onclick="networkManager.toggleInterface('${name}', 'down')">
                                <i class="fas fa-power-off"></i>
                                Disable
                            </button>` :
                            `<button class="btn btn-success btn-small" onclick="networkManager.toggleInterface('${name}', 'up')">
                                <i class="fas fa-power-off"></i>
                                Enable
                            </button>`
                        }
                        <button class="btn btn-secondary btn-small" onclick="networkManager.showIpConfig('${name}')">
                            <i class="fas fa-network-wired"></i>
                            Configure IP
                        </button>
                        <button class="btn btn-secondary btn-small" onclick="networkManager.showModeConfig('${name}')">
                            <i class="fas fa-cogs"></i>
                            Configure Mode
                        </button>
                        ${iface.type === 'wireless' ? 
                            `<button class="btn btn-warning btn-small" onclick="networkManager.scanWireless('${name}')">
                                <i class="fas fa-wifi"></i>
                                Scan WiFi
                            </button>` : ''
                        }
                    </div>
                </div>
            </div>
        `;
    }

    getTypeIcon(type) {
        const icons = {
            'ethernet': 'fas fa-ethernet',
            'wireless': 'fas fa-wifi',
            'usb_tethering': 'fas fa-usb',
            'mihomo_tun': 'fas fa-rocket',
            'vpn': 'fas fa-shield-alt',
            'bridge': 'fas fa-project-diagram',
            'loopback': 'fas fa-sync-alt',
            'tun': 'fas fa-tunnel',
            'ppp': 'fas fa-phone',
            'other': 'fas fa-question-circle'
        };
        return icons[type] || icons.other;
    }

    updateSystemStats() {
        const interfaces = Object.values(this.interfaces);
        const totalInterfaces = interfaces.length;
        const activeInterfaces = interfaces.filter(iface => iface.state === 'UP').length;
        
        let totalRx = 0;
        let totalTx = 0;
        
        interfaces.forEach(iface => {
            if (iface.stats) {
                totalRx += iface.stats.rx_bytes || 0;
                totalTx += iface.stats.tx_bytes || 0;
            }
        });

        document.getElementById('totalInterfaces').textContent = totalInterfaces;
        document.getElementById('activeInterfaces').textContent = activeInterfaces;
        document.getElementById('totalRx').textContent = this.formatBytes(totalRx);
        document.getElementById('totalTx').textContent = this.formatBytes(totalTx);
    }

    formatBytes(bytes) {
        if (bytes === 0) return '0 B';
        const k = 1024;
        const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
    }

    updateConnectionStatus(connected) {
        const statusElement = document.getElementById('connectionStatus');
        const dot = statusElement.querySelector('.status-dot');
        const text = statusElement.querySelector('.status-text');
        
        if (connected) {
            dot.style.background = 'var(--success)';
            text.textContent = 'Connected';
        } else {
            dot.style.background = 'var(--danger)';
            text.textContent = 'Disconnected';
        }
    }

    showLoading() {
        const grid = document.getElementById('interfacesGrid');
        grid.innerHTML = `
            <div class="loading-card">
                <div class="loading-spinner"></div>
                <p>Loading network interfaces...</p>
            </div>
        `;
    }

    async toggleInterface(interfaceName, state) {
        try {
            const response = await fetch(`/api/interface/${interfaceName}/state`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ state })
            });

            const result = await response.json();
            
            if (result.success) {
                this.showToast(`Interface ${interfaceName} ${state === 'up' ? 'enabled' : 'disabled'}`, 'success');
                setTimeout(() => this.loadInterfaces(), 1000);
            } else {
                this.showToast(`Failed to ${state} interface: ${result.error}`, 'error');
            }
        } catch (error) {
            console.error('Error toggling interface:', error);
            this.showToast('Failed to toggle interface', 'error');
        }
    }

    async showInterfaceDetails(interfaceName) {
        try {
            const response = await fetch(`/api/interface/${interfaceName}`);
            if (!response.ok) throw new Error('Failed to fetch interface details');
            
            const iface = await response.json();
            
            const modalTitle = document.getElementById('modalTitle');
            const modalBody = document.getElementById('modalBody');
            
            modalTitle.textContent = `${interfaceName} Details`;
            
            modalBody.innerHTML = `
                <div class="interface-details">
                    <div class="detail-section">
                        <h4><i class="fas fa-info-circle"></i> Basic Information</h4>
                        <div class="detail-grid">
                            <div class="detail-item">
                                <span class="detail-label">Name:</span>
                                <span class="detail-value">${iface.name}</span>
                            </div>
                            <div class="detail-item">
                                <span class="detail-label">Type:</span>
                                <span class="detail-value">${iface.type}</span>
                            </div>
                            <div class="detail-item">
                                <span class="detail-label">State:</span>
                                <span class="detail-value ${iface.state === 'UP' ? 'text-success' : 'text-danger'}">${iface.state}</span>
                            </div>
                            <div class="detail-item">
                                <span class="detail-label">Index:</span>
                                <span class="detail-value">${iface.index}</span>
                            </div>
                            <div class="detail-item">
                                <span class="detail-label">MTU:</span>
                                <span class="detail-value">${iface.mtu || 'Unknown'}</span>
                            </div>
                            <div class="detail-item">
                                <span class="detail-label">Speed:</span>
                                <span class="detail-value">${iface.speed || 'Unknown'}</span>
                            </div>
                        </div>
                    </div>
                    
                    ${iface.addresses && iface.addresses.length > 0 ? `
                        <div class="detail-section">
                            <h4><i class="fas fa-network-wired"></i> IP Addresses</h4>
                            <div class="addresses-list">
                                ${iface.addresses.map(addr => `
                                    <div class="address-detail">
                                        <span class="address-ip">${addr.address}</span>
                                        <span class="address-type ${addr.type.toLowerCase()}">${addr.type}</span>
                                        ${addr.scope ? `<span class="address-scope">${addr.scope}</span>` : ''}
                                    </div>
                                `).join('')}
                            </div>
                        </div>
                    ` : ''}
                    
                    ${iface.stats ? `
                        <div class="detail-section">
                            <h4><i class="fas fa-chart-bar"></i> Statistics</h4>
                            <div class="stats-grid">
                                <div class="stat-item">
                                    <span class="stat-label">RX Bytes:</span>
                                    <span class="stat-value">${iface.stats.rx_formatted || '0 B'}</span>
                                </div>
                                <div class="stat-item">
                                    <span class="stat-label">TX Bytes:</span>
                                    <span class="stat-value">${iface.stats.tx_formatted || '0 B'}</span>
                                </div>
                                <div class="stat-item">
                                    <span class="stat-label">RX Packets:</span>
                                    <span class="stat-value">${iface.stats.rx_packets || 0}</span>
                                </div>
                                <div class="stat-item">
                                    <span class="stat-label">TX Packets:</span>
                                    <span class="stat-value">${iface.stats.tx_packets || 0}</span>
                                </div>
                                <div class="stat-item">
                                    <span class="stat-label">RX Errors:</span>
                                    <span class="stat-value ${iface.stats.rx_errors > 0 ? 'text-danger' : ''}">${iface.stats.rx_errors || 0}</span>
                                </div>
                                <div class="stat-item">
                                    <span class="stat-label">TX Errors:</span>
                                    <span class="stat-value ${iface.stats.tx_errors > 0 ? 'text-danger' : ''}">${iface.stats.tx_errors || 0}</span>
                                </div>
                            </div>
                        </div>
                    ` : ''}
                    
                    ${iface.gateway ? `
                        <div class="detail-section">
                            <h4><i class="fas fa-route"></i> Gateway</h4>
                            <div class="gateway-info">
                                <span class="gateway-ip">${iface.gateway}</span>
                            </div>
                        </div>
                    ` : ''}
                    
                    ${iface.dns && iface.dns.length > 0 ? `
                        <div class="detail-section">
                            <h4><i class="fas fa-server"></i> DNS Servers</h4>
                            <div class="dns-list">
                                ${iface.dns.map(dns => `<div class="dns-item">${dns}</div>`).join('')}
                            </div>
                        </div>
                    ` : ''}
                </div>
            `;
            
            this.showModal();
        } catch (error) {
            console.error('Error fetching interface details:', error);
            this.showToast('Failed to load interface details', 'error');
        }
    }

    showIpConfig(interfaceName) {
        this.currentInterface = interfaceName;
        document.getElementById('ipModalTitle').textContent = `Configure IP for ${interfaceName}`;
        document.getElementById('ipAddress').value = '';
        document.getElementById('netmask').value = '24';
        document.getElementById('ipModal').style.display = 'block';
    }

    async configureIP() {
        if (!this.currentInterface) return;
        
        const ipAddress = document.getElementById('ipAddress').value;
        const netmask = document.getElementById('netmask').value;
        
        if (!ipAddress || !netmask) {
            this.showToast('Please fill in all fields', 'warning');
            return;
        }
        
        try {
            const response = await fetch(`/api/interface/${this.currentInterface}/ip`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    ip: ipAddress,
                    netmask: netmask
                })
            });

            const result = await response.json();
            
            if (result.success) {
                this.showToast(`IP configuration applied to ${this.currentInterface}`, 'success');
                this.closeIpModal();
                setTimeout(() => this.loadInterfaces(), 1000);
            } else {
                this.showToast(`Failed to configure IP: ${result.error}`, 'error');
            }
        } catch (error) {
            console.error('Error configuring IP:', error);
            this.showToast('Failed to configure IP address', 'error');
        }
    }

    async scanWireless(interfaceName) {
        try {
            this.showWirelessModal();
            document.getElementById('wirelessModalBody').innerHTML = `
                <div class="loading-card">
                    <div class="loading-spinner"></div>
                    <p>Scanning for wireless networks...</p>
                </div>
            `;
            
            const response = await fetch(`/api/interface/${interfaceName}/scan`);
            const result = await response.json();
            
            if (result.success && result.networks) {
                const networksHtml = result.networks.map(network => `
                    <div class="wireless-network">
                        <div class="network-info">
                            <div class="network-ssid">${network.ssid || 'Hidden Network'}</div>
                            <div class="network-details">
                                <span class="network-signal">${network.signal || 'Unknown'}</span>
                                <span class="network-quality">${network.quality || 'Unknown'}</span>
                                <span class="network-security ${network.encrypted ? 'encrypted' : 'open'}">
                                    <i class="fas ${network.encrypted ? 'fa-lock' : 'fa-unlock'}"></i>
                                    ${network.encrypted ? 'Secured' : 'Open'}
                                </span>
                            </div>
                        </div>
                        <div class="network-bssid">${network.bssid}</div>
                    </div>
                `).join('');
                
                document.getElementById('wirelessModalBody').innerHTML = `
                    <div class="wireless-networks">
                        <h4>Found ${result.networks.length} networks:</h4>
                        ${networksHtml}
                    </div>
                `;
            } else {
                document.getElementById('wirelessModalBody').innerHTML = `
                    <div class="no-networks">
                        <i class="fas fa-exclamation-triangle"></i>
                        <p>No wireless networks found or scan failed</p>
                        <p class="error-message">${result.error || ''}</p>
                    </div>
                `;
            }
        } catch (error) {
            console.error('Error scanning wireless:', error);
            document.getElementById('wirelessModalBody').innerHTML = `
                <div class="no-networks">
                    <i class="fas fa-exclamation-triangle"></i>
                    <p>Failed to scan for wireless networks</p>
                </div>
            `;
        }
    }

    filterInterfaces() {
        const typeFilter = document.getElementById('typeFilter').value;
        const statusFilter = document.getElementById('statusFilter').value;
        const searchInput = document.getElementById('searchInput').value.toLowerCase();
        
        const cards = document.querySelectorAll('.interface-card');
        
        cards.forEach(card => {
            const interfaceName = card.dataset.interface.toLowerCase();
            const interfaceType = card.dataset.type;
            const interfaceStatus = card.dataset.status;
            
            const matchesType = !typeFilter || interfaceType === typeFilter;
            const matchesStatus = !statusFilter || interfaceStatus === statusFilter;
            const matchesSearch = !searchInput || interfaceName.includes(searchInput);
            
            if (matchesType && matchesStatus && matchesSearch) {
                card.style.display = 'block';
            } else {
                card.style.display = 'none';
            }
        });
    }

    showModal() {
        document.getElementById('interfaceModal').style.display = 'block';
    }

    closeModal() {
        document.getElementById('interfaceModal').style.display = 'none';
    }

    showWirelessModal() {
        document.getElementById('wirelessModal').style.display = 'block';
    }

    closeWirelessModal() {
        document.getElementById('wirelessModal').style.display = 'none';
    }

    closeIpModal() {
        document.getElementById('ipModal').style.display = 'none';
        this.currentInterface = null;
    }

    showModeConfig(interfaceName) {
        this.currentInterface = interfaceName;
        document.getElementById('modeModalTitle').textContent = `Configure Mode for ${interfaceName}`;
        // Reset form
        document.querySelector('#modeConfigForm input[value="dhcp"]').checked = true;
        document.getElementById('staticFields').style.display = 'none';
        document.getElementById('modeIpAddress').value = '';
        document.getElementById('modeNetmask').value = '24';
        document.getElementById('modeModal').style.display = 'block';
    }

    async configureMode() {
        if (!this.currentInterface) return;
        const mode = document.querySelector('#modeConfigForm input[name="mode"]:checked').value;
        const ip = document.getElementById('modeIpAddress').value;
        const netmask = document.getElementById('modeNetmask').value;
        let payload = { mode };
        if (mode === 'static') {
            if (!ip || !netmask) {
                this.showToast('Please fill in IP and netmask for static mode', 'warning');
                return;
            }
            payload.ip = ip;
            payload.netmask = netmask;
        }
        try {
            const response = await fetch(`/api/interface/${this.currentInterface}/mode`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload)
            });
            const result = await response.json();
            if (result.success) {
                this.showToast(`Mode applied to ${this.currentInterface}`, 'success');
                this.closeModeModal();
                setTimeout(() => this.loadInterfaces(), 1000);
            } else {
                this.showToast(`Failed to set mode: ${result.error}`, 'error');
            }
        } catch (error) {
            console.error('Error configuring mode:', error);
            this.showToast('Failed to configure mode', 'error');
        }
    }

    showToast(message, type = 'info') {
        const toast = document.getElementById('toast');
        const icon = toast.querySelector('.toast-icon');
        const messageEl = toast.querySelector('.toast-message');
        
        // Set icon based on type
        const icons = {
            success: 'fas fa-check-circle',
            error: 'fas fa-exclamation-circle',
            warning: 'fas fa-exclamation-triangle',
            info: 'fas fa-info-circle'
        };
        
        icon.className = `toast-icon ${icons[type] || icons.info}`;
        messageEl.textContent = message;
        toast.className = `toast ${type}`;
        
        // Show toast
        toast.classList.add('show');
        
        // Hide after 5 seconds
        setTimeout(() => {
            toast.classList.remove('show');
        }, 5000);
    }

    refreshData() {
        this.loadInterfaces();
        this.showToast('Network interfaces refreshed', 'success');
    }

    startAutoRefresh() {
        // Refresh every 30 seconds
        this.refreshInterval = setInterval(() => {
            this.loadInterfaces();
        }, 30000);
    }

    stopAutoRefresh() {
        if (this.refreshInterval) {
            clearInterval(this.refreshInterval);
            this.refreshInterval = null;
        }
    }
    async testInterfaceConnectivity(interfaceName) {
        try {
            this.showToast(`Testing connectivity for ${interfaceName}...`, 'info');
            
            const response = await fetch(`/api/interface/${interfaceName}/test`);
            const result = await response.json();
            
            if (response.ok) {
                // Show test results in modal
                const modalTitle = document.getElementById('modalTitle');
                const modalBody = document.getElementById('modalBody');
                
                modalTitle.textContent = `Connectivity Test: ${interfaceName}`;
                
                const statusIcon = (success) => success ? '✅' : '❌';
                const statusText = (success) => success ? 'PASSED' : 'FAILED';
                
                modalBody.innerHTML = `
                    <div class="connectivity-test-results">
                        <div class="test-summary">
                            <h4><i class="fas fa-network-wired"></i> Connectivity Test Results</h4>
                            <div class="test-overview">
                                <div class="test-score">
                                    ${[result.ping_gateway, result.ping_dns, result.http_test].filter(Boolean).length}/3 Tests Passed
                                </div>
                            </div>
                        </div>
                        
                        <div class="test-details">
                            <div class="test-item">
                                <div class="test-name">
                                    <i class="fas fa-route"></i>
                                    Gateway Ping
                                </div>
                                <div class="test-result ${result.ping_gateway ? 'success' : 'failed'}">
                                    ${statusIcon(result.ping_gateway)} ${statusText(result.ping_gateway)}
                                </div>
                                ${result.gateway ? `<div class="test-info">Gateway: ${result.gateway}</div>` : ''}
                            </div>
                            
                            <div class="test-item">
                                <div class="test-name">
                                    <i class="fas fa-server"></i>
                                    DNS Connectivity
                                </div>
                                <div class="test-result ${result.ping_dns ? 'success' : 'failed'}">
                                    ${statusIcon(result.ping_dns)} ${statusText(result.ping_dns)}
                                </div>
                                <div class="test-info">Target: 8.8.8.8</div>
                            </div>
                            
                            <div class="test-item">
                                <div class="test-name">
                                    <i class="fas fa-globe"></i>
                                    HTTP Connectivity
                                </div>
                                <div class="test-result ${result.http_test ? 'success' : 'failed'}">
                                    ${statusIcon(result.http_test)} ${statusText(result.http_test)}
                                </div>
                                ${result.public_ip ? `<div class="test-info">Public IP: ${result.public_ip}</div>` : ''}
                            </div>
                        </div>
                        
                        ${result.errors && result.errors.length > 0 ? `
                            <div class="test-errors">
                                <h5><i class="fas fa-exclamation-triangle"></i> Errors:</h5>
                                ${result.errors.map(error => `<div class="error-item">${error}</div>`).join('')}
                            </div>
                        ` : ''}
                    </div>
                `;
                
                this.showModal();
                
                // Show summary toast
                const passedTests = [result.ping_gateway, result.ping_dns, result.http_test].filter(Boolean).length;
                if (passedTests === 3) {
                    this.showToast(`${interfaceName}: All connectivity tests passed!`, 'success');
                } else if (passedTests > 0) {
                    this.showToast(`${interfaceName}: ${passedTests}/3 tests passed`, 'warning');
                } else {
                    this.showToast(`${interfaceName}: All connectivity tests failed`, 'error');
                }
            } else {
                this.showToast(`Failed to test ${interfaceName}: ${result.error || 'Unknown error'}`, 'error');
            }
        } catch (error) {
            console.error('Error testing interface connectivity:', error);
            this.showToast('Failed to test interface connectivity', 'error');
        }
    }

    async checkRoutingHealth() {
        try {
            this.showToast('Checking routing health...', 'info');
            
            const response = await fetch('/api/routing/health');
            const health = await response.json();
            
            if (response.ok) {
                this.showRoutingHealthModal(health);
            } else {
                this.showToast('Failed to check routing health', 'error');
            }
        } catch (error) {
            console.error('Error checking routing health:', error);
            this.showToast('Failed to check routing health', 'error');
        }
    }

    showRoutingHealthModal(health) {
        const modalBody = document.getElementById('routingModalBody');
        
        const statusIcon = health.issues.length === 0 ? '✅' : '⚠️';
        const statusText = health.issues.length === 0 ? 'Healthy' : `${health.issues.length} Issues Found`;
        
        modalBody.innerHTML = `
            <div class="routing-health">
                <div class="health-summary">
                    <div class="health-status">
                        <span class="status-icon">${statusIcon}</span>
                        <span class="status-text">${statusText}</span>
                    </div>
                    <div class="health-stats">
                        <div class="stat-item">
                            <span class="stat-label">Default Routes:</span>
                            <span class="stat-value">${health.default_routes_count}</span>
                        </div>
                        <div class="stat-item">
                            <span class="stat-label">Load Balancing:</span>
                            <span class="stat-value">${health.load_balancing_active ? 'Active' : 'Inactive'}</span>
                        </div>
                    </div>
                </div>
                
                ${health.issues.length > 0 ? `
                    <div class="health-issues">
                        <h4><i class="fas fa-exclamation-triangle"></i> Issues Detected:</h4>
                        ${health.issues.map(issue => `
                            <div class="issue-item">
                                <i class="fas fa-times-circle"></i>
                                ${issue}
                            </div>
                        `).join('')}
                    </div>
                ` : ''}
                
                ${health.suggestions.length > 0 ? `
                    <div class="health-suggestions">
                        <h4><i class="fas fa-lightbulb"></i> Suggestions:</h4>
                        ${health.suggestions.map(suggestion => `
                            <div class="suggestion-item">
                                <i class="fas fa-arrow-right"></i>
                                ${suggestion}
                            </div>
                        `).join('')}
                    </div>
                ` : ''}
                
                <div class="health-actions">
                    ${health.issues.length > 0 ? `
                        <button class="btn btn-danger" onclick="networkManager.fixRoutingFromModal()">
                            <i class="fas fa-tools"></i>
                            Auto-Fix Issues
                        </button>
                    ` : ''}
                    <button class="btn btn-secondary" onclick="networkManager.closeRoutingModal()">
                        Close
                    </button>
                </div>
            </div>
        `;
        
        document.getElementById('routingModal').style.display = 'block';
    }

    async fixRouting() {
        try {
            this.showToast('Fixing routing issues...', 'info');
            
            const response = await fetch('/api/routing/fix', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                }
            });
            
            const result = await response.json();
            
            if (response.ok) {
                this.showRoutingFixModal(result);
            } else {
                this.showToast('Failed to fix routing', 'error');
            }
        } catch (error) {
            console.error('Error fixing routing:', error);
            this.showToast('Failed to fix routing', 'error');
        }
    }

    showRoutingFixModal(result) {
        const modalBody = document.getElementById('routingFixModalBody');
        
        const statusIcon = result.success ? '✅' : '❌';
        const statusText = result.success ? 'Success' : 'Failed';
        
        modalBody.innerHTML = `
            <div class="routing-fix-results">
                <div class="fix-summary">
                    <div class="fix-status ${result.success ? 'success' : 'failed'}">
                        <span class="status-icon">${statusIcon}</span>
                        <span class="status-text">Routing Fix: ${statusText}</span>
                    </div>
                </div>
                
                ${result.actions_taken.length > 0 ? `
                    <div class="fix-actions">
                        <h4><i class="fas fa-check-circle"></i> Actions Taken:</h4>
                        ${result.actions_taken.map(action => `
                            <div class="action-item">
                                <i class="fas fa-arrow-right"></i>
                                ${action}
                            </div>
                        `).join('')}
                    </div>
                ` : ''}
                
                ${result.errors.length > 0 ? `
                    <div class="fix-errors">
                        <h4><i class="fas fa-exclamation-triangle"></i> Errors:</h4>
                        ${result.errors.map(error => `
                            <div class="error-item">
                                <i class="fas fa-times-circle"></i>
                                ${error}
                            </div>
                        `).join('')}
                    </div>
                ` : ''}
                
                ${result.before && result.after ? `
                    <div class="fix-comparison">
                        <div class="comparison-section">
                            <h5>Before Fix:</h5>
                            <div class="comparison-stats">
                                <span>Issues: ${result.before.issues ? result.before.issues.length : 0}</span>
                                <span>Load Balancing: ${result.before.load_balancing_active ? 'Active' : 'Inactive'}</span>
                            </div>
                        </div>
                        <div class="comparison-section">
                            <h5>After Fix:</h5>
                            <div class="comparison-stats">
                                <span>Issues: ${result.after.issues ? result.after.issues.length : 0}</span>
                                <span>Load Balancing: ${result.after.load_balancing_active ? 'Active' : 'Inactive'}</span>
                            </div>
                        </div>
                    </div>
                ` : ''}
                
                <div class="fix-actions-buttons">
                    <button class="btn btn-primary" onclick="networkManager.refreshData()">
                        <i class="fas fa-sync-alt"></i>
                        Refresh Interfaces
                    </button>
                    <button class="btn btn-secondary" onclick="networkManager.closeRoutingFixModal()">
                        Close
                    </button>
                </div>
            </div>
        `;
        
        document.getElementById('routingFixModal').style.display = 'block';
        
        // Show result toast
        if (result.success) {
            this.showToast('Routing issues fixed successfully!', 'success');
        } else {
            this.showToast('Failed to fix some routing issues', 'error');
        }
    }

    async refreshInterfaces() {
        try {
            this.showToast('Refreshing interfaces and detecting changes...', 'info');
            
            const response = await fetch('/api/interfaces/refresh', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                }
            });
            
            const result = await response.json();
            
            if (response.ok && result.success) {
                if (result.changes_detected.length > 0) {
                    this.showToast(`Changes detected: ${result.changes_detected.join(', ')}`, 'warning');
                    
                    // If IP changes detected, suggest routing fix
                    if (result.changed_ips.length > 0) {
                        setTimeout(() => {
                            if (confirm('IP address changes detected. Do you want to fix routing automatically?')) {
                                this.fixRouting();
                            }
                        }, 1000);
                    }
                } else {
                    this.showToast('No interface changes detected', 'info');
                }
                
                // Refresh the interface display
                this.loadInterfaces();
            } else {
                this.showToast('Failed to refresh interfaces', 'error');
            }
        } catch (error) {
            console.error('Error refreshing interfaces:', error);
            this.showToast('Failed to refresh interfaces', 'error');
        }
    }

    fixRoutingFromModal() {
        this.closeRoutingModal();
        this.fixRouting();
    }

    closeRoutingModal() {
        document.getElementById('routingModal').style.display = 'none';
    }

    closeRoutingFixModal() {
        document.getElementById('routingFixModal').style.display = 'none';
    }

    async setupLoadBalancing() {
        try {
            this.showToast('Setting up load balancing...', 'info');
            
            const response = await fetch('/api/usb-tethering/setup-load-balancing', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                }
            });

            const result = await response.json();
            
            if (result.success) {
                this.showToast('Load balancing configured successfully!', 'success');
                setTimeout(() => this.loadInterfaces(), 1000);
            } else {
                this.showToast(`Failed to setup load balancing: ${result.error}`, 'error');
            }
        } catch (error) {
            console.error('Error setting up load balancing:', error);
            this.showToast('Failed to setup load balancing', 'error');
        }
    }

    async configureUsbTethering() {
        try {
            this.showToast('Configuring USB tethering...', 'info');
            
            const response = await fetch('/api/usb-tethering/configure', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                }
            });

            const result = await response.json();
            
            if (result.success) {
                this.showToast('USB tethering configured successfully!', 'success');
                setTimeout(() => this.loadInterfaces(), 1000);
            } else {
                this.showToast(`Failed to configure USB tethering: ${result.error}`, 'error');
            }
        } catch (error) {
            console.error('Error configuring USB tethering:', error);
            this.showToast('Failed to configure USB tethering', 'error');
        }
    }

    async monitorUsbTethering() {
        try {
            this.showToast('Checking USB tethering status...', 'info');
            
            const response = await fetch('/api/usb-tethering/monitor', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                }
            });

            const result = await response.json();
            
            if (result.success) {
                this.showToast('USB tethering monitoring completed!', 'success');
                
                // Show monitoring results in modal
                const modalTitle = document.getElementById('modalTitle');
                const modalBody = document.getElementById('modalBody');
                
                modalTitle.textContent = 'USB Tethering Monitor Results';
                modalBody.innerHTML = `
                    <div class="usb-monitor-results">
                        <h4><i class="fas fa-usb"></i> USB Tethering Status</h4>
                        <pre>${result.output}</pre>
                        ${result.changes_detected ? '<p class="text-warning">⚠️ Changes detected and reconfigured!</p>' : '<p class="text-success">✅ No changes needed</p>'}
                    </div>
                `;
                
                this.showModal();
                setTimeout(() => this.loadInterfaces(), 1000);
            } else {
                this.showToast(`USB monitoring failed: ${result.error}`, 'error');
            }
        } catch (error) {
            console.error('Error monitoring USB tethering:', error);
            this.showToast('Failed to monitor USB tethering', 'error');
        }
    }
}

// Global functions for HTML onclick events
function refreshInterfaces() {
    networkManager.refreshInterfaces();
}

function checkRoutingHealth() {
    networkManager.checkRoutingHealth();
}

function fixRouting() {
    networkManager.fixRouting();
}

function refreshData() {
    networkManager.refreshData();
}

function filterInterfaces() {
    networkManager.filterInterfaces();
}

function closeModal() {
    networkManager.closeModal();
}

function closeWirelessModal() {
    networkManager.closeWirelessModal();
}

function closeIpModal() {
    networkManager.closeIpModal();
}

function closeModeModal() {
    networkManager.closeModeModal();
}

function closeRoutingModal() {
    networkManager.closeRoutingModal();
}

function closeRoutingFixModal() {
    networkManager.closeRoutingFixModal();
}
function setupLoadBalancing() {
    networkManager.setupLoadBalancing();
}

function configureUsbTethering() {
    networkManager.configureUsbTethering();
}

function monitorUsbTethering() {
    networkManager.monitorUsbTethering();
}

// Initialize the application
document.addEventListener('DOMContentLoaded', () => {
    networkManager = new NetworkInterfaceManager();
    
    // Add event listeners for routing buttons
    const routingHealthBtn = document.getElementById('routing-health-btn');
    const fixRoutingBtn = document.getElementById('fix-routing-btn');
    
    if (routingHealthBtn) {
        routingHealthBtn.addEventListener('click', () => {
            networkManager.checkRoutingHealth();
        });
    }
    
    if (fixRoutingBtn) {
        fixRoutingBtn.addEventListener('click', () => {
            networkManager.fixRouting();
        });
    }
    
    // Add additional styles for modal content
    const additionalStyles = `
        <style>
            .interface-details .detail-section {
                margin-bottom: 2rem;
                padding: 1rem;
                background: var(--bg-secondary);
                border-radius: 8px;
                border-left: 3px solid var(--primary-blue);
            }
            
            .interface-details .detail-section h4 {
                display: flex;
                align-items: center;
                gap: 0.5rem;
                margin-bottom: 1rem;
                color: var(--text-main);
                font-size: 1rem;
            }
            
            .detail-grid, .stats-grid {
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
                gap: 1rem;
            }
            
            .detail-item, .stat-item {
                display: flex;
                justify-content: space-between;
                padding: 0.5rem 0;
                border-bottom: 1px solid var(--border);
            }
            
            .detail-label, .stat-label {
                color: var(--text-secondary);
                font-weight: 500;
            }
            
            .detail-value, .stat-value {
                color: var(--text-main);
                font-weight: 600;
            }
            
            .addresses-list, .dns-list {
                display: flex;
                flex-direction: column;
                gap: 0.5rem;
            }
            
            .address-detail {
                display: flex;
                align-items: center;
                gap: 1rem;
                padding: 0.75rem;
                background: var(--bg-tertiary);
                border-radius: 6px;
            }
            
            .address-ip {
                font-family: monospace;
                font-weight: 600;
            }
            
            .address-scope {
                font-size: 0.8rem;
                color: var(--text-muted);
            }
            
            .gateway-info, .dns-item {
                padding: 0.75rem;
                background: var(--bg-tertiary);
                border-radius: 6px;
                font-family: monospace;
                font-weight: 600;
            }
            
            .wireless-networks {
                max-height: 400px;
                overflow-y: auto;
            }
            
            .wireless-network {
                padding: 1rem;
                margin-bottom: 1rem;
                background: var(--bg-secondary);
                border-radius: 8px;
                border-left: 3px solid var(--primary-blue);
            }
            
            .network-ssid {
                font-size: 1.1rem;
                font-weight: 600;
                margin-bottom: 0.5rem;
                color: var(--text-main);
            }
            
            .network-details {
                display: flex;
                gap: 1rem;
                margin-bottom: 0.5rem;
                flex-wrap: wrap;
            }
            
            .network-signal, .network-quality {
                padding: 0.2rem 0.5rem;
                background: var(--bg-tertiary);
                border-radius: 4px;
                font-size: 0.8rem;
            }
            
            .network-security {
                padding: 0.2rem 0.5rem;
                border-radius: 4px;
                font-size: 0.8rem;
                font-weight: 500;
            }
            
            .network-security.encrypted {
                background: var(--success);
                color: white;
            }
            
            .network-security.open {
                background: var(--warning);
                color: white;
            }
            
            .network-bssid {
                font-family: monospace;
                font-size: 0.8rem;
                color: var(--text-muted);
            }
            
            .no-networks {
                text-align: center;
                padding: 2rem;
                color: var(--text-secondary);
            }
            
            .no-networks i {
                font-size: 3rem;
                margin-bottom: 1rem;
                color: var(--warning);
            }
            
            .error-message {
                font-size: 0.9rem;
                color: var(--danger);
                margin-top: 0.5rem;
            }
        </style>
    `;
    
    document.head.insertAdjacentHTML('beforeend', additionalStyles);

    // Mode config form event
    document.getElementById('modeConfigForm').addEventListener('submit', function(e) {
        e.preventDefault();
        networkManager.configureMode();
    });
    // Show/hide static fields
    document.querySelectorAll('#modeConfigForm input[name="mode"]').forEach(radio => {
        radio.addEventListener('change', function() {
            if (this.value === 'static') {
                document.getElementById('staticFields').style.display = 'block';
            } else {
                document.getElementById('staticFields').style.display = 'none';
            }
        });
    });
});