#!/bin/bash
set -e

INSTALL_DIR="/opt/system-sensors"
SERVICE_NAME="system-sensors.service"
SCRIPT_NAME="system-sensors.sh"
SCRIPT_PATH="$INSTALL_DIR/$SCRIPT_NAME"
LOG_FILE="$INSTALL_DIR/data.log"

echo "=== system-sensors installer ==="

# Check if installation already exists
if [ -d "$INSTALL_DIR" ]; then
    echo "[INFO] Existing installation detected. Performing update..."
    
    # Stop the service
    echo "[1/6] Stopping service..."
    sudo systemctl stop $SERVICE_NAME || true
    echo "✓ Service stopped"
else
    echo "[1/6] New installation - creating directory..."
    sudo mkdir -p "$INSTALL_DIR"
    echo "✓ Directory created"
fi

# 2. System update
echo "[2/6] Updating packages..."
sudo apt update -y
echo "✓ Packages updated"

# 3. Install required packages
echo "[3/6] Installing required packages..."
sudo apt install -y lm-sensors smartmontools mosquitto-clients pciutils fancontrol
echo "✓ Required packages installed"

# (optional: GPU tools)
if lspci | grep -qi nvidia; then
    echo "NVIDIA GPU detected – installing nvidia-smi tools"
    sudo apt install -y nvidia-utils-535 || true
fi
if lspci | grep -qi amd; then
    echo "AMD GPU detected – installing rocm-smi"
    sudo apt install -y rocm-smi || true
fi

# 4. Update/Install monitoring script
echo "[4/6] Updating monitoring script..."

# Create a backup of the old script if it exists
if [ -f "$SCRIPT_PATH" ]; then
    echo "Creating backup of old script..."
    sudo cp "$SCRIPT_PATH" "$SCRIPT_PATH.bak"
fi

# Copy the new script
sudo cp temp3.sh "$SCRIPT_PATH"
sudo chmod +x "$SCRIPT_PATH"
echo "✓ Script installed/updated"

# 5. Create/Update systemd service
echo "[5/6] Configuring systemd service..."
cat <<EOF | sudo tee /etc/systemd/system/$SERVICE_NAME >/dev/null
[Unit]
Description=System Sensors MQTT Publisher
After=network.target

[Service]
ExecStart=$SCRIPT_PATH
Restart=always
RestartSec=5
StandardOutput=null
StandardError=null
User=root

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
echo "✓ systemd service configured"

# 6. Start the service
echo "[6/6] Starting/Restarting service..."
sudo systemctl enable $SERVICE_NAME
sudo systemctl start $SERVICE_NAME
echo "✓ Service started"

echo ""
echo "=== Installation/Update completed! ==="
echo ""
echo "Installation directory: $INSTALL_DIR"
echo "Script: $SCRIPT_PATH"
echo "Log file: $LOG_FILE"
echo ""
echo "Useful commands:"
echo "  Service status:        sudo systemctl status $SERVICE_NAME"
echo "  View logs:             tail -f $LOG_FILE"
echo "  Last 50 entries:       tail -50 $LOG_FILE"
echo "  Number of entries:     wc -l $LOG_FILE"
echo "  Restart service:       sudo systemctl restart $SERVICE_NAME"
echo ""
echo "Available sensors:"
sensors
