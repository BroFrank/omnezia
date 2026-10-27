import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Details panel for AmneziaWG VPN bar widget.
// Loaded via Loader in BarWidget.qml; receives anchorItem and hostWidget from it.
Panel {
  id: root
  moduleName: "io.github.BroFrank.omnezia"
  ipcTarget: "io.github.BroFrank.omnezia"
  manageIpc: true

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
  property string vpnKeyInput: ""

  // Service — inline component for this panel
  Service {
    id: service
    settings: root.settings
    interfaceName: "wg0"
  }

  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color urgent: bar ? bar.urgent : Commons.Color.urgent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property bool connected: service.connected
  readonly property bool busy: service.busy
  readonly property var profiles: service.profiles
  readonly property var currentProfile: service.currentProfile

  // ---- Panel lifecycle
  // opened is inherited from Quickshell's Panel base class when manageIpc: true.
  // It drives KeyboardPanel visibility and the bar's popout coordinator.

  function open() {
    cursorActive = false
    configEditMode = false
    rawConfigInput = ""
    newProfileName = ""
    vpnKeyInput = ""
    if (service) {
      service.loadProfiles()
      service.refreshStatus()
    }
    root.opened = true
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.opened = false
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
      var showKeyForm = configEditMode || !currentProfile
      if (focusSection === "header" && dy > 0 && showProfiles) focusSection = "profiles"
      else if (focusSection === "profiles" && dy < 0) focusSection = "header"
      else if (focusSection === "profiles" && dy > 0 && showKeyForm) focusSection = "keyform"
      else if (focusSection === "keyform" && dy < 0) focusSection = "profiles"

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

          // ===== SECTION 1: Header =====
          Item {
            width: parent.width
            implicitHeight: headerSection.implicitHeight

            Column {
              id: headerSection
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              spacing: Style.space(6)

              // Icon + Title + Toggle row (single row)
              Row {
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: Style.space(10)

                Image {
                  id: icon
                  source: Qt.resolvedUrl("icon.svg")
                  width: Style.font.display * 1.2
                  height: width
                  fillMode: Image.PreserveAspectFit
                  smooth: true
                }

                Text {
                  text: "OMNEZIA"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.display
                  font.bold: true
                  elide: Text.ElideRight
                  width: parent.width - icon.width - powerSwitch.implicitWidth - Style.space(10) * 2
                  anchors.verticalCenter: parent.verticalCenter
                }

                ToggleSwitch {
                  id: powerSwitch
                  checked: connected
                  busy: busy
                  foreground: root.foreground
                  onToggled: service.toggle()

                  PanelToolTip {
                    visible: powerSwitch.containsMouse
                    text: connected ? "Disconnect" : (profiles.length > 0 ? "Connect" : "Add a profile first")
                    fontFamily: root.fontFamily
                  }
                }
              }
            }
          }

          // ===== SECTION 2: amnezia-wg status =====
          Item {
            width: parent.width
            implicitHeight: wgStatusSection.implicitHeight

            Column {
              id: wgStatusSection
              anchors.left: parent.left
              anchors.right: parent.right
              spacing: Style.space(8)

              PanelSectionHeader {
                text: "AmneziaWG"
                foreground: root.foreground
                fontFamily: root.fontFamily
              }

              // Not installed state
              CursorSurface {
                visible: !!service ? (!!service.whichProcess && !service.whichProcess.running && service.statusText === "amneziawg-go not installed") : false
                width: parent.width
                implicitHeight: missingBlock.implicitHeight + Style.spacing.xl
                foreground: root.foreground

                Column {
                  id: missingBlock
                  anchors.left: parent.left
                  anchors.right: parent.right
                  spacing: Style.space(8)

                  Text {
                    text: "amneziawg-go is not installed"
                    color: root.urgent
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    font.bold: true
                  }

                  Text {
                    text: "Install it to enable VPN connections.\nUse: omarchy pkg add amneziawg-go"
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    wrapMode: Text.WordWrap
                  }

                  PanelActionButton {
                    iconText: "󰏔"
                    tooltipText: "Install amneziawg-go"
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                    onClicked: service.installAmneziaWG()
                  }
                }
              }

              // Installing state with progress bar
              CursorSurface {
                visible: !!service ? (!!service.installProcess && service.installProcess.running) : false
                width: parent.width
                implicitHeight: installingBlock.implicitHeight + Style.spacing.xl
                foreground: root.foreground

                Column {
                  id: installingBlock
                  anchors.left: parent.left
                  anchors.right: parent.right
                  spacing: Style.space(8)

                  Text {
                    text: "Installing amneziawg-go…"
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    font.bold: true
                  }

                  ProgressBar {
                    width: parent.width
                    value: service.installProgress || 0
                  }

                  Text {
                    text: service.installOutput || ""
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    wrapMode: Text.WordWrap
                    maximumLineCount: 3
                  }
                }
              }

              // Installed state — show version
              CursorSurface {
                visible: !!service ? (!!service.whichProcess && !service.whichProcess.running && service.statusText !== "amneziawg-go not installed") : false
                width: parent.width
                implicitHeight: installedBlock.implicitHeight + Style.spacing.xl
                foreground: root.foreground

                Column {
                  id: installedBlock
                  anchors.left: parent.left
                  anchors.right: parent.right
                  spacing: Style.space(4)

                  Text {
                    text: "amneziawg-go installed"
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    font.bold: true
                  }

                  Text {
                    text: service.amneziaWGVersion || "Checking version…"
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                  }
                }
              }
            }
          }

          // ===== SECTION 3: Profiles list =====
          Item {
            width: parent.width
            implicitHeight: profilesSection.implicitHeight

            Column {
              id: profilesSection
              anchors.left: parent.left
              anchors.right: parent.right
              spacing: Style.space(8)

              PanelSectionHeader {
                text: "Profiles (" + profiles.length + ")"
                foreground: root.foreground
                fontFamily: root.fontFamily
              }

              // No profiles message
              Text {
                visible: !service.profilesLoaded || profiles.length === 0
                width: parent.width
                text: "No VPN profiles configured yet.\nAdd one using the key form below."
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.WordWrap
              }

              // Profile list
              ListView {
                visible: profiles.length > 0
                id: profileList
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
            }
          }

          // ===== SECTION 4: Key input form =====
          Item {
            width: parent.width
            implicitHeight: keyFormSection.implicitHeight

            Column {
              id: keyFormSection
              anchors.left: parent.left
              anchors.right: parent.right
              spacing: Style.space(8)

              PanelSectionHeader {
                text: "Add Profile"
                foreground: root.foreground
                fontFamily: root.fontFamily
              }

              TextField {
                width: parent.width
                id: vpnKeyField
                foreground: root.foreground
                placeholderText: "Paste Amnezia vpn:// key here"
                text: vpnKeyInput
                onTextChanged: vpnKeyInput = text
                Keys.onPressed: function(event) {
                  if (event.key === Qt.Key_Escape) {
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
                  iconText: "󰅌"
                  tooltipText: "Paste from clipboard"
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  onClicked: {
                    var clip = Quickshell.clipboard()
                    if (clip) vpnKeyInput = clip.text || ""
                  }
                }

                PanelActionButton {
                  iconText: "󰏔"
                  tooltipText: "Add profile from key"
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  enabled: vpnKeyInput.trim() !== "" && !busy
                  onClicked: service.addProfileFromVpnKey(vpnKeyInput.trim())
                }

                PanelActionButton {
                  iconText: "󰌶"
                  tooltipText: "Cancel"
                  foreground: root.dim
                  fontFamily: root.fontFamily
                  onClicked: {
                    configEditMode = false
                    vpnKeyInput = ""
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
    fill: Style.hoverFillFor(root.foreground, Commons.Color.accent)
    currentFill: Style.selectedFillFor(root.foreground, Commons.Color.accent)

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
        width: parent.width - Style.space(22) - Style.space(8) * 2 - deleteBtn.implicitWidth - selectBtn.implicitWidth
        anchors.verticalCenter: parent.verticalCenter
      }

      PanelActionButton {
        id: selectBtn
        iconText: "󰆏"
        foreground: root.dim
        fontFamily: root.fontFamily
        enabled: !isActive && !service.busy
        onClicked: service.loadProfile(profileName)

        PanelToolTip {
          visible: containsMouse
          text: "Select this profile"
          fontFamily: root.fontFamily
        }
      }

      PanelActionButton {
        id: deleteBtn
        iconText: "󰆴"
        foreground: isActive ? root.dim : root.urgent
        fontFamily: root.fontFamily
        enabled: !service.busy
        onClicked: service.deleteProfile(profileName)

        PanelToolTip {
          visible: containsMouse
          text: "Delete profile '" + profileName + "'"
          fontFamily: root.fontFamily
        }
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
