# <img src="icon.png" width="27"> Auto-Hide HUD for Assetto Corsa
Allows you to auto-hide any app on your HUD with custom rules based on the interior/exterior view and selected desktop.

![v1.3](https://github.com/user-attachments/assets/48fd9c41-47ad-4102-902c-e20012da4faa)

## Features
- Auto-hide all apps in interior or exterior view cameras.
- Auto-hide all apps in replays.
- Auto-hide virtual mirror (works even on servers with forced virtual mirror!).
- Auto-hide all or individual apps if there's no mouse movement or D-Pad inputs for a set amount of seconds.
- Create custom rules to control each app window on your HUD individually.
- Choose which desktop you want the rule to work on.
- Save, edit, and delete your custom rules - everything is saved in the `rules.ini` config file.

## Video Demo
[![Auto Hide HUD demo](https://img.youtube.com/vi/-D__XKbmtaQ/0.jpg)](https://youtu.be/-D__XKbmtaQ)

## Changelog
  - v1.34
    - Added compatibility wiith the new "Apps in pause menu" feature from CSP 0.2.7/0.2.8p1 to hopefully prevent any issues it may cause.
    - Fixed an issue where dualsense (and potentially dualshock?) D-Pads were not recognised.
  - v1.33
    - Fixed the desktop selection not affecting apps that are set to auto-hide on timer.
  - v1.32
    - Fixed the bug from 1.31 where apps set to timer-based hiding were starting to hide before pressing the Save button.
  - v1.31
    - Fixed start up bug caused by apps set to timer-based hiding.
  - v1.3
    - Implemented timer based hiding for individual apps.
    - Updated the "auto-hide all" option to integrate the timer based hiding there instead of a separate toggle.
  - v1.2
    - Implemented auto-hiding of virtual mirror.
    - Added validation for manual inputs into time-out slider.
  - v1.1
    - Implemented auto-hiding of apps when there's no mouse movement or D-Pad inputs for x continuous seconds.
    - Implemented auto-hiding of all apps in replay mode.
    - Added option to recognize F6 int/ext cameras.
    - Fixed 'remove' button restoring apps on the wrong desktops.
  - v1.02
    - Fixed 'Hide all apps' option not working with apps that are also used in custom rules in certain conditions.
  - v1.01
    - Fixed apps not hiding when switcing from Dash camera to any of the F2-F7 cameras.

## Installation
1. Unpack the archive.
2. Copy the `Auto_Hide_HUD` into the `..\steamapps\common\assettocorsa\apps\lua` folder or just drag & drop the contents of the unpacked archive into your assettocorsa root.
3. In-game, open the `Auto Hide HUD` app, set up your rules, save, and enjoy! :)

## Uninstallation
Just delete the app's folder from `..\steamapps\common\assettocorsa\apps\lua`.
