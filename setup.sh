# Pastikan semua script .sh memiliki permission 755
chmod 755 ./*.sh
#!/bin/bash
set -e

# Nama service
SERVICES=(network-manager.service usb-monitor.service)

# Fungsi: stop, disable, dan hapus service jika sudah ada
for SERVICE in "${SERVICES[@]}"; do
    if systemctl list-units --full -all | grep -q "$SERVICE"; then
        echo "[INFO] $SERVICE ditemukan, stop & disable..."
        sudo systemctl stop $SERVICE || true
        sudo systemctl disable $SERVICE || true
        if [ -f "/etc/systemd/system/$SERVICE" ]; then
            sudo rm -f "/etc/systemd/system/$SERVICE"
            echo "[INFO] $SERVICE dihapus dari systemd."
        fi
    fi
done

# Uninstall systemd (jika ada script)
if [ -f ./uninstall-systemd.sh ]; then
    echo "[INFO] Menjalankan uninstall-systemd.sh..."
    sudo ./uninstall-systemd.sh || true
fi

# Setup virtualenv jika belum ada
if [ ! -d "venv" ]; then
    echo "[INFO] Membuat virtual environment..."
    python3 -m venv venv
fi

# Aktifkan virtualenv & install requirements
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

deactivate

# Install systemd service
if [ -f ./install-systemd.sh ]; then
    echo "[INFO] Menjalankan install-systemd.sh..."
    sudo ./install-systemd.sh
fi

# Rename USB tethering interface (jika script tersedia)
if [ -f ./rename-usb-interface.sh ]; then
    echo "[INFO] Menstandarisasi nama interface USB tethering..."
    sudo ./rename-usb-interface.sh || true
fi

# Jalankan aplikasi (opsional, bisa pakai systemd atau manual)
echo "[INFO] Menjalankan aplikasi via start.sh..."
./start.sh &

# Tampilkan status service
echo "\n[INFO] Status service setelah setup:"
for SERVICE in "${SERVICES[@]}"; do
    systemctl status $SERVICE --no-pager | head -20 || true
done

echo "\n[SETUP SELESAI] Aplikasi dan service sudah diinstall ulang." 