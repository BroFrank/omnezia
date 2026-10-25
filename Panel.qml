import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

// Details panel for AmneziaWG VPN bar widget.
// Loaded via Loader in BarWidget.qml; receives anchorItem and hostWidget from it.
Panel {
  id: root
  moduleName: "bro.amneziawg"
  ipcTarget: "bro.amneziawg"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  // ---- State
  property string focusSection: "header"
  property int profileIndex: 0
  property bool cursorActive: false
  property bool configEditMode: false
  property string newProfileName: ""
  property string rawConfigInput: ""

  // Service — inline component for this panel
  Service {
    id: service
    settings: root.settings
    interfaceName: "wg0"
  }

  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property bool connected: service.connected
  readonly property bool busy: service.busy
  readonly property var profiles: service.profiles
  readonly property var currentProfile: service.currentProfile

  // ---- Panel lifecycle
  function open() {
    cursorActive = false
    configEditMode = false
    rawConfigInput = ""
    newProfileName = ""
    if (service) {
      service.loadProfiles()
      service.refreshStatus()
    }
    root.controller.show()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else service.toggle()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  // ---- Navigation helpers
  function moveCursor(dx, dy) {
    cursorActive = true
    if (dy !== 0) {
      var showProfiles = profiles.length > 0 || service.profilesLoaded
      var showConfigEditor = configEditMode || !currentProfile
      if (focusSection === "header" && dy > 0 && showProfiles) focusSection = "profiles"
      else if (focusSection === "profiles" && dy < 0) focusSection = "header"
      else if (focusSection === "profiles" && dy > 0 && showConfigEditor) focusSection = "config"
      else if (focusSection === "config" && dy < 0) focusSection = "profiles"

      if (focusSection === "profiles") {
        profileIndex = Math.max(0, Math.min(profiles.length - 1, profileIndex + dy))
      }
    }
  }

  function activateCursor() {
    if (cursorActive) {
      if (focusSection === "header") service.toggle()
      else if (focusSection === "profiles" && profiles.length > 0) {
        var selected = profiles[Math.max(0, Math.min(profileIndex, profiles.length - 1))]
        service.loadProfile(selected)
      }
    }
  }

  function setProfileCursor(index) {
    cursorActive = true
    focusSection = "profiles"
    profileIndex = index
  }

  // ---- UI content
  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) { root.moveCursor(dx, dy) }
      onActivateRequested: if (cursorActive) root.activateCursor()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(12)

          // Header section with connection status and toggle
          Item {
            width: parent.width
            implicitHeight: hero.implicitHeight

            PanelHero {
              id: hero
              width: parent.width
              title: "AmneziaWG VPN"
              meta: connected ? "Connected" : (profiles.length > 0 ? "Disconnected — select a profile" : "No profiles configured")
              foreground: root.foreground
              fontFamily: root.fontFamily
              iconOpacity: connected ? 1.0 : 0.5

              iconComponent: Component {
                Item {
                  AmneziaIcon {
                    x: (parent.width - width) / 2
                    y: (parent.height - height) / 2
                    iconSize: Style.font.display
                    color: connected ? root.foreground : root.dim
                  }
                }
              }

              trailingControl: Component {
                ToggleSwitch {
                  visible: profiles.length > 0 || currentProfile !== null
                  checked: connected
                  busy: busy
                  foreground: hero.foreground
                  onToggled: service.toggle()

                  PanelToolTip {
                    visible: powerSwitch.containsMouse
                    text: connected ? "Disconnect" : (currentProfile ? "Connect" : "Select a profile first")
                    fontFamily: hero.fontFamily
                  }
                }
              }
            }
          }

          // Error/status messages
          Text {
            textFormat: Text.PlainText
            visible: service.lastError !== "" || service.actionStatus !== ""
            width: parent.width
            text: service.lastError !== "" ? service.lastError : (service.actionStatus ? service.actionStatus : "")
            color: service.lastError !== "" ? root.urgent : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          // Not installed message
          CursorSurface {
            visible: !service.whichProcess.running
            width: parent.width
            implicitHeight: missingText.implicitHeight + Style.spacing.rowPaddingX
            foreground: root.foreground

            Text {
              id: missingText
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.margins: Style.space(12)
              text: "amneziawg-go not installed. Install with:\n  omarchy pkg add amneziawg-go"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              wrapMode: Text.WordWrap
            }
          }

          // Profile list section
          PanelSeparator {
            visible: profiles.length > 0 && !configEditMode
            foreground: root.foreground
          }

          Column {
            visible: profiles.length > 0 && !configEditMode
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader {
              text: "VPN Profiles (" + profiles.length + ")"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            ListView {
              id: profileList
              visible: profiles.length > 0
              width: parent.width
              height: Math.min(contentHeight, Style.space(240))
              clip: true
              spacing: Style.space(6)
              model: profiles
              reuseItems: true
              boundsBehavior: Flickable.StopAtBounds

              delegate: ProfileRow {
                required property var modelData
                required property int index
                width: profileList.width
                profileName: modelData
                isActive: currentProfile && currentProfile.name === modelData
                rowIndex: index
              }
            }

            PanelActionButton {
              visible: true
              iconText: "󰅕"
              tooltipText: "Add new profile"
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: {
                configEditMode = true
                rawConfigInput = ""
                newProfileName = ""
              }
            }
          }

          // Config editor section
          PanelSeparator {
            visible: configEditMode
            foreground: root.foreground
          }

          Column {
            id: configEditor
            visible: configEditMode
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader {
              text: "New Profile"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            TextField {
              width: parent.width
              foreground: root.foreground
              placeholderText: "Profile name (e.g., Germany, USA)"
              text: newProfileName
              onTextChanged: newProfileName = text
              Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                  configEditMode = false
                  keyCatcher.forceActiveFocus()
                  event.accepted = true
                }
              }
            }

            TextEdit {
              width: parent.width
              height: Style.space(200)
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              text: rawConfigInput
              wrapMode: TextEdit.Wrap

              Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape && !rawConfigInput) {
                  configEditMode = false
                  keyCatcher.forceActiveFocus()
                  event.accepted = true
                }
              }
            }

            RowLayout {
              width: parent.width
              spacing: Style.space(8)

              PanelActionButton {
                Layout.fillWidth: true
                iconText: "󰋽"
                tooltipText: "Save profile"
                foreground: root.foreground
                fontFamily: root.fontFamily
                enabled: newProfileName.trim() !== "" && rawConfigInput.trim() !== "" && !busy
                onClicked: service.saveProfile(newProfileName.trim(), rawConfigInput)
              }

              PanelActionButton {
                iconText: "󰌶"
                tooltipText: "Cancel"
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: configEditMode = false
              }
            }
          }
        }
      }
    }
  }

  // ---- ProfileRow component
  component ProfileRow: CursorSurface {
    id: profileRow
    property string profileName: ""
    property bool isActive: false
    property int rowIndex: 0

    hasCursor: root.cursorActive && root.focusSection === "profiles" && root.profileIndex === rowIndex
    current: isActive
    foreground: root.foreground
    fill: root.hoverFill
    currentFill: root.selectedFill

    implicitHeight: inner.implicitHeight + Style.spacing.xl

    Row {
      id: inner
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(6)
      anchors.rightMargin: Style.space(6)
      spacing: Style.space(8)

      Text {
        text: isActive ? "󰄳" : "󰌾"
        color: isActive ? root.foreground : root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        width: Style.space(22)
        horizontalAlignment: Text.AlignHCenter
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        textFormat: Text.PlainText
        text: profileName
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: isActive
        elide: Text.ElideRight
        width: parent.width - Style.space(22) - Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
      }

      PanelActionButton {
        iconText: "󰆏"
        foreground: root.dim
        fontFamily: root.fontFamily
        enabled: !isActive && !service.busy
        onClicked: service.deleteProfile(profileName)
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: root.setProfileCursor(rowIndex)
      onClicked: if (profileName !== "") service.loadProfile(profileName)
    }
  }
}
