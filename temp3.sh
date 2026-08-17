#!/bin/bash

# Konfiguracja MQTT
MQTT_HOST="10.10.0.153"
MQTT_PORT="1883"      # dla MQTT TCP
#MQTT_PORT="9002/ws" # jeżeli chcesz używać websocket zamiast TCP
MQTT_TOPIC="pc-sensors"

# Konfiguracja logowania
LOG_DIR="/opt/system-sensors"
LOG_FILE="$LOG_DIR/data.log"
MAX_LINES=1000  # Maksymalnie 1000 wpisów w logu

# Hostname systemu
HOSTNAME=$(hostname)

# Kolory
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Funkcja do logowania
log_message() {
    local message=$1
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" >> "$LOG_FILE"
    
    # Sprawdzanie liczby linii i obcinanie jeśli przekroczy MAX_LINES
    local line_count=$(wc -l < "$LOG_FILE" 2>/dev/null || echo 0)
    if [ "$line_count" -gt "$MAX_LINES" ]; then
        # Zachowaj ostatnie MAX_LINES wpisów
        tail -n "$MAX_LINES" "$LOG_FILE" > "$LOG_FILE.tmp"
        mv "$LOG_FILE.tmp" "$LOG_FILE"
    fi
}

# Upewnij się, że folder logów istnieje
mkdir -p "$LOG_DIR"
# Utwórz plik logu jeśli nie istnieje
touch "$LOG_FILE"

# Inicjalizacja logu
log_message "=== SYSTEM SENSORS MONITOR STARTED ==="
log_message "Hostname: $HOSTNAME"
log_message "MQTT Host: $MQTT_HOST:$MQTT_PORT"
log_message "Log file: $LOG_FILE (max $MAX_LINES entries)"

get_color() {
    local temp=$1
    if (( temp >= 80 )); then
        echo -e "${RED}${temp}°C${NC}"
    elif (( temp >= 60 )); then
        echo -e "${YELLOW}${temp}°C${NC}"
    else
        echo -e "${GREEN}${temp}°C${NC}"
    fi
}

publish_mqtt() {
    local key=$1
    local value=$2
    mosquitto_pub -h "$MQTT_HOST" -p "$MQTT_PORT" -t "$MQTT_TOPIC/$HOSTNAME/$key" -m "$value" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        log_message "MQTT: Published $MQTT_TOPIC/$HOSTNAME/$key = $value"
    else
        log_message "ERROR: Failed to publish $MQTT_TOPIC/$HOSTNAME/$key"
    fi
}

while true; do
    clear
    echo -e "=== ${YELLOW}Monitor temperatur (${HOSTNAME})${NC} ==="
    log_message "--- Cycle START ---"

    # CPU (Twoja oryginalna sekcja - nietknięta)
    echo -e "\nCPU:"
    sensors | grep -E "Core|Package" | while read -r line; do
        temp=$(echo "$line" | grep -oP '\+?\K[0-9]+(?=\.?[0-9]*°C)' | head -n1)
        if [[ -n "$temp" ]]; then
            color_temp=$(get_color "$temp")
            name=$(echo "$line" | awk '{print $1}' | tr -d ':')
            echo "$line" | sed -E "s/([0-9]+\.?[0-9]*°C)/$color_temp/"
            publish_mqtt "cpu/$name" "$temp"
        else
            echo "$line"
        fi
    done

    # ================================================================= #
    # === OSTATECZNA, POPRAWIONA SEKCJA DLA POZOSTAŁYCH SENSORÓW === #
    # ================================================================= #
    echo -e "\nPozostałe czujniki (lm-sensors):"
    
    sensors | awk '
        # Zapamiętaj nazwę adaptera, gdy ją znajdziesz
        /^[a-zA-Z0-9]/ && !/:/ { adapter=$0; print ";"$0; next }
        # Drukuj linie "Adapter:" bez zmian
        /^Adapter:/ { print ";"$0; next }
        # Drukuj puste linie dla zachowania formatowania
        /^$/ { print ";"; next }
        # Ignoruj linie CPU, bo są już obsłużone wyżej
        /^(Core|Package)/ { next }
        # Jeśli mamy zapamiętany adapter, dodaj go jako prefiks do linii z danymi
        { if (adapter) print adapter";"$0 }
    ' | while IFS=';' read -r adapter line; do
        # Jeśli linia nie ma prefiksu adaptera, to jest to tylko linia formatująca (np. nazwa, pusta linia) - po prostu ją wyświetl
        if [ -z "$adapter" ]; then
            echo "$line"
            continue
        fi

        # === POPRAWIONE PARSOWANIE ===
        # Wyciągnij część linii PO pierwszym dwukropku, żeby nie czytać cyfr z etykiet
        data_part=$(echo "$line" | cut -d ':' -f 2-)
        # Wyciągnij PIERWSZĄ liczbę z tej właściwej części danych
        value=$(echo "$data_part" | grep -oP '[+-]?\K[0-9]+\.?[0-9]*' | head -n 1)
        # Nazwa sensora to część PRZED dwukropkiem
        name=$(echo "$line" | cut -d ':' -f 1 | xargs | tr -d ' ' | tr -d '+')

        # Publikacja do MQTT
        if [[ -n "$name" && -n "$value" ]]; then
            # Usuwamy myślniki z nazwy adaptera, bo mogą powodować problemy
            adapter_mqtt=$(echo "$adapter" | tr -d '-')
            # === POPRAWIONA ŚCIEŻKA MQTT (bez dodatkowego "sensors") ===
            publish_mqtt "$adapter_mqtt/$name" "$value"
        fi

        # Kolorowanie temperatur
        if [[ "$line" =~ °C && -n "$value" ]]; then
            temp_int=${value%.*}
            color_temp=$(get_color "$temp_int")
            echo "$line" | sed "s/[+-]\?[0-9]\+\.\?[0-9]*°C/$color_temp/"
        else
            # Wypisz pozostałe linie (RPM, V, W) bez zmian
            echo "$line"
        fi
    done


    # GPU (Twoja oryginalna sekcja - nietknięta)
    echo -e "\nGPU:"
    gpu_found=false

    # AMD GPU
    if command -v rocm-smi &>/dev/null; then
        temp=$(rocm-smi --showtemp | grep -oP '[0-9]+(?=\.0\s*C)' | head -n1)
        if [ -n "$temp" ]; then
            echo -e "AMD GPU: $(get_color "$temp")"
            publish_mqtt "gpu/amd" "$temp"
            gpu_found=true
        fi
    fi

    # NVIDIA GPU
    if command -v nvidia-smi &>/dev/null; then
        temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits | head -n1)
        if [[ "$temp" =~ ^[0-9]+$ ]]; then
            echo -e "NVIDIA GPU: $(get_color "$temp")"
            publish_mqtt "gpu/nvidia" "$temp"
            gpu_found=true
        fi
    fi

    # Inne GPU przez sensors
    if [ "$gpu_found" = false ]; then
        temp=$(sensors | grep -iE 'edge|junction|mem|gpu' | grep -oP '[0-9]+(?=\.?[0-9]*°C)' | head -n1)
        if [[ "$temp" =~ ^[0-9]+$ ]]; then
            echo -e "Inne GPU: $(get_color "$temp")"
            publish_mqtt "gpu/other" "$temp"
        else
            echo "Brak danych GPU"
        fi
    fi

    # Dyski (Twoja oryginalna sekcja - nietknięta)
    echo -e "\nDyski:"
    for disk in /dev/nvme* /dev/sd[a-z]; do
        [ -b "$disk" ] || continue
        temp=$(sudo smartctl -A "$disk" 2>/dev/null | awk '/Temperature_Celsius|Temperature:/ {print $10; exit}')
        if [[ "$temp" =~ ^[0-9]+$ ]]; then
            echo -e "$disk: $(get_color "$temp")"
            publish_mqtt "disk/$(basename "$disk")" "$temp"
        fi
    done

    log_message "--- Cycle END ---"
    sleep 10
done
