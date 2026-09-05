# System Sensors - Logging Configuration

## Zmiana logowania i interwału

Skrypt `temp3.sh` został zmodyfikowany, aby:

### 2. **Logging do pliku zamiast journalctl**
   - Wszystkie wpisy logów są zapisywane do: `/opt/system-sensors/data.log`
   - Format: `[YYYY-MM-DD HH:MM:SS] message`
   - Zawiera:
     - Informacje o publikacji MQTT
     - Błędy publikacji
     - Znaczniki rozpoczęcia/zakończenia cyklu

### 3. **Automatyczne ograniczanie logów do 1000 wpisów**
   - Maksymalnie 1000 ostatnich wpisów w pliku
   - Starsze wpisy są automatycznie usuwane
   - Brak logrotate - wszystko odbywa się w skrypcie
   - Oszczędzanie miejsca na dysku

## Instalacja i Aktualizacja

### Nowa instalacja:
```bash
cd system-sensors-linux
sudo bash install.sh
```

### Aktualizacja istniejącej instalacji:
Prosto uruchom install.sh jeszcze raz - automatycznie:
- Zatrzyma starą usługę
- Kopię zapasową starego skryptu (`.bak`)
- Zainstaluje nową wersję
- Restartuje usługę

```bash
cd system-sensors-linux
sudo bash install.sh
```

## Plik Logu

### Lokalizacja
- `/opt/system-sensors/data.log`

### Rozmiar
- Maksymalnie 1000 wpisów
- Starsze wpisy są automatycznie kasowane
- Brak kompresji (nie potrzebna)
- Brak backupów

### Przykłady poleceń

```bash
# Wyświetlanie ostatnich 50 wpisów
tail -50 /opt/system-sensors/data.log

# Monitorowanie w czasie rzeczywistym
tail -f /opt/system-sensors/data.log

# Wyszukiwanie błędów
grep "ERROR" /opt/system-sensors/data.log

# Liczenie wszystkich wpisów
wc -l /opt/system-sensors/data.log

# Wyświetlanie całego logu
cat /opt/system-sensors/data.log

# Ostatnie 3 godziny (przybliżenie)
tail -100 /opt/system-sensors/data.log
```

## Struktura Katalogów

```
/opt/system-sensors/
├── system-sensors.sh          # Główny skrypt (aktualny)
├── system-sensors.sh.bak      # Kopia zapasowa poprzedniej wersji
└── data.log                   # Plik logu (max 1000 wpisów)
```

## Zarządzanie Usługą

```bash
# Status usługi
sudo systemctl status system-sensors.service

# Restart usługi
sudo systemctl restart system-sensors.service

# Zatrzymanie usługi
sudo systemctl stop system-sensors.service

# Uruchomienie usługi
sudo systemctl start system-sensors.service

# Włączenie/Wyłączenie autostartu
sudo systemctl enable system-sensors.service
sudo systemctl disable system-sensors.service
```

## Format Logów

```
[2026-08-17 14:23:45] === SYSTEM SENSORS MONITOR STARTED ===
[2026-08-17 14:23:45] Hostname: myserver
[2026-08-17 14:23:45] MQTT Host: 10.10.0.153:1883
[2026-08-17 14:23:45] Log file: /opt/system-sensors/data.log (max 1000 entries)
[2026-08-17 14:23:46] --- Cycle START ---
[2026-08-17 14:23:46] MQTT: Published pc-sensors/myserver/cpu/Core0 = 45
[2026-08-17 14:23:46] MQTT: Published pc-sensors/myserver/cpu/Core1 = 48
[2026-08-17 14:23:46] MQTT: Published pc-sensors/myserver/gpu/nvidia = 52
[2026-08-17 14:23:46] --- Cycle END ---
```

## Notki

- Nie trzeba instalować logrotate - automatyczne ograniczenie jest w skrypcie
- Każde uruchomienie `install.sh` tworzy kopię zapasową poprzedniej wersji
- Logi nie zawierają żadnych danych z journalctl
- Wszystkie wpisy są zapisywane ze znacznikiem czasu
- Błędy MQTT są logowane z prefiksem "ERROR"
