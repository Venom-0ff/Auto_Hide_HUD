# <img src="icon.png" width="27"> Auto-Hide HUD for Assetto Corsa
Allows you to auto-hide any app on your HUD with custom rules based on the interior/exterior view and selected desktop.

![Example](https://github.com/user-attachments/assets/096aa25c-e646-42ea-bd57-c3a4f3e88f53)

## Features
- Auto-hide all apps in interior or exterior view cameras.
- Create custom rules to control each app window on your HUD individually.
- Choose which desktop you want the rule to work on.
- Save, edit, and delete your custom rules - everything is saved in the `rules.ini` config file.

## Video Demo
[![Auto Hide HUD demo](https://img.youtube.com/vi/-D__XKbmtaQ/0.jpg)](https://youtu.be/-D__XKbmtaQ)

## Changelog
  - v1.1
    - Implemented auto-hiding of apps when there's no mouse movement or D-Pad inputs for x continuous seconds
    - Implemented auto-hiding of all apps in replay mode
    - Added option to recognize F6 int/ext cameras
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
