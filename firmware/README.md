# CarGuard Firmware (ESP8266 / NodeMCU)

Arduino sketch for the vehicle monitor module that the Flutter app talks to.

## Flashing

1. Open `car_guard/car_guard.ino` in Arduino IDE
2. Board: **NodeMCU 1.0 (ESP-12E Module)**, 80 MHz, 4M (3M SPIFFS)
3. Libraries (Library Manager): `OneWire`, `DallasTemperature`,
   `WebSockets` (links2004), `ESP8266WiFi`/`ESP8266WebServer`/`DNSServer`/
   `EEPROM` come with the ESP8266 core
4. Upload — or flash over-the-air later from the app/AP at
   `http://192.168.4.1/update`

## Wiring

| Signal | Pin |
| --- | --- |
| DS18B20 data (4.7kΩ pull-up to 3V3) | D1 (GPIO5) |
| Buzzer (active, HIGH = on) | D2 (GPIO4) |
| Relay / fan | D3 (GPIO0) |
| Voltage divider center tap | A0 |

Default access point: **SSID `CarGaurd` / password `12345678`**, device IP
`192.168.4.1`, WebSocket on port **81**.

## Protocol

### `/data` (HTTP, every second over WebSocket too)

```json
{
  "temp": 32.5, "volt": 12.17,
  "maxTemp": 97.0, "fanOnTemp": 90.0,
  "minVolt": 12.0, "maxVolt": 14.8, "offset": 1.5,
  "fanState": 0,
  "alarm": 0, "muted": 0
}
```

CSV variant (WebSocket):

```
temp,volt,fanState,?,maxTemp,fanOnTemp,minVolt,maxVolt,offset,alarm,muted
```

`alarm` and `muted` are the **[APP SYNC]** additions: they mirror the
module buzzer so the app can show its state. Both are appended at the end
of the CSV and as new JSON keys, so older dashboards keep working.

### Endpoints

| Endpoint | Purpose | Reply |
| --- | --- | --- |
| `/data` | live readings + limits | JSON |
| `/getallsettings` | everything incl. serial, install date, R1/R2, calibration | JSON |
| `/saveallsettings?maxTemp=&fanOnTemp=&minVolt=&maxVolt=&offset=` | alarm limits | `OK` |
| `/saveadvancedsettings?offset=&voltCalib=&r1=&r2=&sensorPullUp=&installDate=` | calibration | `OK` |
| `/calibratevoltage?realVolt=` | voltage wizard (8–18 V) | `OK,<factor>` |
| `/getwifisettings` / `/savewifi?ssid=&password=` | AP credentials | JSON / `OK` |
| `/testfan` | run the fan for 5 s | `OK` |
| `/mute` | silence the buzzer until the danger clears | `OK` |
| `/restart` | reboot the module | `RESTARTING` |
| `/update` | OTA firmware upload page | HTML |

### Value ranges enforced by the firmware

| Value | Range |
| --- | --- |
| Alarm temperature | 50–150 °C |
| Fan-on temperature | 40–140 °C (hysteresis 5 °C) |
| Min voltage | 8.0–14.0 V (alarm after 2 s out of range) |
| Max voltage | 12.0–18.0 V |
| Temp offset | ±10 °C |
| R1 / R2 / pull-up | 0–100000 Ω |
| voltCalib | 0.1–10.0 |

The mobile app validates the same ranges before sending, so the module
never receives values it would reject.
