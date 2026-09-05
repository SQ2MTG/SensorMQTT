# 🧠 System Sensors MQTT Publisher

![Build Status](https://img.shields.io/badge/build-passing-brightgreen)
![Platform](https://img.shields.io/badge/platform-Linux-blue)
![Language](https://img.shields.io/badge/shell-bash-lightgrey)
[![CodeFactor](https://www.codefactor.io/repository/github/sq2mtg/system-sensors-linux/badge/main)](https://www.codefactor.io/repository/github/sq2mtg/system-sensors-linux/overview/main)
![MQTT](https://img.shields.io/badge/protocol-MQTT-orange)
![License](https://img.shields.io/badge/license-MIT-yellow)

A lightweight Bash-based monitoring tool that reads system hardware sensors (CPU, GPU, disk, and more) and publishes their readings to an MQTT broker.  
Designed for Linux systems using `lm-sensors`, `smartmontools`, and optional GPU utilities.

---

## 📋 Table of Contents
- [Overview](#overview)
- [Features](#features)
- [Installation](#installation)
- [Usage](#usage)
- [MQTT Topics](#mqtt-topics)
- [Dependencies](#dependencies)
- [Configuration](#configuration)
- [Service Management](#service-management)
- [Logging](#logging)
- [Troubleshooting](#troubleshooting)
- [License](#license)

---

## 🧩 Overview

`system-sensors` continuously monitors local hardware metrics and publishes them to an MQTT topic for further integration with monitoring dashboards (e.g. Home Assistant, Grafana, Node-RED).

It detects:
- CPU core and package temperatures
- GPU temperatures (NVIDIA / AMD / other sensors)
- Disk temperatures via S.M.A.R.T.
- Any additional `lm-sensors` readings

All sensor values are colorized in the terminal and periodically sent to an MQTT broker.

---

## ✨ Features
- Real-time terminal display with colored temperature output  
- MQTT publishing per sensor/device  
- Automatic detection of available sensors (CPU, GPU, disks)  
- Works as a systemd service  
- Supports both TCP (`1883`) and WebSocket (`9002/ws`) MQTT connections  

---

## ⚙️ Installation

Run the included installer:

```bash
chmod +x install.sh
sudo ./install.sh
```

This script will:
1. Update system packages  
2. Install dependencies (`lm-sensors`, `mosquitto-clients`, `smartmontools`, etc.)  
3. Create `/opt/system-sensors/` and place the monitoring script there  
4. Set up and enable a `systemd` service (`system-sensors.service`)  
5. Start the service automatically at boot  

After installation, logs are viewable via:
```bash
journalctl -u system-sensors -f
```

---

## 🚀 Usage

To run manually (without systemd):
```bash
bash /opt/system-sensors/system-sensors.sh
```

To stop the background service:
```bash
sudo systemctl stop system-sensors
```

To start it again:
```bash
sudo systemctl start system-sensors
```

---

## 🛰️ MQTT Topics

By default, data is published to:
```
pc-sensors/<hostname>/<category>/<sensor_name>
```

**Examples:**
```
pc-sensors/server01/cpu/Core0
pc-sensors/server01/gpu/nvidia
pc-sensors/server01/disk/nvme0n1
```

You can adjust the broker or topic settings at the top of the script:
```bash
MQTT_HOST="<MQTT_IP"
MQTT_PORT="1883"
MQTT_TOPIC="pc-sensors"
```

---

## 📦 Dependencies

Installed automatically via the installer:
- `lm-sensors`
- `smartmontools`
- `mosquitto-clients`
- `pciutils`
- `fancontrol`

Optional (detected automatically):
- `nvidia-utils` (for NVIDIA GPUs)
- `rocm-smi` (for AMD GPUs)

---

## 🧰 Configuration

You can edit `system-sensors.sh` to customize:
- MQTT host and port  
- Topic root name  
- Update interval (`sleep 2` at the bottom of the loop)  
- Sensor inclusion/exclusion logic  

---

## 🔧 Service Management

Enable on boot:
```bash
sudo systemctl enable system-sensors
```

Disable:
```bash
sudo systemctl disable system-sensors
```

---

## 📝 Logging

This project now uses file-based logging implemented inside the monitoring script. The changes are summarized below (see `README-LOGGING.md` for details).

- Log file location: `/opt/system-sensors/data.log`
- Log format: `[YYYY-MM-DD HH:MM:SS] message`
- The script logs:
  - MQTT publishing information
  - Publishing errors (prefixed with `ERROR`)
  - Cycle start/end markers
- Automatic limiting: the script keeps a maximum of the most recent 1,000 entries in the log file; older entries are removed automatically (no `logrotate` required).

### Installation and Updating

New installation:
```bash
cd system-sensors-linux
sudo bash install.sh
```

Updating existing installation: run `install.sh` again — it will automatically:
- Stop the old service
- Create a backup of the old script (`.bak`)
- Install the new version
- Restart the service

```bash
cd system-sensors-linux
sudo bash install.sh
```

### Log File Commands

```bash
# Display the last 50 entries
tail -50 /opt/system-sensors/data.log

# Monitor the log in real time
tail -f /opt/system-sensors/data.log

# Search for errors
grep "ERROR" /opt/system-sensors/data.log

# Count all entries
wc -l /opt/system-sensors/data.log

# Display the entire log
cat /opt/system-sensors/data.log
```

### Directory Structure

```text
/opt/system-sensors/
├── system-sensors.sh          # Main script (current version)
├── system-sensors.sh.bak      # Backup of the previous version
└── data.log                   # Log file (max. 1,000 entries)
```

### Log Format Example

```text
[2026-08-17 14:23:45] === SYSTEM SENSORS MONITOR STARTED ===
[2026-08-17 14:23:45] Hostname: myserver
[2026-08-17 14:23:45] MQTT Host: 10.10.0.153:1883
[2026-08-17 14:23:45] Log file: /opt/system-sensors/data.log (max. 1,000 entries)
[2026-08-17 14:23:46] --- Cycle START ---
[2026-08-17 14:23:46] MQTT: Published pc-sensors/myserver/cpu/Core0 = 45
[2026-08-17 14:23:46] MQTT: Published pc-sensors/myserver/cpu/Core1 = 48
[2026-08-17 14:23:46] MQTT: Published pc-sensors/myserver/gpu/nvidia = 52
[2026-08-17 14:23:46] --- Cycle END ---
```

### Notes

- There is no need to install `logrotate` — automatic log limiting is built into the script
- Each execution of `install.sh` creates a backup of the previous version
- The logs do not contain any data from `journalctl`
- All entries are saved with timestamps
- MQTT errors are logged with the `ERROR` prefix

---

## 🩺 Troubleshooting

- **No sensors detected:**  
  Run `sudo sensors-detect` and reboot.
- **MQTT not receiving data:**  
  Check broker IP/port and topic in the script.  
  Test with:
  ```bash
  mosquitto_sub -h <host> -t "sensors/#" -v
  ```
- **Permission errors:**  
  Ensure `system-sensors.sh` is executable:
  ```bash
  sudo chmod +x /opt/system-sensors/system-sensors.sh
  ```

---

## 📜 License

This project is released under the **MIT License**.  
Use freely, modify, and share with attribution.


## 💡 Autor

**Błażej SQ2MTG**  
