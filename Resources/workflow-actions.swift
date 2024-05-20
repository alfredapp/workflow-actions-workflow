#!/usr/bin/swift

import Foundation

// Helpers
struct Environment {
  static let env: [String: String] = ProcessInfo.processInfo.environment

  static let alfredPreferences: String = env["alfred_preferences"]!
  static let modNone: String = env["mod_none"]!
  static let modCmd: String = env["mod_cmd"]!
  static let modAlt: String = env["mod_alt"]!
  static let modCtrl: String = env["mod_ctrl"]!
  static let modShift: String = env["mod_shift"]!
}

struct WorkflowHistory: Codable {
  let preferences: Preferences

  struct Preferences: Codable {
    let workflows: [String]
  }
}

struct ModifierAction: Codable {
  let name: String
  let details: Details

  init(_ name: String, subtitle: String) {
    self.name = name
    self.details = Details(subtitle: subtitle, variables: ["action": name])
  }

  struct Details: Codable {
    let subtitle: String
    let variables: [String: String]
  }
}

struct ScriptFilterItem: Codable {
  let variables: [String: String]
  let title: String
  let subtitle: String
  let icon: [String: String]
  let match: String
  let mods: [String: ModifierAction.Details]
  let arg: String
}

struct InfoPlist: Codable {
  let name: String
  let bundleid: String
}

// Constants
let fileManager = FileManager.default
let workflowsParent = URL(fileURLWithPath: "\(Environment.alfredPreferences)/workflows")
let historyFile = URL(
  fileURLWithPath: ("~/Library/Application Support/Alfred/history.json" as NSString)
    .expandingTildeInPath)

// Populate and sort directories
let workflowDirs = try fileManager.contentsOfDirectory(
  at: workflowsParent, includingPropertiesForKeys: nil, options: .skipsHiddenFiles
).filter { fileManager.fileExists(atPath: $0.appendingPathComponent("info.plist").path) }

let editHistory: [URL] = {
  guard fileManager.fileExists(atPath: historyFile.path) else { return [] }

  guard
    let historyData = try? Data(contentsOf: historyFile),
    let historyUIDs = try? JSONDecoder().decode(WorkflowHistory.self, from: historyData)
      .preferences
      .workflows
  else { return [] }

  return historyUIDs.map { workflowsParent.appendingPathComponent($0) }
}()

let sortedDirs = workflowDirs.sorted {
  guard let first = editHistory.firstIndex(of: $0) else { return false }
  guard let second = editHistory.firstIndex(of: $1) else { return true }
  return first < second
}

// Polulate modifiers
let modifiers: [String: ModifierAction.Details] = {
  let actions = [
    ModifierAction("edit_workflow", subtitle: "Edit in Alfred Preferences"),
    ModifierAction("edit_config", subtitle: "Open Configuration"),
    ModifierAction("open_finder", subtitle: "Open in Finder"),
    ModifierAction("open_terminal", subtitle: "Open in Terminal"),
    ModifierAction("open_data_cache_folders", subtitle: "Reveal Data Folders"),
    ModifierAction("export_workflow", subtitle: "Export"),
    ModifierAction("reload_workflow", subtitle: "Reload"),
  ].reduce(into: [:]) { $0[$1.name] = $1.details }

  guard
    let actCmd = actions[Environment.modCmd],
    let actAlt = actions[Environment.modAlt],
    let actCtrl = actions[Environment.modCtrl],
    let actShift = actions[Environment.modShift]
  else { return [:] }

  return [
    "cmd": actCmd,
    "alt": actAlt,
    "ctrl": actCtrl,
    "shift": actShift,
  ]
}()

// Populate items
let sfItems: [ScriptFilterItem] = sortedDirs.compactMap { directory in
  // Grab plist data
  let plistFile = directory.appendingPathComponent("info.plist")

  guard
    let plistData = try? Data(contentsOf: plistFile),
    let plistContents = try? PropertyListDecoder().decode(InfoPlist.self, from: plistData)
  else { return nil }

  let name = plistContents.name
  let bid = plistContents.bundleid.isEmpty ? "[Missing Bundle Identifier]" : plistContents.bundleid

  // Return item
  return ScriptFilterItem(
    variables: ["action": Environment.modNone],
    title: name,
    subtitle: bid,
    icon: ["path": directory.appendingPathComponent("icon.png").path],
    match: "\(name) \(bid)",
    mods: modifiers,
    arg: directory.path
  )
}

// Output JSON
let jsonData = try JSONEncoder().encode(["items": sfItems])
print(String(data: jsonData, encoding: .utf8)!)
