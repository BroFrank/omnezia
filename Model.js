pragma ComponentBehavior: Bound

/*
 * Model.js — WireGuard / AmneziaWG config parsing utilities
 *
 * Parses raw WireGuard-style config text into structured JSON objects.
 * Used by Service.qml to parse profile configs and interface status.
 */

function parseConfig(text) {
  var lines = String(text || "").split("\n")
  var result = { ok: false, name: "", interface: {}, peer: {}, error: "" }

  var section = null // "Interface" or "Peer"
  var currentSection = {}

  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim()

    // Skip empty lines and comments
    if (line === "" || line.startsWith("#") || line.startsWith(";")) continue

    // Section headers
    if (line.match(/^\[Interface\]$/i)) {
      section = "interface"
      currentSection = {}
      continue
    }
    if (line.match(/^\[Peer\]$/i)) {
      section = "peer"
      currentSection = {}
      continue
    }

    // Parse key=value pairs
    var kvMatch = line.match(/^([^=]+?)\s*=\s*(.+)$/)
    if (!kvMatch) continue

    var key = kvMatch[1].trim()
    var value = kvMatch[2].trim()

    if (section === "interface") {
      currentSection[key] = parseValue(key, value)
    } else if (section === "peer") {
      currentSection[key] = parseValue(key, value)
    }
  }

  // Validate minimum required fields
  if (!currentSection || !section) {
    result.error = "No config sections found"
    return result
  }

  var iface = section === "interface" ? currentSection : {}
  var peer = section === "peer" ? currentSection : {}

  // Validate Interface has PrivateKey
  if (!iface.PrivateKey || iface.PrivateKey.length < 40) {
    result.error = "Interface missing or invalid PrivateKey"
    return result
  }

  // Validate Peer has PublicKey
  if (!peer.PublicKey || peer.PublicKey.length < 40) {
    result.error = "Peer missing or invalid PublicKey"
    return result
  }

  result.ok = true
  result.interface = iface
  result.peer = peer

  return result
}

function parseValue(key, value) {
  // Arrays (Address, AllowedIPs) — comma-separated or newline-separated
  if (key === "Address" || key === "AllowedIPs") {
    var parts = String(value).split(",").map(function(s) { return s.trim() }).filter(function(s) { return s !== "" })
    return parts.length > 0 ? parts : [value]
  }

  // Numeric fields
  if (key === "ListenPort" || key === "PersistentKeepalive" ||
      key === "S1" || key === "S2" || key === "S3" || key === "S4" ||
      key === "Jc" || key === "Jmin" || key === "Jmax" ||
      key === "ContentPaddingAddition" ||
      key === "RekeyAfterTime" || key === "RekeyTimeout" ||
      key === "RejectAfterTime" || key === "KeepaliveTimeout" ||
      key === "MaxHandshakeAttempts") {
    var n = parseInt(value, 10)
    if (isFinite(n)) return n
    // Handle "(off)" for S3/H3 etc.
    if (value.toLowerCase() === "(off)") return null
    return 0
  }

  // Range strings like "696-700" or "(off)"
  if (key.match(/^H[1-4]$/)) {
    if (value.toLowerCase() === "(off)") return null
    return value
  }

  // Custom signature packets I1-I5 — keep as-is
  if (key.match(/^I[1-5]$/)) {
    return value
  }

  // Everything else is a string (PrivateKey, PublicKey, Endpoint, HeaderProtectionKey)
  return value
}

function configToText(config) {
  /* Serialize a parsed config object back to WireGuard-style text format */
  if (!config || !config.ok) return ""

  var lines = []

  // [Interface] section
  lines.push("[Interface]")
  var iface = config.interface
  if (iface.Address && iface.Address.length > 0) {
    lines.push("Address = " + iface.Address.join(", "))
  }
  if (iface.PrivateKey) lines.push("PrivateKey = " + iface.PrivateKey)
  if (iface.ListenPort && iface.ListenPort > 0) lines.push("ListenPort = " + iface.ListenPort)

  // AmneziaWG-specific interface params
  addIfNotNull(lines, "S1", iface.S1)
  addIfNotNull(lines, "S2", iface.S2)
  addIfNotNull(lines, "S3", formatOffOrNull(iface.S3))
  addIfNotNull(lines, "S4", iface.S4)
  addIfNotNull(lines, "Jc", iface.Jc)
  addIfNotNull(lines, "Jmin", iface.Jmin)
  addIfNotNull(lines, "Jmax", iface.Jmax)
  addIfRange(lines, "H1", iface.H1)
  addIfRange(lines, "H2", iface.H2)
  addIfRange(lines, "H3", iface.H3)
  addIfRange(lines, "H4", iface.H4)
  addRawText(lines, "I1", iface.I1)
  addRawText(lines, "I2", iface.I2)
  addRawText(lines, "I3", iface.I3)
  addRawText(lines, "I4", iface.I4)
  addRawText(lines, "I5", iface.I5)
  if (iface.HeaderProtectionKey) lines.push("HeaderProtectionKey = " + iface.HeaderProtectionKey)
  if (iface.ContentPaddingAddition && iface.ContentPaddingAddition > 0) {
    lines.push("ContentPaddingAddition = " + iface.ContentPaddingAddition)
  }
  addIfNotNull(lines, "RekeyAfterTime", iface.RekeyAfterTime)
  addIfNotNull(lines, "RekeyTimeout", iface.RekeyTimeout)
  addIfNotNull(lines, "RejectAfterTime", iface.RejectAfterTime)
  addIfNotNull(lines, "KeepaliveTimeout", iface.KeepaliveTimeout)
  addIfNotNull(lines, "MaxHandshakeAttempts", iface.MaxHandshakeAttempts)

  // [Peer] section
  lines.push("")
  lines.push("[Peer]")
  var peer = config.peer
  if (peer.PublicKey) lines.push("PublicKey = " + peer.PublicKey)
  if (peer.Endpoint) lines.push("Endpoint = " + peer.Endpoint)
  if (peer.AllowedIPs && peer.AllowedIPs.length > 0) {
    lines.push("AllowedIPs = " + peer.AllowedIPs.join(", "))
  }
  addIfNotNull(lines, "PersistentKeepalive", peer.PersistentKeepalive)

  return lines.join("\n")
}

function formatOffOrNull(value) {
  if (value === null || value === undefined) return "(off)"
  return String(value)
}

function addIfNotNull(lines, key, value) {
  if (value !== null && value !== undefined && value !== "") {
    lines.push(key + " = " + String(value))
  }
}

function addIfRange(lines, key, value) {
  if (value !== null && value !== undefined && value !== "") {
    lines.push(key + " = " + String(value))
  }
}

function addRawText(lines, key, value) {
  if (value && String(value).trim() !== "") {
    lines.push(key + " = " + String(value))
  }
}

function isValidPrivateKey(key) {
  // Base64-encoded, 44 chars for WireGuard private keys
  return key && key.length === 44 && /^[A-Za-z0-9+\/=]+$/.test(key)
}

function isValidPublicKey(key) {
  // Base64-encoded, 44 chars for WireGuard public keys
  return key && key.length === 44 && /^[A-Za-z0-9+\/=]+$/.test(key)
}
