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

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }
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

  IpcHandler {
    target: "io.github.BroFrank.omnezia"
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
  }

  Item {
    id: button
    anchors.fill: parent

    Image {
      anchors.centerIn: parent
      source: Qt.resolvedUrl("icon.svg")
      width: Style.font.icon || 16
      height: width
      fillMode: Image.PreserveAspectFit
      smooth: true
    }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: if (root.bar) root.bar.showTooltip(root, "AmneziaWG VPN")
      onExited: if (root.bar) root.bar.hideTooltip(root)
      onPressed: function(mouse) {
        if (mouse.button === Qt.RightButton) root.toggle()
        else if (root.opened) root.close()
        else root.open()
      }
    }
  }
}
