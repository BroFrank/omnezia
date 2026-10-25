import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Item {
  id: root
  property int iconSize: Style.font.icon || 16
  property color color: "white"
  property bool connected: false

  width: iconSize
  height: iconSize
  implicitWidth: iconSize
  implicitHeight: iconSize

  // VPN shield icon — Material Design VPN icon (U+E33E)
  Text {
    anchors.centerIn: parent
    text: "󰌾"
    font.family: Style.font.iconFamily || "Material Symbols Rounded"
    font.pixelSize: root.iconSize
    color: root.color
  }

  // Small connected indicator dot (top-right corner when active)
  Rectangle {
    visible: root.connected
    anchors.top: parent.top
    anchors.right: parent.right
    width: Math.max(2, iconSize * 0.24)
    height: Math.max(2, iconSize * 0.24)
    radius: width / 2
    color: Commons.Color.accent || "#4caf50"
  }
}
