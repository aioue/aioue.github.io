---
layout: post
title: Home Assistant Voice PE on a self-hosted Assist pipeline
date: '2026-07-23 02:45:00'
tags: [home-assistant, voice, homelab, proxmox, wyoming]
hidden: false
---

I wanted a local voice puck without reviving my lapsed Nabu Casa subscription. The [Home Assistant Voice Preview Edition](https://www.home-assistant.io/voice-pe/) looked right: ESP32-S3 hardware, Wyoming STT/TTS, Assist pipeline on my own HA instance (VM 101 on Proxmox, Ryzen 5650G). An evening of USB and language-code friction later, it works. Room control like Alexa's "study off" does not - but announcements and Q&A are a better fit anyway.

## The setup

- **Host:** ASRock DeskMini X300M-STX / 5650G, Proxmox 8
- **HA:** VM 101, `cpu: host` (Piper/Whisper addons need x86_v2 flags)
- **Voice PE:** Study area, firmware 26.6.0, wake word "Okay Nabu"
- **Pipeline:** faster-whisper (STT) + Piper (TTS), full local processing
- **Public URL:** Caddy on ubuntu-cloud → `https://ha.home.aioue.net` (no `:8123`)

No Home Assistant Cloud. Firmware via [esphome.github.io/home-assistant-voice-pe](https://esphome.github.io/home-assistant-voice-pe), onboarding via the Voice Satellite wizard.

## USB and flashing

Chrome showed no serial device. Bootloader mode (hold centre button, plug in) left the LED ring dark - normal, not dead.

What fixed detection:

1. **Different USB-C cable** - the first was charge-only or flaky.
2. **Direct Mac USB-C port** - not through a Digital AV adapter.

The installer then saw the puck (existing 25.12.1 → update to 26.6.0). First flash failed mid-write (`Failed to write compressed data to flash after seq 106`). Second attempt on a direct port succeeded.

## Onboarding traps

### External URL with `:8123`

"Add to Home Assistant" redirected to `https://ha.home.aioue.net:8123/...`. Caddy serves HA on 443; nothing listens on 8123 at that hostname. Fix: **Settings → System → Network** → external URL `https://ha.home.aioue.net` (no port). LAN `http://192.168.1.240:8123` stays as internal.

### Piper language tags

Try and the wake word flashed red. HA reported:

```
Failed to perform the action assist_satellite/announce. Language 'en-gb' not supported
```

British English in the wizard had set `tts_language: en-gb`. Piper Wyoming only accepts tags like **`en_GB`** and **`en_US`** - not `en`, not `en-gb`. Querying the Wyoming `describe` payload confirmed it.

Working pipeline fields:

| Field | Value |
|-------|-------|
| `language` | `en-GB` |
| `stt_language` | `en` |
| `tts_language` | `en_GB` |
| `tts_voice` | `en_GB-jenny_dioco-medium` |

### Pipeline voice ≠ Piper addon default

Piper addon was set to "English female low"; I heard a male voice. Assist uses the **pipeline** `tts_voice`, not the addon default. After aligning both to the same `en_GB-*` voice, behaviour matched.

## Latency (state history, not log scraping)

From `assist_satellite` state transitions on the HA recorder:

| Phase | Typical |
|-------|---------|
| Listening (user speaking) | 2.5-5.7 s |
| Processing (STT + intent) | <0.5 s |
| Responding (TTS playback) | 1.7-3.1 s |
| **Total (short phrase)** | **~4-5 s** |

Announce-only ("Try" in the wizard): ~2.7 s average TTS. STT is not the bottleneck; listening time scales with how long you talk. Moving Whisper to a dedicated LXC or Vulkan on the 5650G iGPU is deferred - not urgent at these numbers.

## "Study off" and why I stopped chasing it

Alexa maps "study off" to a room light group. I had **24 study-related entities** exposed to Assist: 14 Hue scenes (`Study Bright`, `Study Relax`, …), four lights, two Cast players named `study`, sensors. Result:

> There are multiple devices called study

Fixable with exposure hygiene (room groups only) or one global `{area} off` custom sentence - but maintaining per-room voice aliases is not what I want from this puck. **Pivot:** use the PE for prompts and Q&A (morning motion in the study → weather, chore check-in, maybe `ask_question` later). OpenAI Conversation (`gpt-4o-mini`, `prefer_local_intents`) when open-ended chat is worth the API cost.

## What worked

- Hardware is solid once flashed; no cloud subscription required
- Wyoming on the HA VM is fast enough for short Q&A
- Voice Satellite wizard + Assist pipeline is the right integration path
- USB cable and `en_GB` are the two non-obvious gotchas worth documenting

## What I'd do differently

- Flash from a direct port first; skip the hub
- Set external URL before clicking "Add to Home Assistant"
- Set `tts_language: en_GB` before the first Try
- Don't expose every Hue scene to Assist if you care about room names

## Next

Morning briefing automation: `binary_sensor.top_study_motion_osram_occupancy` → `assist_satellite.announce` on `assist_satellite.home_assistant_voice_09414f_assist_satellite` → template with weather + chore state. Phase 2: `ask_question` for yes/no. Phase 3: OpenAI for follow-up chat.

Ansible repo: [proxmox-setup](https://github.com/aioue/proxmox-setup) (`roles/vm_homeassistant`, Wyoming pipeline defaults in `configure-homeassistant.yml`).
