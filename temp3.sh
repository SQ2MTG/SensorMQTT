#!/bin/bash

# MQTT configuration
MQTT_HOST="10.10.0.153"
MQTT_PORT="1883"      # for MQTT TCP
#MQTT_PORT="9002/ws" # if you want to use websocket instead of TCP
MQTT_TOPIC="pc-sensors"

# Logging configuration
LOG_DIR="/opt/system-sensors"
LOG_FILE="$LOG_DIR/data.log"
MAX_LINES=1000  # Maximum 1000 log entries

# System hostname
HOSTNAME=$(hostname)

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Logging function
log_message() {
    local message=$1
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" >> "$LOG_FILE"
    
    # Check line count and trim if it exceeds MAX_LINES
    local line_count=$(wc -l < "$LOG_FILE" 2>/dev/null || echo 0)
    if [ "$line_count" -gt "$MAX_LINES" ]; then
        # Keep last MAX_LINES entries
        tail -n "$MAX_LINES" "$LOG_FILE" > "$LOG_FILE.tmp"
        mv "$LOG_FILE.tmp" "$LOG_FILE"
    fi
}

# Ensure log folder exists
mkdir -p "$LOG_DIR"
# Create log file if it does not exist
touch "$LOG_FILE"

# Initialize log
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
    echo -e "=== ${YELLOW}Temperature monitor (${HOSTNAME})${NC} ==="
    log_message "--- Cycle START ---"

    # CPU (original section - untouched)
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
    # === FINAL, FIXED SECTION FOR OTHER SENSORS === #
    # ================================================================= #
    echo -e "\nOther sensors (lm-sensors):"
    
    sensors | awk '
        # Remember adapter name when found
        /^[a-zA-Z0-9]/ && !/:/ { adapter=$0; print ";"$0; next }
        # Print "Adapter:" lines unchanged
        /^Adapter:/ { print ";"$0; next }
        # Print empty lines to preserve formatting
        /^$/ { print ";"; next }
        # Ignore CPU lines because they are already handled above
        /^(Core|Package)/ { next }
        # If we have remembered adapter, add it as prefix to data lines
        { if (adapter) print adapter";"$0 }
    ' | while IFS=';' read -r adapter line; do
        # If the line has no adapter prefix, it is just a formatting line (e.g., name, blank) - print it
        if [ -z "$adapter" ]; then
            echo "$line"
            continue
        fi

        # === FIXED PARSING ===
        # Extract the part of the line AFTER the first colon so we don't read numbers from labels
        data_part=$(echo "$line" | cut -d ':' -f 2-)
        # Extract the FIRST number from this actual data part
        value=$(echo "$data_part" | grep -oP '[+-]?\K[0-9]+\.?[0-9]*' | head -n 1)
        # Sensor name is the part BEFORE the colon
        name=$(echo "$line" | cut -d ':' -f 1 | xargs | tr -d ' ' | tr -d '+')

        # Publish to MQTT
        if [[ -n "$name" && -n "$value" ]]; then
            # Remove dashes from adapter name as they may cause issues
            adapter_mqtt=$(echo "$adapter" | tr -d '-')
            # === FIXED MQTT PATH (without additional "sensors") ===
            publish_mqtt "$adapter_mqtt/$name" "$value"
        fi

        # Coloring temperatures
        if [[ "$line" =~ °C && -n "$value" ]]; then
            temp_int=${value%.*}
            color_temp=$(get_color "$temp_int")
            echo "$line" | sed "s/[+-]\?[0-9]\+\.?[0-9]*°C/$color_temp/"
        else
            # Print other lines (RPM, V, W) unchanged
            echo "$line"
        fi
    done


    # GPU (original section - untouched)
    echo -e "\nGPU:"
    gpu_found=false

    # AMD GPU
    if command -v rocm-smi &>/dev/null; then
        temp=$(rocm-smi --showtemp | grep -oP '[0-9]+(?=\.0\s*C)' | head -n1)
        if [ -n "$temp" ]; then
            echo -e "AMD GPU: $(get_color \"$temp\")"
            publish_mqtt "gpu/amd" "$temp"
            gpu_found=true
        fi
    fi

    # NVIDIA GPU
    if command -v nvidia-smi &>/dev/null; then
        temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits | head -n1)
        if [[ "$temp" =~ ^[0-9]+$ ]]; then
            echo -e "NVIDIA GPU: $(get_color \"$temp\")"
            publish_mqtt "gpu/nvidia" "$temp"
            gpu_found=true
        fi
    fi

    # Other GPUs via sensors
    if [ "$gpu_found" = false ]; then
        temp=$(sensors | grep -iE 'edge|junction|mem|gpu' | grep -oP '[0-9]+(?=\.?[0-9]*°C)' | head -n1)
        if [[ "$temp" =~ ^[0-9]+$ ]]; then
            echo -e "Other GPU: $(get_color \"$temp\")"
            publish_mqtt "gpu/other" "$temp"
        else
            echo "No GPU data"
        fi
    fi

    # Disks (original section - untouched)
    echo -e "\nDisks:"
    for disk in /dev/nvme* /dev/sd[a-z]; do
        [ -b "$disk" ] || continue
        temp=$(sudo smartctl -A "$disk" 2>/dev/null | awk '/Temperature_Celsius|Temperature:/ {print $10; exit}')
        if [[ "$temp" =~ ^[0-9]+$ ]]; then
            echo -e "$disk: $(get_color \"$temp\")"
            publish_mqtt "disk/$(basename "$disk")" "$temp"
        fi
    done

    log_message "--- Cycle END ---"
    sleep 2
done
