// Network Interface Manager JavaScript

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
}

// Global functions for HTML onclick events
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

// Initialize the application
let networkManager;

document.addEventListener('DOMContentLoaded', () => {
    networkManager = new NetworkInterfaceManager();
    
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
});