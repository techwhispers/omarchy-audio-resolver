# Omarchy Plugin Lessons
Verified against `/usr/share/omarchy/shell` and this Audio Resolver plugin.
## 1. BarWidget Structure
Use `BarWidget` as the root for a bar-only widget. Its base properties are
`bar`, `moduleName`, and `settings` (none are QML-`required`); set
`moduleName` to the manifest/widget ID. The host injects `bar`.
Mandatory imports for the installed minimal menu widget are:
`import QtQuick` and `import qs.Ui`. Add `import qs.Commons` for `Style`,
`Color`, or shared helpers. The widget supplies its own implicit size; the
installed menu uses `implicitWidth: button.implicitWidth`,
`implicitHeight: button.implicitHeight`. Typical row spacing is
`Style.space(6)`.
```qml
import QtQuick
import qs.Ui
BarWidget {
  id: root
  moduleName: "example.widget"
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "E"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton && root.bar)
        root.bar.run("example-command")
    }
  }
}
```
The manifest needs `"kinds": ["bar-widget"]` and
`"entryPoints": {"barWidget": "BarWidget.qml"}`.
## 2. Click -> Panel Wiring
Audio Resolver's exact bar interaction is:
```qml
BarIconButton {
  id: button
  anchors.fill: parent
  bar: root.bar
  onPressed: function(buttonCode) {
    if (buttonCode === Qt.LeftButton) root.toggle()
    else if (buttonCode === Qt.RightButton) root.setWatching(!root.watching)
  }
}
```
The root is `Panel` (with `import QtQuick`, `import Quickshell`,
`import Quickshell.Io`, `import qs.Commons`, and `import qs.Ui`). `Panel`
owns `PanelController`; `root.toggle()` changes `root.opened`. The popup is
inline:
```qml
KeyboardPanel {
  id: panel
  anchorItem: button
  owner: root
  bar: root.bar
  open: root.opened
}
```
`Panel` supplies `IpcHandler` when `manageIpc` is true. `KeyboardPanel` is a
`WlrLayer.Overlay` layer-shell surface: it overlays the bar and does not push
bar content.
## 3. Context Menus
This release has no generic `ContextMenu` type. Use `MouseArea` plus
`PopupCard` for a bar-level menu:
```qml
property bool menuOpen: false
MouseArea {
  anchors.fill: parent
  acceptedButtons: Qt.LeftButton | Qt.RightButton
  onClicked: function(mouse) {
    if (mouse.button === Qt.RightButton) root.menuOpen = !root.menuOpen
    else root.toggle()
  }
}
PopupCard {
  anchorItem: root; bar: root.bar; owner: root; open: root.menuOpen
  contentWidth: fittedContentWidth(240)
  contentHeight: fittedContentHeight(column.implicitHeight)
  Column { id: column; Button { text: "Run"; onClicked: root.run() } }
}
```
Per-row controls use `Button.onRightClicked` or
`PanelSlider.onRightClicked`, not a second full-row `MouseArea`. Pass item
data from a delegate:
```qml
Repeater {
  model: root.items
  delegate: Item {
    required property var modelData
    required property int index
    Button {
      text: modelData.name
      onClicked: root.openItem(modelData.id, index)
      onRightClicked: root.menuFor(modelData.id, index)
    }
  }
}
```
The installed network panel uses this explicit `modelData`/`index` wrapper.
Use `onClicked`, not `onPressed`, for menu activation; `acceptedButtons`
excludes wheel events, while `ListView`/`Flickable` retains scroll/drag.
## 4. Actions & IPC
Exact shell IPC wiring:
```qml
IpcHandler {
  target: root.ipcTarget
  function toggle(): void { root.toggle() }
}
```
Audio Resolver's backend action is a `Process` with an argv array. It sets an
in-progress property before starting, disables the button, and clears it in
`onExited`; stderr becomes the failure message:
```qml
Process {
  id: proc
  onExited: root.busy = false
}
Button {
  enabled: !root.busy
  text: root.busy ? "Working..." : "Run"
  onClicked: {
    root.busy = true
    proc.command = [root.pluginDir + "/run.sh", root.itemId]
    proc.running = true
  }
}
```
## 5. Persistence
Bar placement: `~/.config/omarchy/shell.json`. Plugin config:
`~/.config/audio-resolver/config.env`. Import manifest:
`~/.local/state/audio-resolver/imports.json`. Log:
`~/.local/share/audio-resolver/convert.log`. No SQLite is used.
`configure.py` reads config on save and atomically rewrites
`SOURCE_DIR`, `DESTINATION_DIR`, and `OUTPUT_LABEL`. The state helper reads
and writes JSON on every `check`/`record`. `Panel.qml` polls config/service
state every 2000 ms, so external service changes appear in the UI.
Missing config displays “Not configured”. Missing or invalid import JSON
becomes `{}` because `load()` catches `FileNotFoundError` and
`JSONDecodeError`. Paths are absolute/XDG-resolved, not plugin-relative.
## 6. Model / State Management
Audio Resolver has no item list: QML properties (`watching`, `sourceDir`,
`destinationDir`, `outputLabel`, status) are the UI single source of truth;
the backend manifest is persistence only. Installed plugins use either
`ListModel` + `ListView` or a JS array + `Repeater`. `ListModel.append`,
`remove`, and `set` refresh delegates; a changed JS array must be reassigned.
## 7. Notifications & Feedback
Conversion appends to `~/.local/share/audio-resolver/convert.log`; the panel
shows `tail -n 1` of that file. Success calls:
```bash
notify-send "Audio Resolver" "Converted ${filename}"
```
Failures log `ERROR: conversion failed: ...` and return status 1. Manual
import displays stderr; `Import Now` is disabled while importing or watching.
## 8. Build & Test Process
Use this verified command sequence:
```bash
bash -n audio-resolver-convert.sh audio-resolver-watch.sh \
  audio-resolver-import.sh select-folder.sh
python3 -m py_compile configure.py audio-resolver-state.py
python3 -m json.tool manifest.json >/dev/null
git diff --check
omarchy plugin validate .
omarchy restart shell
```
`omarchy plugin validate .` passed with exit code 0 and no output.
`/usr/lib/qt6/bin/qmllint Panel.qml` exited successfully but warned that
`qs.Commons`, `qs.Ui`, `BarIconButton`, `PanelHero`, `ToggleSwitch`,
`PanelSectionHeader`, `Button`, `TextField`, and `KeyboardPanel` were
unresolved outside the shell import path. That is not runtime proof.
Without the shell, test scripts, Python, JSON, FFmpeg/ffprobe, and state/config
behavior directly; this plugin has no QML unit-test harness. Fastest loop:
edit -> syntax checks -> `omarchy plugin validate .` ->
`omarchy restart shell` -> inspect `~/.local/share/audio-resolver/convert.log`.
## 9. Gotchas & Surprises
- `gdbus monitor` could not receive the portal response because it is sent to
  the original D-Bus connection. `omarchy file select --directory` works.
- FFmpeg needs `-f mov` because `.mov.part` does not identify the container.
- `set -u` exposed an uninitialised filename in an earlier converter.
- The watcher must scan existing files before `inotifywait`, or files copied
  while stopped are missed.
- Standalone `qmllint` lacks the shell's `qs.*` import path; lint success does
  not prove runtime behavior.
- `Panel` uses an overlay layer and `PanelController`; logical `open` can
  differ briefly from the mapped fade-out surface.
## 10. Reusable Patterns (Copy-Paste Ready)
### BarWidget skeleton
```qml
import QtQuick
import qs.Ui
BarWidget {
  id: root; moduleName: "example.widget"
  implicitWidth: button.implicitWidth; implicitHeight: button.implicitHeight
  WidgetButton {
    id: button; anchors.fill: parent; bar: root.bar; text: "E"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.bar.run("example-command")
    }
  }
}
```
### Context menu
```qml
import qs.Ui
property bool menuOpen: false
MouseArea {
  anchors.fill: parent
  acceptedButtons: Qt.LeftButton | Qt.RightButton
  onClicked: function(mouse) {
    if (mouse.button === Qt.RightButton) root.menuOpen = !root.menuOpen
  }
}
PopupCard {
  anchorItem: root; bar: root.bar; owner: root; open: root.menuOpen
  contentWidth: fittedContentWidth(240)
  contentHeight: fittedContentHeight(column.implicitHeight)
  Column { id: column; Button { text: "Run"; onClicked: root.run() } }
}
```
### UI -> backend with progress state
```qml
Process { id: proc; onExited: root.busy = false }
Button {
  enabled: !root.busy
  text: root.busy ? "Working..." : "Run"
  onClicked: {
    root.busy = true
    proc.command = [root.pluginDir + "/run.sh", root.itemId]
    proc.running = true
  }
}
```
### Persistence and notification
```qml
Process {
  command: ["python3", root.pluginDir + "/configure.py", source, destination]
  running: true
}
```
```bash
printf '[%s] SUCCESS: %s\n' "$(date '+%F %T')" "$output" >>"$LOG_FILE"
notify-send "Example Plugin" "Completed $filename"
```
