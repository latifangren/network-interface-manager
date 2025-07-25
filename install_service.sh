#!/bin/bash

SERVICE_NAME=network-interface-manager
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"
WORKDIR="$(cd "$(dirname "$0")"; pwd)"
START_SCRIPT="$WORKDIR/start.sh"

# Cek akses root
if [[ $EUID -ne 0 ]]; then
   echo "Script ini harus dijalankan sebagai root (sudo)!"
   exit 1
fi

# Buat file systemd service
cat > "$SERVICE_FILE" <<EOL
[Unit]
Description=Network Interface Manager
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$WORKDIR
ExecStart=$START_SCRIPT
Restart=always

[Install]
WantedBy=multi-user.target
EOL

# Reload systemd, enable dan start service
systemctl daemon-reload
systemctl enable $SERVICE_NAME
systemctl restart $SERVICE_NAME

echo "Systemd service '$SERVICE_NAME' berhasil dibuat dan dijalankan!"
echo "Gunakan 'systemctl status $SERVICE_NAME' untuk cek status." 