#!/bin/bash
set -e

INSTALL_DIR="/opt/system-sensors"
SERVICE_NAME="system-sensors.service"
SCRIPT_NAME="system-sensors.sh"
SCRIPT_PATH="$INSTALL_DIR/$SCRIPT_NAME"
LOG_FILE="$INSTALL_DIR/data.log"

echo "=== Instalator system-sensors ==="

# Check if installation already exists
if [ -d "$INSTALL_DIR" ]; then
    echo "[INFO] Wykryto istniejącą instalację. Przeprowadzanie aktualizacji..."
    
    # Stop the service
    echo "[1/6] Zatrzymywanie usługi..."
    sudo systemctl stop $SERVICE_NAME || true
    echo "✓ Usługa zatrzymana"
else
    echo "[1/6] Nowa instalacja - tworzenie katalogu..."
    sudo mkdir -p "$INSTALL_DIR"
    echo "✓ Katalog utworzony"
fi

# 2. System update
echo "[2/6] Aktualizacja pakietów..."
sudo apt update -y
echo "✓ Pakiety zaktualizowane"

# 3. Install required packages
echo "[3/6] Instalacja wymaganych pakietów..."
sudo apt install -y lm-sensors smartmontools mosquitto-clients pciutils fancontrol
echo "✓ Wymagane pakiety zainstalowane"

# (optional: GPU tools)
if lspci | grep -qi nvidia; then
    echo "Wykryto NVIDIA GPU – instalacja narzędzi nvidia-smi"
    sudo apt install -y nvidia-utils-535 || true
fi
if lspci | grep -qi amd; then
    echo "Wykryto AMD GPU – instalacja rocm-smi"
    sudo apt install -y rocm-smi || true
fi

# 4. Update/Install monitoring script
echo "[4/6] Aktualizacja skryptu monitorującego..."

# Create a backup of the old script if it exists
if [ -f "$SCRIPT_PATH" ]; then
    echo "Tworzenie kopii zapasowej starego skryptu..."
    sudo cp "$SCRIPT_PATH" "$SCRIPT_PATH.bak"
fi

# Copy the new script
sudo cp temp3.sh "$SCRIPT_PATH"
sudo chmod +x "$SCRIPT_PATH"
echo "✓ Skrypt zainstalowany/zaktualizowany"

# 5. Create/Update systemd service
echo "[5/6] Konfiguracja usługi systemd..."
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
echo "✓ Usługa systemd skonfigurowana"

# 6. Start the service
echo "[6/6] Uruchamianie/Restartowanie usługi..."
sudo systemctl enable $SERVICE_NAME
sudo systemctl start $SERVICE_NAME
echo "✓ Usługa uruchomiona"

echo ""
echo "=== Instalacja/Aktualizacja zakończona! ==="
echo ""
echo "Katalog instalacji: $INSTALL_DIR"
echo "Skrypt: $SCRIPT_PATH"
echo "Log: $LOG_FILE"
echo ""
echo "Komendy przydatne:"
echo "  Status usługi:        sudo systemctl status $SERVICE_NAME"
echo "  Wyświetlanie logów:   tail -f $LOG_FILE"
echo "  Ostatnie 50 wpisów:   tail -50 $LOG_FILE"
echo "  Liczba wpisów:        wc -l $LOG_FILE"
echo "  Restart usługi:       sudo systemctl restart $SERVICE_NAME"
echo ""
echo "Dostępne czujniki:"
sensors
