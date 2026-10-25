import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "bro.amneziawg"
  ipcTarget: "bro.amneziawg"
  manageIpc: false

  property string focusSection: "header"
  property int profileIndex: 0
  property bool cursorActive: false
  property bool configEditMode: false
  property string newProfileName: ""
  property string rawConfigInput: ""

  // References to panel children for navigation
  readonly property Item headerArea: panel.loadedContent ? panel.loadedContent.headerArea : null
  readonly property Item profileList: panel.loadedContent ? panel.loadedContent.profileList : null
  readonly property Item configEditor: panel.loadedContent ? panel.loadedContent.configEditor : null

  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // Service references from BarWidget.qml via Loader
  readonly property var service: panel.loadedContent ? panel.loadedContent.service : null
  readonly property bool connected: service ? service.connected : false
  readonly property bool busy: service ? service.busy : false
  readonly property string statusText: service ? service.statusText : ""
  readonly property string lastError: service ? service.lastError : ""
  readonly property var profiles: service ? service.profiles : []
  readonly property var currentProfile: service ? service.currentProfile : null

  readonly property bool showProfiles: profiles.length > 0 || service && service.profilesLoaded
  readonly property bool showConfigEditor: configEditMode || !currentProfile

  onOpenedChanged: if (opened) {
    cursorActive = false
    configEditMode = false
    rawConfigInput = ""
    newProfileName = ""
    if (service) {
      service.loadProfiles()
      service.refreshStatus()
    }
    Qt.callLater(function() { if (panel.loadedContent) panel.loadedContent.forceActiveFocus() })
  }

  Service {
    id: service
    settings: root.settings
    interfaceName: "wg0"
  }

  ShellIpc {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { service.toggle() }
    function refresh(): string { if (service) service.refresh(); return "ok" }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    iconComponent: Component {
      Item {
        AmneziaIcon {
          x: (parent.width - width) / 2
          y: (parent.height - height) / 2
          iconSize: button.iconSize
          color: connected ? bar.foreground : Qt.darker(bar.foreground, 1.55)
        }
      }
    }
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) service.toggle()
      else if (buttonCode === Qt.MiddleButton) service.refresh()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: panel.loadedContent
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight, Style.space(560))

    content: PanelKeyCatcher {
      id: keyCatcher
      property alias headerArea: headerArea
      property alias profileList: profileList
      property alias configEditor: configEditor
      implicitHeight: column.implicitHeight
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        root.moveCursor(dx, dy)
      }
      onActivateRequested: if (root.cursorActive) root.activateCursor()
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
            id: headerArea
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
            visible: lastError !== "" || service && service.actionStatus !== ""
            width: parent.width
            text: lastError !== "" ? lastError : (service && service.actionStatus ? service.actionStatus : "")
            color: lastError !== "" ? root.urgent : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          // Not installed message
          CursorSurface {
            visible: !service || !service.whichProcess.running === false
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
            visible: showProfiles && profiles.length > 0
            foreground: root.foreground
          }

          Column {
            visible: showProfiles && profiles.length > 0
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
                isActive: service && currentProfile && currentProfile.name === modelData
                rowIndex: index
              }
            }

            // Add new profile button
            PanelActionButton {
              visible: true
              iconText: "󰅕"  // plus icon
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
            visible: configEditor && configEditMode
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
              onAccepted: configEditor.forceActiveFocus()
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
              foreground: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              text: rawConfigInput
              placeholderText: "[Interface]\nPrivateKey = ...\nAddress = 10.244.0.2/32\n\n[Peer]\nPublicKey = ...\nEndpoint = server.example.com:51820\nAllowedIPs = 0.0.0.0/0, ::/0"
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
                iconText: "󰋽"  // save icon
                tooltipText: "Save profile"
                foreground: root.foreground
                fontFamily: root.fontFamily
                enabled: newProfileName.trim() !== "" && rawConfigInput.trim() !== "" && !busy
                onClicked: {
                  if (service) service.saveProfile(newProfileName.trim(), rawConfigInput)
                }
              }

              PanelActionButton {
                iconText: "󰌶"  // cancel/close icon
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

  function moveCursor(dx, dy) {
    cursorActive = true
    if (dy !== 0) {
      // Simple section navigation: header → profiles → config editor
      if (focusSection === "header" && dy > 0 && showProfiles) focusSection = "profiles"
      else if (focusSection === "profiles" && dy < 0) focusSection = "header"
      else if (focusSection === "profiles" && dy > 0 && configEditMode) focusSection = "config"
      else if (focusSection === "config" && dy < 0) focusSection = "profiles"

      // Profile index navigation within profiles section
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
        if (service) service.loadProfile(selected)
      }
    }
  }

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
        text: isActive ? "󰄳" : "󰌾"  // checkmark or VPN icon
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
        iconText: "󰆏"  // delete icon
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

  function setProfileCursor(index) {
    cursorActive = true
    focusSection = "profiles"
    profileIndex = index
  }
}
