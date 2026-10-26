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

/**
 * Convert a decoded Amnezia vpn:// JSON into our profile format.
 *
 * The decoded vpn:// structure:
 *   { containers: [...], dns1: "...", dns2: "..." }
 * Each container has protocol configs like:
 *   { awg: { last_config: "{ config: WG_template, mtu: ..., port: ... }" } }
 */
function vpnKeyToProfile(decodedJson, profileName) {
  var result = { ok: false, name: profileName || "", interface: {}, peer: {}, error: "" }

  if (!decodedJson || !decodedJson.containers || decodedJson.containers.length === 0) {
    result.error = "No containers in vpn:// config"
    return result
  }

  // Use the last container (most recent config)
  var lastContainer = decodedJson.containers[decodedJson.containers.length - 1]
  if (!lastContainer.awg || !lastContainer.awg.last_config) {
    result.error = "No AmneziaWG config in containers"
    return result
  }

  try {
    var lastConfig = JSON.parse(lastContainer.awg.last_config)
    var wgTemplate = String(lastConfig.config || "")

    // Replace DNS placeholders with actual values from decoded json
    if (decodedJson.dns1) wgTemplate = wgTemplate.replace("$PRIMARY_DNS", decodedJson.dns1)
    if (decodedJson.dns2) wgTemplate = wgTemplate.replace("$SECONDARY_DNS", decodedJson.dns2)

    // Parse the WireGuard config template
    var parsed = parseConfig(wgTemplate)
    if (!parsed.ok) {
      result.error = parsed.error || "Failed to parse WireGuard config from vpn:// key"
      return result
    }

    // Copy interface and peer data
    result.interface = parsed.interface
    result.peer = parsed.peer

    // Add AmneziaWG-specific params from lastConfig if available
    if (lastConfig.mtu) {
      // MTU is not a standard WG param but we store it for reference
      result.interface.MTU = lastConfig.mtu
    }
    if (lastConfig.port && parseInt(lastConfig.port, 10) > 0) {
      result.interface.ListenPort = parseInt(lastConfig.port, 10)
    }

    // Extract AmneziaWG params from the template if present
    var lines = wgTemplate.split("\n")
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim()
      var kvMatch = line.match(/^([^=]+?)\s*=\s*(.+)$/)
      if (!kvMatch) continue

      var key = kvMatch[1].trim()
      var value = kvMatch[2].trim()

      // AmneziaWG-specific params go into interface section
      if (key === "S1" || key === "S2" || key === "S3" || key === "S4") {
        result.interface[key] = parseValue(key, value)
      } else if (key === "Jc" || key === "Jmin" || key === "Jmax") {
        result.interface[key] = parseValue(key, value)
      } else if (key.match(/^H[1-4]$/)) {
        result.interface[key] = parseValue(key, value)
      } else if (key.match(/^I[1-5]$/)) {
        result.interface[key] = value
      } else if (key === "HeaderProtectionKey") {
        result.interface[key] = value
      } else if (key === "ContentPaddingAddition") {
        var n = parseInt(value, 10)
        if (isFinite(n)) result.interface[key] = n
      } else if (key === "RekeyAfterTime" || key === "RekeyTimeout" ||
                 key === "RejectAfterTime" || key === "KeepaliveTimeout" ||
                 key === "MaxHandshakeAttempts") {
        var n2 = parseInt(value, 10)
        if (isFinite(n2)) result.interface[key] = n2
      }
    }

    result.ok = true
    return result
  } catch (e) {
    result.error = "Failed to parse vpn:// config: " + String(e)
    return result
  }
}
