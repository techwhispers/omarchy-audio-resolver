import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "quazix.audio-resolver"
  ipcTarget: "quazix.audio-resolver"
  manageIpc: false

  property bool watching: false
  property bool importing: false
  property string sourceDir: "Not configured"
  property string destinationDir: "Not configured"
  property string lastLog: "No recent conversions"
  property string actionStatus: ""
  property string outputLabel: ""
  readonly property string pluginDir: "/home/quazix/.config/omarchy/plugins/quazix.audio-resolver"
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color muted: Qt.darker(foreground, 1.6)
  readonly property color active: "#a6e3a1"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() {
    statusProc.running = false
    statusProc.running = true
  }
  function chooseSource() {
    sourcePicker.command = [pluginDir + "/select-folder.sh", "source"]
    sourcePicker.running = true
  }
  function chooseDestination() {
    destinationPicker.command = [pluginDir + "/select-folder.sh", "destination"]
    destinationPicker.running = true
  }
  function saveFolders() {
    saveProc.command = ["python3", pluginDir + "/configure.py",
      root.sourceDir === "Not configured" ? "" : root.sourceDir,
      root.destinationDir === "Not configured" ? "" : root.destinationDir,
      root.outputLabel]
    saveProc.running = true
  }
  function setWatching(enabled) {
    root.watching = enabled
    serviceProc.command = ["systemctl", "--user", enabled ? "start" : "stop", "audio-resolver.service"]
    serviceProc.running = true
  }

  Timer {
    interval: 2000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Process {
    id: statusProc
    command: ["bash", "-c",
      "active=$(systemctl --user is-active audio-resolver.service 2>/dev/null || true); " +
      "source \"$HOME/.config/audio-resolver/config.env\" 2>/dev/null || true; " +
      "log=$(tail -n 1 \"$HOME/.local/share/audio-resolver/convert.log\" 2>/dev/null || true); " +
      "printf '%s\\t%s\\t%s\\t%s\\t%s\\n' \"$active\" \"${SOURCE_DIR:-}\" \"${DESTINATION_DIR:-}\" \"${OUTPUT_LABEL:-${OUTPUT_SUFFIX:-}}\" \"$log\""]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parts = text.trim().split("\t")
        if (parts.length >= 5) {
          root.watching = parts[0] === "active"
          if (parts[1] !== "") root.sourceDir = parts[1]
          if (parts[2] !== "") root.destinationDir = parts[2]
          root.outputLabel = parts[3]
          root.lastLog = parts[4] !== "" ? parts[4] : "No recent conversions"
        }
      }
    }
  }

  Process {
    id: serviceProc
    onExited: root.refresh()
  }
  Process {
    id: saveProc
    onExited: function(exitCode) {
      if (exitCode === 0) root.refresh()
    }
  }
  Process {
    id: sourcePicker
    running: false
    stdout: StdioCollector { id: sourceOutput; waitForEnd: true }
    stderr: StdioCollector { id: sourceError; waitForEnd: true }
    onExited: function(exitCode) {
      var chosen = String(sourceOutput.text || "").trim()
      if (exitCode === 0 && chosen !== "") {
        root.sourceDir = chosen.split("\n")[0]
        root.refresh()
      } else if (exitCode !== 1) {
        root.lastLog = String(sourceError.text || "Folder picker failed").trim()
      }
    }
  }
  Process {
    id: destinationPicker
    running: false
    stdout: StdioCollector { id: destinationOutput; waitForEnd: true }
    stderr: StdioCollector { id: destinationError; waitForEnd: true }
    onExited: function(exitCode) {
      var chosen = String(destinationOutput.text || "").trim()
      if (exitCode === 0 && chosen !== "") {
        root.destinationDir = chosen.split("\n")[0]
        root.refresh()
      } else if (exitCode !== 1) {
        root.lastLog = String(destinationError.text || "Folder picker failed").trim()
      }
    }
  }
  Process {
    id: importProc
    stdout: StdioCollector { id: importOutput; waitForEnd: true }
    stderr: StdioCollector { id: importError; waitForEnd: true }
    onExited: {
      root.importing = false
      root.actionStatus = exitCode === 0
        ? "Manual import complete"
        : String(importError.text || importOutput.text || "Manual import failed").trim()
      root.refresh()
    }
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { root.refresh(); return "ok" }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    tooltipText: root.watching ? "Audio Resolver: watching " + root.sourceDir : "Audio Resolver: stopped"
    iconComponent: Component {
      Text {
        anchors.centerIn: parent
        text: "󰎈"
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        color: root.watching ? root.active : root.muted
      }
    }
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) {
        root.toggle()
      } else if (buttonCode === Qt.RightButton) {
        root.setWatching(!root.watching)
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    contentWidth: panel.fittedContentWidth(Style.space(390))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      width: parent.width
      spacing: Style.space(12)

      PanelHero {
        width: parent.width
        title: "Audio Resolver"
        meta: root.watching ? "Watching for new AAC video" : "Watcher stopped"
        foreground: root.foreground
        fontFamily: root.fontFamily
        iconOpacity: root.watching ? 1 : 0.5
        iconComponent: Component {
          Text {
            text: "󰎈"
            font.family: root.fontFamily
            font.pixelSize: Style.font.display
            color: root.watching ? root.active : root.muted
          }
        }
        trailingControl: Component {
          ToggleSwitch {
            checked: root.watching
            foreground: root.foreground
            onToggled: root.setWatching(!root.watching)
          }
        }
      }

      PanelSectionHeader { text: "FOLDERS"; foreground: root.foreground; fontFamily: root.fontFamily }
      RowLayout {
        width: parent.width
        spacing: Style.space(8)
        Text {
          Layout.fillWidth: true
          text: "Source\n" + (root.sourceDir === "Not configured"
            ? "Select source media folder\n(camera card or SD card)"
            : root.sourceDir)
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideMiddle
        }
        Button {
          text: "Choose"
          bordered: true
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: root.chooseSource()
        }
      }
      RowLayout {
        width: parent.width
        spacing: Style.space(8)
        Text {
          Layout.fillWidth: true
          text: "Destination\n" + (root.destinationDir === "Not configured"
            ? "Select destination folder\n(for Resolve .mov files)"
            : root.destinationDir)
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideMiddle
        }
        Button {
          text: "Choose"
          bordered: true
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: root.chooseDestination()
        }
      }
      RowLayout {
        width: parent.width
        spacing: Style.space(8)
        Text {
          text: "Label"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
        TextField {
          id: labelField
          Layout.fillWidth: true
          text: root.outputLabel
          placeholderText: "None (outputs filename.mov)"
          foreground: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          onEditingFinished: {
            root.outputLabel = text
            root.saveFolders()
          }
        }
      }
      RowLayout {
        width: parent.width
        spacing: Style.space(8)
        Button {
          text: root.importing ? "Importing..." : "Import Now"
          enabled: !root.importing && !root.watching && root.sourceDir !== "Not configured" && root.destinationDir !== "Not configured"
          bordered: true
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: {
            root.importing = true
            importProc.command = [root.pluginDir + "/audio-resolver-import.sh", root.sourceDir, root.destinationDir]
            importProc.running = true
          }
        }
        Text {
          Layout.fillWidth: true
          text: root.watching ? "Disabled while watching" : "Available when watcher is stopped"
          color: root.muted
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }
      }
      PanelSectionHeader { text: "ACTIVITY"; foreground: root.foreground; fontFamily: root.fontFamily }
      Text {
        visible: root.actionStatus !== ""
        width: parent.width
        text: root.actionStatus
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WrapAnywhere
      }
      Text {
        width: parent.width
        text: root.lastLog
        color: root.muted
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WrapAnywhere
      }
      Text {
        width: parent.width
        text: "AAC audio is decoded to pcm_s16le without re-encoding the video. The result is saved as a Resolve-ready .mov file."
        color: root.muted
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }
    }
  }
}
