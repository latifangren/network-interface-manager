# 🌐 Network Interface Manager

**Manajemen antarmuka jaringan berbasis web untuk Linux.**  
Pantau, konfigurasi, dan kelola Ethernet, WiFi, USB Tethering, VPN, dan Mihomo Proxy dengan mudah!

---

## ✨ Fitur Utama

- 🔎 **Monitoring Real-time** semua antarmuka jaringan
- 🔄 **Aktif/Nonaktifkan** antarmuka dengan satu klik
- 📝 **Konfigurasi IP** (CIDR support)
- 📈 **Statistik** RX/TX, paket, error, MTU, kecepatan
- 📡 **Scan WiFi** & info kualitas sinyal
- 🌑 **Tampilan modern**: dark mode, responsive, notifikasi interaktif
- 🔀 **Integrasi Mihomo**: deteksi TUN, load balancing, status proxy
- 🖥️ **Dukungan multi-interface**: Ethernet, WiFi, USB, VPN, Bridge, Loopback, PPP

---

## 🚀 Instalasi Otomatis

### Persiapan
- Linux + Python 3.7+
- pip3 & akses sudo

### Instalasi Cepat
```bash
# Hapus folder lama jika sudah ada
rm -rf network-interface-manager
git clone https://github.com/username/network-interface-manager.git
cd network-interface-manager
chmod +x setup.sh
sudo ./setup.sh
```
Akses web: [http://localhost:5020](http://localhost:5020)

---

## 🛠️ Penggunaan

- **Dashboard**: Statistik & status semua interface
- **Aksi Cepat**: Enable/Disable, konfigurasi IP, detail interface
- **Scan WiFi**: Temukan jaringan sekitar (khusus WiFi)
- **Filter & Cari**: Berdasarkan tipe/status/nama interface

---

## 🔌 Integrasi Mihomo Proxy

- Deteksi otomatis interface TUN (Meta)
- Monitoring status Mihomo & load balancing
- Cek integrasi:  
  ```bash
  ./test-mihomo.sh
  ```

---

## ⚡ API Endpoint

| Endpoint                              | Fungsi                        |
|----------------------------------------|-------------------------------|
| `GET /api/interfaces`                  | Daftar semua interface        |
| `GET /api/interface/<nama>`            | Detail interface tertentu     |
| `POST /api/interface/<nama>/state`     | Aktif/nonaktifkan interface   |
| `POST /api/interface/<nama>/ip`        | Konfigurasi IP               |
| `GET /api/interface/<nama>/scan`       | Scan WiFi (khusus wireless)   |
| `GET /api/mihomo`                      | Status Mihomo                 |
| `GET /api/system`                      | Info sistem & Mihomo          |

---

## ⚙️ Konfigurasi & Systemd

- **Port default**: 5020 (ubah di `app.py` jika perlu)
- **Integrasi systemd**:  
  - Otomatis start saat boot
  - Logging ke journal
  - Restart otomatis jika crash
- **Instalasi/Uninstall systemd**:  
  ```bash
  sudo ./install-systemd.sh
  sudo ./uninstall-systemd.sh
  ```

---

## 🧩 Struktur Project

```
network-interface-manager/
├── app.py                 # Aplikasi utama Flask
├── setup.sh               # Instalasi otomatis (reinstall support)
├── start.sh               # Jalankan aplikasi manual
├── install-systemd.sh     # Setup systemd service
├── uninstall-systemd.sh   # Hapus systemd service
├── requirements.txt       # Dependensi Python
├── static/                # Asset frontend (css, js, images)
├── templates/             # Template HTML
├── ... (script & file lain)
```

---

## 🆘 Troubleshooting

- ❗ **Permission denied**: Jalankan dengan sudo
- ❗ **Port bentrok**: Ubah port di `app.py`
- ❗ **Interface tidak muncul**: Cek dengan `ip link show`
- ❗ **Error dependensi**:  
  ```bash
  pip install -r requirements.txt
  ```

---

## 📄 Lisensi

MIT License

---

## 💡 Tips

- Untuk update/instal ulang, cukup jalankan:
  ```bash
  sudo ./setup.sh
  ```
- Cek status service:
  ```bash
  systemctl status network-manager.service
  systemctl status usb-monitor.service
  ```

---

**Network Interface Manager** - Solusi profesional manajemen jaringan Linux.