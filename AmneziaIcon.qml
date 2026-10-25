import QtQuick
import qs.Ui

Item {
  id: root
  property int iconSize: Style.font.icon
  property color color: "white"

  width: iconSize
  height: iconSize

  // VPN shield icon — connected state shows filled, disconnected shows outlined
  Text {
    anchors.centerIn: parent
    text: "󰌾"  // Material Design VPN icon (U+E33E)
    font.family: Style.font.iconFamily || "Material Symbols Rounded"
    font.pixelSize: root.iconSize
    color: root.color
  }

  // Small connected indicator dot (top-right corner when active)
  Rectangle {
    visible: root.connected
    anchors.top: parent.top
    anchors.right: parent.right
    width: iconSize * 0.25
    height: iconSize * 0.25
    radius: width / 2
    color: Style.accent || "#4caf50"
  }
}
