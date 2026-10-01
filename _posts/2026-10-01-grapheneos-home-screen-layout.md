---
layout: post
title: Restoring a GrapheneOS home screen from XML
date: '2026-10-01 23:45:00'
tags: [grapheneos, android, launcher]
hidden: false
---

I wanted the launcher cache gone and ran:

```bash
adb shell pm clear com.android.launcher3 --cache-only
```

The help text is `pm clear [--user USER_ID] [--cache-only] PACKAGE`. With the flag after the package, the command still printed `Success` and deleted the launcher database. The home screen came back as the default grid: no folders, no widgets, and none of the placed icons. The same command against `com.android.systemui` clears the Quick Settings layout. The file below does not restore that.

Placing icons with `input draganddrop` works, one at a time. It is a slow way to rebuild a screen.

A backup from before the clear is how you get the old database back. On GrapheneOS that is Seedvault, under Settings, System, Backup. With no snapshot, Launcher3 can still load a workspace XML. The shell is not allowed to write it.

```bash
adb shell content call --uri content://com.android.launcher3.settings --method EXPORT_LAYOUT_XML
```

That fails with `SecurityException: requires android.permission.ACCESS_LAUNCHER_DATA`. `pm grant` says the permission is not a changeable type. There is no developer option for it, and a production GrapheneOS build has no `adb root`.

The hook that does work is the first-run layout. On an empty favorites database, `ModelDbController` reads the secure setting `launcher3.layout.provider`. If that value is a content-provider authority, the launcher opens:

```text
content://AUTHORITY/launcher_layout?version=1&gridWidth=4&gridHeight=5&hotseatSize=4
```

and parses the body with `AutoInstallsLayout`. I installed a small app that serves the XML. The sample, using Settings, Clock, Dialer and the desk clock widget, is [graphene-home-screen-restore](https://github.com/aioue/graphene-home-screen-restore). Replace those activities with your own.

JDK 17 and an Android SDK:

```bash
export ANDROID_HOME="$HOME/Android/Sdk"
./build.sh
CONFIRM=yes ./apply.sh
```

`apply.sh` installs the apk, sets the secure setting, and checks that `content read` prints XML. Then it runs `pm clear com.android.launcher3`, which is what makes the database empty so the hook runs. The clear replaces whatever is on the screen.

Logcat:

```text
LauncherLayout: serving layout for content://com.example.launcherlayout/launcher_layout?version=1&gridWidth=4&gridHeight=5&hotseatSize=4
LayoutParserFactory: Loading layout from com.example.launcherlayout
```

The root tag is `workspace`. `appicon` takes `packageName` and `className`, plus `screen`, `x` and `y`. `folder` takes `titleText` and at least two children that resolve, or the folder is removed. `appwidget` takes the provider class from `dumpsys appwidget`, plus `spanX` and `spanY`. The dock is `container="hotseat"` and `rank`.

```bash
adb shell cmd package resolve-activity --brief \
  -a android.intent.action.MAIN \
  -c android.intent.category.LAUNCHER com.android.settings
```

`com.android.settings/.Settings` means class `com.android.settings.Settings`. A missing component logs `Favorite not found` and is skipped. If the file adds no rows, the launcher loads its built-in default instead.

The grid is chosen when the database is created. Nothing is saved yet, so Launcher3 picks the device profile closest to the display size. `gridWidth` and `gridHeight` in that log line are the grid the XML was parsed against. Icons past the last column or row do not show.

I wanted 5 columns. The default profile was 4. In Launcher3 `device_profiles.xml`, `5_by_5` "Large Phone" is 406 dp by 694 dp. Override the display size so that profile is the nearest one, clear, then reset the size:

```bash
CONFIRM=yes GRID_SIZE=1100x2100 ./apply.sh
```

The script resets `wm size` after Home has started. The grid name is written into launcher prefs on that first start, so the reset leaves the 5-column grid in place. If `gridWidth` is wrong, choose another size and clear again.

The secure setting is only read for an empty database. Icons moved afterwards stay across a reboot. Stop a later clear from loading this file with:

```bash
adb shell settings delete secure launcher3.layout.provider
adb uninstall com.example.launcherlayout
```

{% include github-embed.html repo="aioue/graphene-home-screen-restore" file="src/com/example/launcherlayout/LayoutProvider.java" %}
