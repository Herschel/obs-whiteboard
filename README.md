# OBS Whiteboard Plugin

This plugin adds whiteboard/telestrator ability to OBS, allowing you draw using the mouse or touch onto the live display in a projector window. **The plugin currently works on Windows only**.

# Installation

 * Download the latest release from the [Releases page](https://github.com/Herschel/obs-whiteboard/releases).
 * Unzip the package somewhere on your computer.
 * Launch OBS, and select Tools -> Scripts.
 * Click the plus button to add a script, and select `whiteboard.lua` from the location where you unzipped the package.

# Usage
 * Click the plus in the Sources panel, and add a Whiteboard source to the scene.
 * Right-click the scene, and select Windowed Projector or Fullscreen Projceter.
 * Click and drag on the projector to draw on the scene.
 * To clear the scene, go to File -> Settings -> Hotkeys and add a hotkey for Clear Whiteboard.

# License

This project is licensed under the [MIT License](LICENSE.md). It uses the [winapi LUA bindings](https://github.com/stevedonovan/winapi) by Steve Donovan, licensed under the MIT License.
