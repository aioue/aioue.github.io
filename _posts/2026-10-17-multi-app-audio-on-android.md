---
layout: post
title: Multi-app audio on Android, and why the toggle waits for a reboot
date: '2026-10-17 05:30:00 +0100'
last_modified_at: '2026-10-17'
tags: [android, audio, grapheneos, shizuku]
hidden: false
---

Sometimes I want VLC or a browser to play at the same time as YouTube and Spotify. Sometimes I want the normal one-app-at-a-time behaviour back. On a Pixel 8a running GrapheneOS (Android 17), no root, this turned into a longer dig than expected.

## The flag

Android's audio focus policy is controlled by a single settings key:

```bash
adb shell settings put system multi_audio_focus_enabled 1
```

`audioserver` reads it once, in `MediaFocusControl`'s constructor. You can check the live state with:

```bash
adb shell dumpsys audio | grep -i multi
```

which shows `Multi Audio Focus enabled :true` or `false`.

The catch: nothing watches that setting after startup. The only runtime setter is the hidden `AudioManager.setMultiAudioFocusEnabled`, which calls `updateMultiAudioFocus`. On this phone that hidden call is a oneway binder, and when it arrives from adb or Shizuku (uid 2000), `AudioService` then does `Settings.System.putIntForUser` as package `android` without `clearCallingIdentity`. Logcat tells the story:

```
SecurityException: Package android does not belong to 2000
```

The live flag does not change. `settings put` on its own does not change what `dumpsys` reports either. A reboot does: with the setting at 0, `dumpsys` came back `false`; set it back to 1, reboot, and it reports `true`. Shell cannot `stop` or `kill` audioserver to shortcut the restart.

## Why new players can still pick it up

`isMultiFocus()` reads the setting when a new focus environment is created, so an app launched after the `settings put` sees the new policy. Apps that already hold focus stay on the cached flag - which is why turning the setting off does not stop what is already playing. Practical sequence: set the flag, then start the second player.

## State of the art

- [channelramble/multiAPPaudio](https://github.com/channelramble/multiAPPaudio) - `settings put` plus reboot. Their notes say the live API is not possible.
- [legendsayantan/ShizuTools](https://github.com/legendsayantan/ShizuTools) MixedAudio - does not touch the flag. Per-app `appops set <pkg> TAKE_AUDIO_FOCUS ignore` applies immediately and lets that app keep playing over others. It does not restore one-at-a-time.
- `PLAY_AUDIO ignore` mutes one app.
- crDroid updates the flag from inside audioserver. Not portable to a Pixel.
- Root-only routes: kill audioserver, or an LSPosed module. Not available here.

No public non-root command flips the live flag. The defect belongs in AOSP - the uid 2000 path in `setMultiAudioFocusEnabled` - not as a GrapheneOS-only patch. Filed as [issue 574515432](https://issuetracker.google.com/issues/574515432).

## Pausing from an app is not the same thing

An app can pause other `MediaSession`s, and that looks similar from the couch. It is not: both apps are allowed to start, you hear a short overlap, and anything without a media session - games, many browser tabs, alarms - never gets paused. The paused app can also resume itself, because it never lost audio focus.

## The app

I wrapped this in my phone app. The screen keeps two switches: "Let media apps play at the same time" (saved immediately, applied at next reboot) and "Restore music after calls", which resumes media after a phone call while multi-app is on. That one did resume in testing because the player restarted itself - the app only presses play if the session is still paused. A red "Reboot to apply" chip shows when the saved setting and the live `dumpsys` flag disagree. After a reboot they match and the chip goes away.
