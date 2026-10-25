import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "Model.js" as Model

Item {
  id: root

  property var settings: ({})
  property string interfaceName: "wg0"

  // Connection state
  property bool connected: false
  property bool busy: whichProcess.running || statusProcess.running || connectProcess.running || disconnectProcess.running || profileLoadProcess.running || profileSaveProcess.running
  property string statusText: "Checking…"  // i18n: ignore
  property string lastError: ""
  property string actionStatus: ""

  // Profile management
  property var profiles: []
  property var currentProfile: null
  property string activeProfileName: ""
  property bool profilesLoaded: false
  property string profileLoadError: ""
  property bool refreshing: false

  // Config editing (for the panel)
  property string rawConfigText: ""
  property string parsedConfigPreview: ""
  property bool configValid: false
  property string configParseError: ""

  // AmneziaWG-specific status from socket
  property string handshakeStatus: ""
  property int transferBytesReceived: 0
  property int transferBytesSent: 0

  readonly property int refreshIntervalSec: intSetting("refreshIntervalSec", 10, 5, 3600)
  readonly property string profilesDir: Quickshell.env("HOME") + "/.config/omnezia/profiles"

  // Process outputs
  property string _statusOutput: ""
  property string _statusError: ""
  property string _connectOutput: ""
  property string _connectError: ""
  property string _disconnectOutput: ""
  property string _disconnectError: ""
  property string _profileListOutput: ""
  property string _profileLoadOutput: ""
  property string _profileLoadError: ""

  // Optimistic toggle state
  property int _desired: -1
  readonly property bool active: _desired === -1 ? connected : (_desired === 1)

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function intSetting(name, fallback, min, max) {
    var n = parseInt(String(setting(name, fallback)), 10)
    if (!isFinite(n)) n = fallback
    if (n < min) n = min
    if (n > max) n = max
    return n
  }

  // Check if amneziawg-go binary is available
  function checkInstalled() {
    if (!whichProcess.running) {
      refreshing = true
      whichProcess.command = ["which", "amneziawg-go"]
      whichProcess.running = true
    }
  }

  // Check interface status
  function refreshStatus() {
    if (!statusProcess.running) {
      _statusOutput = ""
      _statusError = ""
      statusProcess.command = ["bash", "-c", "ip link show " + root.interfaceName + " 2>&1"]
      statusProcess.running = true
    }
  }

  // Connect to VPN using current profile config
  function connect() {
    if (!currentProfile || connectProcess.running) return
    _desired = 1

    // Remove existing interface first
    runDisconnect(function() {
      // Write config file and start amneziawg-go
      var configFile = "/tmp/amnezia-" + root.interfaceName + "-" + activeProfileName.replace(/[^a-zA-Z0-9]/g, "_") + ".conf"
      var configText = Model.configToText(currentProfile)

      _connectOutput = ""
      _connectError = ""
      connectProcess.command = [
        "bash", "-c",
        "printf '%s' '" + Util.shellQuote(configText).replace(/'/g, "'\\''") + "' > " + configFile +
        " && amneziawg-go " + root.interfaceName + " < " + configFile
      ]
      connectProcess.running = true
    })
  }

  // Disconnect from VPN
  function disconnect() {
    if (disconnectProcess.running) return
    _desired = 0

    _disconnectOutput = ""
    _disconnectError = ""
    disconnectProcess.command = ["bash", "-c", "ip link del " + root.interfaceName + " 2>&1 || rm -f /var/run/amneziawg/" + root.interfaceName + ".sock"]
    disconnectProcess.running = true
  }

  // Toggle connection state
  function toggle() {
    if (active) disconnect()
    else connect()
  }

  // Load all profiles from disk
  function loadProfiles() {
    if (!profileLoadProcess.running && !profilesLoaded) {
      _profileListOutput = ""
      profileLoadProcess.command = ["bash", "-c", "ls '" + root.profilesDir + "'/*.json 2>/dev/null"]
      profileLoadProcess.running = true
    }
  }

  // Load a specific profile by name
  function loadProfile(name) {
    if (!profileLoadProcess.running || String(name || "") === "") return
    _profileLoadOutput = ""
    _profileLoadError = ""
    activeProfileName = name
    profileLoadProcess.command = ["bash", "-c", "cat '" + root.profilesDir + "/" + name + ".json' 2>&1"]
    profileLoadProcess.running = true
  }

  // Save a profile (from raw config text)
  function saveProfile(name, configText) {
    if (!profileSaveProcess.running || String(name || "") === "" || String(configText || "") === "") return
    profileSaveProcess.command = [
      "bash", "-c",
      "mkdir -p '" + root.profilesDir + "' && printf '%s' '" + Util.shellQuote(configText).replace(/'/g, "'\\''") + "' > '" + root.profilesDir + "/" + name + ".json'"
    ]
    profileSaveProcess.running = true
  }

  // Delete a profile by name
  function deleteProfile(name) {
    if (String(name || "") === "") return
    Quickshell.execDetached(["bash", "-c", "rm -f '" + root.profilesDir + "/" + name + ".json'"])
    loadProfiles()
  }

  // Parse status output to determine connection state
  function parseStatus(stdout, stderr) {
    var combined = String(stdout || "") + "\n" + String(stderr || "")
    if (combined.indexOf("state UP") !== -1 || combined.match(/type 65534/) /* WireGuard type */) {
      connected = true
      statusText = "Connected"
      lastError = ""
      actionStatus = ""
      if (_desired !== -1 && _desired === 1) _desired = -1
    } else {
      connected = false
      statusText = "Disconnected"
      lastError = ""
      actionStatus = ""
      if (_desired !== -1 && _desired === 0) _desired = -1
    }
  }

  // Parse profile list output
  function parseProfileList(stdout) {
    var files = String(stdout || "").trim().split("\n").filter(function(f) { return f.trim() !== "" })
    profiles = []
    for (var i = 0; i < files.length; i++) {
      var file = files[i].trim()
      // Extract profile name from path: /home/user/.config/omnezia/profiles/name.json → name
      var match = file.match(/\/([^\/]+)\.json$/)
      if (match) profiles.push(match[1])
    }
    profilesLoaded = true
  }

  // Parse loaded profile JSON
  function parseProfileLoad(stdout, stderr) {
    var text = String(stdout || "")
    if (stderr && String(stderr).trim() !== "") {
      profileLoadError = String(stderr).trim()
      currentProfile = null
      return
    }

    try {
      var parsed = JSON.parse(text)
      // Validate structure
      if (!parsed.name || !parsed.interface || !parsed.peer) {
        configParseError = "Invalid profile: missing name, interface, or peer section"
        currentProfile = null
        return
      }

      currentProfile = Model.parseConfig(serializeToWgFormat(parsed))
      if (currentProfile.ok) {
        parsedConfigPreview = "OK — Interface + Peer validated"
        configValid = true
        profileLoadError = ""
      } else {
        parsedConfigError = currentProfile.error || "Config parse error"
        currentProfile = null
        configValid = false
      }
    } catch (e) {
      profileLoadError = "JSON parse error: " + String(e)
      currentProfile = null
      configValid = false
    }
  }

  // Convert JSON profile to WireGuard-style text for parsing
  function serializeToWgFormat(jsonProfile) {
    var lines = []
    lines.push("[Interface]")
    if (jsonProfile.interface.Address && jsonProfile.interface.Address.length > 0) {
      lines.push("Address = " + jsonProfile.interface.Address.join(", "))
    }
    if (jsonProfile.interface.PrivateKey) lines.push("PrivateKey = " + jsonProfile.interface.PrivateKey)
    if (jsonProfile.interface.ListenPort && jsonProfile.interface.ListenPort > 0) {
      lines.push("ListenPort = " + jsonProfile.interface.ListenPort)
    }

    // AmneziaWG params
    addParam(lines, "S1", jsonProfile.interface.S1)
    addParam(lines, "S2", jsonProfile.interface.S2)
    addParamOrNull(lines, "S3", jsonProfile.interface.S3)
    addParam(lines, "S4", jsonProfile.interface.S4)
    addParam(lines, "Jc", jsonProfile.interface.Jc)
    addParam(lines, "Jmin", jsonProfile.interface.Jmin)
    addParam(lines, "Jmax", jsonProfile.interface.Jmax)
    addParamOrNull(lines, "H1", jsonProfile.interface.H1)
    addParamOrNull(lines, "H2", jsonProfile.interface.H2)
    addParamOrNull(lines, "H3", jsonProfile.interface.H3)
    addParamOrNull(lines, "H4", jsonProfile.interface.H4)
    addRawParam(lines, "I1", jsonProfile.interface.I1)
    addRawParam(lines, "I2", jsonProfile.interface.I2)
    addRawParam(lines, "I3", jsonProfile.interface.I3)
    addRawParam(lines, "I4", jsonProfile.interface.I4)
    addRawParam(lines, "I5", jsonProfile.interface.I5)
    if (jsonProfile.interface.HeaderProtectionKey) {
      lines.push("HeaderProtectionKey = " + jsonProfile.interface.HeaderProtectionKey)
    }
    if (jsonProfile.interface.ContentPaddingAddition && jsonProfile.interface.ContentPaddingAddition > 0) {
      lines.push("ContentPaddingAddition = " + jsonProfile.interface.ContentPaddingAddition)
    }
    addParam(lines, "RekeyAfterTime", jsonProfile.interface.RekeyAfterTime)
    addParam(lines, "RekeyTimeout", jsonProfile.interface.RekeyTimeout)
    addParam(lines, "RejectAfterTime", jsonProfile.interface.RejectAfterTime)
    addParam(lines, "KeepaliveTimeout", jsonProfile.interface.KeepaliveTimeout)
    addParam(lines, "MaxHandshakeAttempts", jsonProfile.interface.MaxHandshakeAttempts)

    lines.push("")
    lines.push("[Peer]")
    if (jsonProfile.peer.PublicKey) lines.push("PublicKey = " + jsonProfile.peer.PublicKey)
    if (jsonProfile.peer.Endpoint) lines.push("Endpoint = " + jsonProfile.peer.Endpoint)
    if (jsonProfile.peer.AllowedIPs && jsonProfile.peer.AllowedIPs.length > 0) {
      lines.push("AllowedIPs = " + jsonProfile.peer.AllowedIPs.join(", "))
    }
    addParam(lines, "PersistentKeepalive", jsonProfile.peer.PersistentKeepalive)

    return lines.join("\n")
  }

  function addParam(lines, key, value) {
    if (value !== null && value !== undefined && value !== "") {
      lines.push(key + " = " + String(value))
    }
  }

  function addParamOrNull(lines, key, value) {
    if (value !== null && value !== undefined) {
      var display = value === null ? "(off)" : String(value)
      lines.push(key + " = " + display)
    }
  }

  function addRawParam(lines, key, value) {
    if (value && String(value).trim() !== "") {
      lines.push(key + " = " + String(value))
    }
  }

  // Run disconnect callback chain
  function runDisconnect(callback) {
    if (!disconnectProcess.running) {
      _disconnectOutput = ""
      _disconnectError = ""
      disconnectProcess.command = ["bash", "-c", "ip link del " + root.interfaceName + " 2>&1 || true"]
      disconnectProcess.running = true
    } else {
      // Already running, will execute callback on exit via onExited handler
      disconnectCallback = callback
    }
  }

  property var disconnectCallback: null

  function elideStatus(text) {
    var value = String(text || "").replace(/\s+/g, " ").trim()
    return value.length > 140 ? value.substring(0, 137) + "…" : value
  }

  // Timers for periodic refresh and process timeout
  Timer {
    id: refreshTimer
    interval: root.refreshIntervalSec * 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refreshStatus()
  }

  Timer {
    id: pollWatchdog
    interval: 15000
    repeat: false
    onTriggered: {
      if (statusProcess.running) statusProcess.running = false
      if (connectProcess.running) connectProcess.running = false
      if (disconnectProcess.running) disconnectProcess.running = false
    }
  }

  Timer {
    id: actionStatusTimer
    interval: 3000
    repeat: false
    onTriggered: root.actionStatus = ""
  }

  // Process: check amneziawg-go availability
  Process {
    id: whichProcess
    running: false
    command: []
    onExited: function(exitCode) {
      root.refreshing = false
      if (exitCode !== 0) {
        statusText = "amneziawg-go not installed"
        lastError = "Install amneziawg-go from AUR or build from https://github.com/amnezia-vpn/amneziawg-go"
      } else {
        root.refreshStatus()
      }
    }
  }

  // Process: check interface status
  Process {
    id: statusProcess
    running: false
    command: []
    stdout: StdioCollector { id: statusStdout; waitForEnd: true; onStreamFinished: root._statusOutput = text }
    stderr: StdioCollector { id: statusStderr; waitForEnd: true; onStreamFinished: root._statusError = text }
    onExited: function(exitCode) {
      root.refreshing = false
      var stdout = String(statusStdout.text || root._statusOutput || "")
      var stderr = String(statusStderr.text || root._statusError || "")
      root.parseStatus(stdout, stderr)
    }
  }

  // Process: connect (write config + start amneziawg-go)
  Process {
    id: connectProcess
    running: false
    command: []
    stdout: StdioCollector { id: connectStdout; waitForEnd: true; onStreamFinished: root._connectOutput = text }
    stderr: StdioCollector { id: connectStderr; waitForEnd: true; onStreamFinished: root._connectError = text }
    onExited: function(exitCode) {
      root.refreshing = false
      var stdout = String(connectStdout.text || root._connectOutput || "")
      var stderr = String(connectStderr.text || root._connectError || "")

      if (exitCode !== 0) {
        connected = false
        _desired = -1
        lastError = elideStatus(stderr || stdout || "Connection failed")
        actionStatus = lastError
        actionStatusTimer.restart()
      } else {
        // Connect succeeded — trigger status check
        if (root.disconnectCallback) {
          root.disconnectCallback = null
          root.refreshStatus()
        }
      }
    }
  }

  // Process: disconnect (delete interface)
  Process {
    id: disconnectProcess
    running: false
    command: []
    stdout: StdioCollector { id: disconnectStdout; waitForEnd: true; onStreamFinished: root._disconnectOutput = text }
    stderr: StdioCollector { id: disconnectStderr; waitForEnd: true; onStreamFinished: root._disconnectError = text }
    onExited: function(exitCode) {
      root.refreshing = false
      var stdout = String(disconnectStdout.text || root._disconnectOutput || "")
      var stderr = String(disconnectStderr.text || root._disconnectError || "")

      if (exitCode !== 0 && stderr.indexOf("does not exist") === -1) {
        lastError = elideStatus(stderr || stdout || "Disconnect failed")
        actionStatus = lastError
        actionStatusTimer.restart()
      } else {
        connected = false
        _desired = -1
        lastError = ""
        actionStatus = ""

        // Execute pending callback (e.g., start amneziawg-go after interface removal)
        if (root.disconnectCallback) {
          var cb = root.disconnectCallback
          root.disconnectCallback = null
          cb()
        } else {
          root.refreshStatus()
        }
      }
    }
  }

  // Process: list profiles
  Process {
    id: profileLoadProcess
    running: false
    command: []
    stdout: StdioCollector { id: profileListStdout; waitForEnd: true; onStreamFinished: root._profileListOutput = text }
    stderr: StdioCollector { id: profileLoadStderr; waitForEnd: true; onStreamFinished: root._profileLoadError = text }

    // Determine if this is a list or load operation based on command content
    property bool isListOperation: false

    onStarted: function() {
      isListOperation = String(command).indexOf("ls ") !== -1
    }

    onExited: function(exitCode) {
      var stdout = String(profileListStdout.text || root._profileListOutput || "")
      var stderr = String(profileLoadStderr.text || root._profileLoadError || "")

      if (isListOperation) {
        if (exitCode === 0) root.parseProfileList(stdout)
        else {
          profiles = []
          profilesLoaded = true
          profileLoadError = "Profiles directory not found"
        }
      } else {
        // Profile load operation
        if (exitCode === 0) root.parseProfileLoad(stdout, "")
        else root.parseProfileLoad("", stderr)
      }
    }
  }

  // Process: save profile
  Process {
    id: profileSaveProcess
    running: false
    command: []
    stdout: StdioCollector { id: saveStdout; waitForEnd: true; onStreamFinished: root._profileLoadOutput = text }
    stderr: StdioCollector { id: saveStderr; waitForEnd: true; onStreamFinished: root._profileLoadError = text }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        lastError = elideStatus(String(saveStderr.text || "Save failed"))
        actionStatus = lastError
        actionStatusTimer.restart()
      } else {
        lastError = ""
        actionStatus = "Profile saved"
        actionStatusTimer.restart()
        loadProfiles()
      }
    }
  }
}
