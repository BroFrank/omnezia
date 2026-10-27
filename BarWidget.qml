import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Bar widget entry point for AmneziaWG VPN.
// Left click opens the details panel, right click toggles connection.
BarWidget {
  id: root
  moduleName: "io.github.BroFrank.omnezia"

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  readonly property bool connected: panelLoader.item ? panelLoader.item.connected === true : false
  readonly property bool busy: panelLoader.item ? panelLoader.item.busy === true : false

  function open() {
    if (panelLoader.item) {
      panelLoader.item.open()
    } else {
      // Panel not yet loaded — retry after component instantiation completes
      Qt.callLater(function() { root.open() })
    }
  }
  function close() {
    if (panelLoader.item) {
      panelLoader.item.close()
    } else {
      Qt.callLater(function() { root.close() })
    }
  }
  function toggle() { if (panelLoader.item) panelLoader.item.toggleConnection() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  // IPC (open/close/toggle from `omarchy-shell shell ...` and keybindings) is
  // owned by the base Panel via ipcTarget. Bar-widget panels are summoned
  // through the live bar instance, so a second IpcHandler here would only
  // collide with the panel's handler for the same target.

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    pressable: true
    hasVisualContent: true
    active: root.connected
    tooltipText: root.busy
      ? "AmneziaWG: working…"
      : (root.connected ? "AmneziaWG: connected" : "AmneziaWG: disconnected")

    onPressed: function(b) {
      if (b === Qt.RightButton) root.toggle()
      else if (root.opened) root.close()
      else root.open()
    }

    Image {
      anchors.centerIn: parent
      source: Qt.resolvedUrl("icon.svg")
      width: Style.font.icon || 16
      height: width
      fillMode: Image.PreserveAspectFit
      smooth: true
      // Unplugged/tinted so the bar icon reads as inactive when disconnected.
      opacity: root.connected ? 1 : 0.55
    }
  }
}
