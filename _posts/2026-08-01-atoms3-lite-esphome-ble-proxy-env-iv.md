---
layout: post
title: 'AtomS3 Lite + ENV IV: ESPHome BLE proxy and room sensors in one box'
date: '2026-08-01 11:00:00'
tags: [esphome, home-assistant, bluetooth, homelab, m5stack]
hidden: false
---

I wanted a small Bluetooth proxy near two [Vent-Axia Svara](https://www.vent-axia.com/) extractors ([Pax](https://github.com/eriknn/ha-pax_ble) BLE fans) and a cheap way to read temperature, humidity, and pressure in the same spot. M5Stack's **AtomS3 Lite** (~£9) (ESP32-S3) plus the **Unit ENV IV** (~£6; [EOL from M5Stack](https://shop.m5stack.com/products/env-iv-unit-with-temperature-humidity-air-pressure-sensor-sht40-bmp280), still findable from resellers) (SHT40 + BMP280 on Grove I2C) turned out to be one ESPHome device that does both  -  about **£15** of hardware in total.

This post covers what the hardware is, what it reports to Home Assistant, how much RAM the firmware uses, and the sanitized YAML I run.

<p style="text-align:center"><img src="/ext/m5stack/atoms3-lite-env-iv-scale.jpg" alt="M5Stack AtomS3 Lite and Unit ENV IV sensor with a two-pence coin for scale" width="640" style="max-width:100%;height:auto;" /></p>

## The two parts (one firmware)

### M5Stack AtomS3 Lite (~£9)

Tiny ESP32-S3 board with Wi-Fi, Bluetooth 5 LE, a button, and four RGB LEDs under the cap.

From `esptool` when the board is connected over USB:

```
Chip type:          ESP32-S3 (QFN56) (revision v0.2)
Features:           Wi-Fi, BT 5 (LE), Dual Core + LP Core, 240MHz, Embedded Flash 8MB (GD)
Crystal frequency:  40MHz
```

In practice that means: enough flash for ESP-IDF + BLE proxy + sensors, dual-core headroom for Wi-Fi/BLE coexistence, and native USB-CDC for first flash (no separate USB-UART chip).

### M5Stack Unit ENV IV (~£6)

Grove/STEMMA QT breakout with:

- **Sensirion SHT40**  -  temperature and relative humidity (0x44 on I2C)
- **Bosch BMP280**  -  barometric pressure (0x76 on I2C)

On the AtomS3 Lite the Grove port maps to **SDA = GPIO2**, **SCL = GPIO1**. A short Grove cable is enough; if I2C scan finds nothing, swap the yellow/white data lines  -  AtomS3 Grove pin order is not always the cable default.

## What it does in Home Assistant

Primary job: **ESPHome Bluetooth proxy** so Home Assistant can reach Pax fans that only speak BLE GATT, not Wi-Fi. I use Erik Nordby's community integration [**ha-pax_ble**](https://github.com/eriknn/ha-pax_ble)  -  actively maintained, responsive on issues/PRs, and the right layer for Vent-Axia Svara hardware without a official HA integration.

Secondary job: publish room environment every five minutes (I kept env reads slow so the chip stays cool and I2C traffic stays out of the way of BLE).

After OTA to firmware **1.1.1** (ESPHome 2026.7.3), a typical live snapshot:

| Check | Status |
| --- | --- |
| ESPHome integration | Loaded  -  AtomS3 Lite Temp 5e5b70 |
| Firmware | **1.1.1** (ESPHome 2026.7.3) |
| Connectivity (Status) | On |
| Uptime | ~5 min (post-OTA) |
| Wi-Fi signal | **-53 dBm** (IoT VLAN) |
| Temperature | **25.0 °C** |
| Humidity | **47.7 %** |
| Pressure | **1017 hPa** |
| Absolute humidity | **11.0 g/m³** |
| Dew point | **13.2 °C** |
| Altitude (barometric) | **~-32 m** vs ISA 1013.25 hPa |
| LED | Blue when Wi-Fi up; green/red 10 s flash after each env publish |

### [Pax](https://github.com/eriknn/ha-pax_ble) fans via the proxy

With the Atom on the IoT VLAN and the proxy active, both Svara units stay reachable:

| Fan | State | RPM | Temperature |
| --- | --- | --- | --- |
| `top_bathroom_extractor` | Trickle ventilation | 1000 | 25.4 °C |
| `tom_bedroom_ensuite_extractor` | Trickle ventilation | 1641 | 22.9 °C |

Home Assistant sees full Pax entities (flow, humidity sensor on the unit, boost mode, silent hours, etc.) through [ha-pax_ble](https://github.com/eriknn/ha-pax_ble). The Atom does not run the Pax logic  -  it forwards BLE so the integration on the HA host can connect.

## RAM and flash budget

Compiled with ESPHome **2026.7.3**, ESP-IDF **5.5.5**, project version **1.1.1**:

```
RAM:   [====      ]  42.6% (used 145515 bytes from 341760 bytes)
Flash: [========  ]  75.1% (used 1377767 bytes from 1835008 bytes)
```

That leaves comfortable headroom for three BLE connection slots (Pax may hold active GATT sessions), Wi-Fi, captive portal fallback, and the LED/env automation scripts. I stayed on three slots rather than four  -  each slot costs roughly 1 KB RAM and Wi-Fi proxies rarely need more unless you are saturating connections.

## LED feedback (v1.1.1)

The four WS2812 LEDs under the button are status-only:

- **Blue**  -  Wi-Fi connected to HA
- **Red pulse**  -  fallback AP / Wi-Fi down
- **Green 10 s**  -  env reading published and HA API reachable
- **Red 10 s (solid)**  -  reading OK but Wi-Fi or API unreachable
- **Short press**  -  toggle LED; **long press ~1 s**  -  reboot

Handy when the puck is on a USB charger away from the desk and you want to know it is still talking to HA.

## Sanitized ESPHome config

Secrets (`wifi_ssid`, `wifi_password`, `api_encryption_key`, fallback AP password) live in `secrets.yaml` on the HA host  -  not in git. Example placeholders:

```yaml
wifi_ssid: "your-ssid"
wifi_password: "your-wifi-password"
api_encryption_key: "generate-with-esphome secrets create"
wifi_ap_password: "fallback-ap-password"
```

Full public YAML (no credentials):

<details markdown="1">
<summary><code>atoms3-lite-temp.yaml</code> (click to expand)</summary>

```yaml
# Public/sanitized ESPHome config for AtomS3 Lite + Unit ENV IV (SHT40 + BMP280).
# Secrets: copy secrets.yaml.example → secrets.yaml and fill in locally.
# BLE proxy baseline: https://github.com/esphome/bluetooth-proxies/tree/main/m5stack

substitutions:
  name: atoms3-lite-temp
  friendly_name: AtomS3 Lite Temp
  sea_level_pressure_hpa: "1013.25"
  wifi_ap_ssid: "AtomS3-Lite-Fallback"

esphome:
  name: ${name}
  friendly_name: ${friendly_name}
  min_version: 2025.8.0
  name_add_mac_suffix: true
  project:
    name: homelab.atoms3-ble-proxy
    version: "1.1.1"

esp32:
  variant: esp32s3
  framework:
    type: esp-idf

logger:
  baud_rate: 0
  level: INFO

api:
  encryption:
    key: !secret api_encryption_key

ota:
  - platform: esphome
    id: ota_esphome

wifi:
  ssid: !secret wifi_ssid
  password: !secret wifi_password
  ap:
    ssid: ${wifi_ap_ssid}
    password: !secret wifi_ap_password
  on_connect:
    - script.execute: led_wifi_connected
  on_disconnect:
    - script.execute: led_wifi_ap

captive_portal:

esp32_ble_tracker:

bluetooth_proxy:
  active: true
  cache_services: true
  connection_slots: 3

i2c:
  sda: GPIO2
  scl: GPIO1
  scan: true
  id: bus_grove

light:
  - platform: esp32_rmt_led_strip
    rgb_order: GRB
    pin: GPIO35
    num_leds: 4
    chipset: ws2812
    id: atom_led
    name: "${friendly_name} LED"
    restore_mode: RESTORE_DEFAULT_OFF
    effects:
      - pulse:
          name: Pulse
          transition_length: 1s

script:
  - id: led_wifi_connected
    then:
      - light.turn_on:
          id: atom_led
          brightness: 30%
          red: 0%
          green: 0%
          blue: 100%
  - id: led_wifi_ap
    then:
      - light.turn_on:
          id: atom_led
          brightness: 30%
          red: 100%
          green: 40%
          blue: 0%
          effect: Pulse
  - id: led_update_sent
    mode: restart
    then:
      - light.turn_on:
          id: atom_led
          brightness: 30%
          red: 0%
          green: 100%
          blue: 0%
      - delay: 10s
      - if:
          condition:
            wifi.connected:
          then:
            - script.execute: led_wifi_connected
          else:
            - script.execute: led_wifi_ap
  - id: led_update_failed
    mode: restart
    then:
      - light.turn_on:
          id: atom_led
          brightness: 30%
          red: 100%
          green: 0%
          blue: 0%
      - delay: 10s
      - if:
          condition:
            wifi.connected:
          then:
            - script.execute: led_wifi_connected
          else:
            - script.execute: led_wifi_ap

sensor:
  - platform: sht4x
    i2c_id: bus_grove
    address: 0x44
    update_interval: 300s
    precision: High
    heater_max_duty: 0.0
    temperature:
      name: "${friendly_name} Temperature"
      id: sht40_temperature
    humidity:
      name: "${friendly_name} Humidity"
      id: sht40_humidity

  - platform: bmp280_i2c
    i2c_id: bus_grove
    address: 0x76
    update_interval: 300s
    iir_filter: 4x
    temperature:
      id: bmp280_temperature
      internal: true
    pressure:
      name: "${friendly_name} Pressure"
      id: bmp280_pressure
      on_value:
        then:
          - if:
              condition:
                and:
                  - wifi.connected:
                  - api.connected:
              then:
                - script.execute: led_update_sent
              else:
                - script.execute: led_update_failed

  - platform: absolute_humidity
    name: "${friendly_name} Absolute Humidity"
    temperature: sht40_temperature
    humidity: sht40_humidity

  - platform: template
    name: "${friendly_name} Dew Point"
    unit_of_measurement: "°C"
    device_class: temperature
    icon: mdi:thermometer-alert
    update_interval: 300s
    lambda: |-
      return (243.5 * (log(id(sht40_humidity).state / 100.0) +
        ((17.67 * id(sht40_temperature).state) /
        (243.5 + id(sht40_temperature).state)))) /
        (17.67 - log(id(sht40_humidity).state / 100.0) -
        ((17.67 * id(sht40_temperature).state) /
        (243.5 + id(sht40_temperature).state)));

  - platform: template
    name: "${friendly_name} Altitude"
    unit_of_measurement: "m"
    icon: mdi:image-filter-hdr
    update_interval: 300s
    lambda: |-
      const float sea_level = ${sea_level_pressure_hpa};
      return ((id(sht40_temperature).state + 273.15) / 0.0065) *
        (powf(sea_level / id(bmp280_pressure).state, 0.190234) - 1);

  - platform: wifi_signal
    name: "${friendly_name} WiFi Signal"
    update_interval: 60s

  - platform: uptime
    name: "${friendly_name} Uptime"
    update_interval: 60s

binary_sensor:
  - platform: status
    name: "${friendly_name} Status"

  - platform: gpio
    name: "${friendly_name} Button"
    id: atom_button
    pin:
      number: GPIO41
      inverted: true
      mode:
        input: true
        pullup: true
    filters:
      - delayed_on_off: 50ms
    on_click:
      - min_length: 50ms
        max_length: 800ms
        then:
          - light.toggle: atom_led
      - min_length: 1000ms
        max_length: 5000ms
        then:
          - button.press: device_restart

button:
  - platform: restart
    name: "${friendly_name} Restart"
    id: device_restart
    internal: true

  - platform: safe_mode
    name: "${friendly_name} Safe Mode Boot"
    id: button_safe_mode

  - platform: factory_reset
    name: "${friendly_name} Factory Reset"
    id: factory_reset_btn
```

</details>

Broad structure:

- **ESP-IDF** on ESP32-S3 (not Arduino  -  lower RAM use for BLE + Wi-Fi)
- **`bluetooth_proxy`** with `active: true`, `cache_services: true`, `connection_slots: 3`
- **SHT4x + BMP280** on Grove I2C, 300 s update interval
- Derived **absolute humidity**, **dew point**, **altitude** templates
- **Wi-Fi signal** and **uptime** sensors for placement debugging
- **Captive portal** + named fallback AP for recovery

Official BLE proxy starting point: [esphome/bluetooth-proxies  -  M5Stack Atom S3](https://github.com/esphome/bluetooth-proxies/tree/main/m5stack).

## Links

- Pax BLE for Home Assistant: [github.com/eriknn/ha-pax_ble](https://github.com/eriknn/ha-pax_ble)
- ESPHome Bluetooth proxies: [github.com/esphome/bluetooth-proxies](https://github.com/esphome/bluetooth-proxies)
- M5Stack AtomS3 Lite: [docs.m5stack.com  -  AtomS3 Lite](https://docs.m5stack.com/en/core/AtomS3%20Lite)
- M5Stack Unit ENV IV: [docs.m5stack.com  -  Unit ENV IV](https://docs.m5stack.com/en/unit/env%20IV)

If you are running Vent-Axia fans and HA, ha-pax_ble is worth a star.
