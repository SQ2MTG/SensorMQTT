# System Sensors - Logging Configuration

## Changes to Logging and Interval

The `temp3.sh` script has been modified to:

### 2. Logging to a File Instead of `journalctl`

- All log entries are written to: `/opt/system-sensors/data.log`
- Format: `[YYYY-MM-DD HH:MM:SS] message`
- Includes:
  - MQTT publishing information
  - Publishing errors
  - Cycle start/end markers

### 3. Automatic Limiting of Logs to 1,000 Entries

- A maximum of the 1,000 most recent entries is kept in the file
- Older entries are automatically removed
- No `logrotate` is required — everything is handled within the script
- Saves disk space

## Installation and Update

### New Installation

```bash
cd system-sensors-linux
sudo bash install.sh
```

### Updating an Existing Installation

Simply run `install.sh` again — it will automatically:

- Stop the old service
- Create a backup of the old script (`.bak`)
- Install the new version
- Restart the service

```bash
cd system-sensors-linux
sudo bash install.sh
```

## Log File

### Location

- `/opt/system-sensors/data.log`

### Size

- Maximum of 1,000 entries
- Older entries are automatically deleted
- No compression (not needed)
- No backups

### Example Commands

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

# Last 3 hours (approximation)
tail -100 /opt/system-sensors/data.log
```

## Directory Structure

```text
/opt/system-sensors/
├── system-sensors.sh          # Main script (current version)
├── system-sensors.sh.bak      # Backup of the previous version
└── data.log                   # Log file (max. 1,000 entries)
```

## Service Management

```bash
# Check service status
sudo systemctl status system-sensors.service

# Restart the service
sudo systemctl restart system-sensors.service

# Stop the service
sudo systemctl stop system-sensors.service

# Start the service
sudo systemctl start system-sensors.service

# Enable automatic startup
sudo systemctl enable system-sensors.service

# Disable automatic startup
sudo systemctl disable system-sensors.service
```

## Log Format

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

## Notes

- There is no need to install `logrotate` — automatic log limiting is built into the script
- Each execution of `install.sh` creates a backup of the previous version
- The logs do not contain any data from `journalctl`
- All entries are saved with timestamps
- MQTT errors are logged with the `"ERROR"` prefix
