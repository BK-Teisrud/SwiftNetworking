import Foundation

// Repository maintenance only. This file is not part of any library product.
// Invoke from any directory with: swift /path/to/Tools/RepositoryTools.swift <command>
struct ToolFailure: Error, CustomStringConvertible {
  let description: String
  init(_ description: String) { self.description = description }
}

let files = FileManager.default
let modules = ["Networking", "NetworkingTransfers", "NetworkingRealtime", "NetworkingSync"]
let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
  .deletingLastPathComponent()

func directory(_ url: URL) throws {
  try files.createDirectory(at: url, withIntermediateDirectories: true)
}

func children(_ url: URL) throws -> [URL] {
  try files.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
    .sorted { $0.lastPathComponent < $1.lastPathComponent }
}

@discardableResult
func run(
  _ arguments: [String], at root: URL = repository,
  environment: [String: String] = [:], capture: Bool = false
) throws -> String {
  let process = Process()
  process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
  process.arguments = arguments
  process.currentDirectoryURL = root
  process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
  // Capture to a file rather than an undrained pipe: commands may emit more than a pipe buffer.
  let output = files.temporaryDirectory.appendingPathComponent(
    "networking-tool-\(UUID().uuidString)")
  var handle: FileHandle?
  if capture {
    guard files.createFile(atPath: output.path, contents: nil) else {
      throw ToolFailure("Cannot create command output file")
    }
    handle = try FileHandle(forWritingTo: output)
    process.standardOutput = handle
  }
  defer {
    try? handle?.close()
    if capture { try? files.removeItem(at: output) }
  }
  try process.run()
  process.waitUntilExit()
  guard process.terminationReason == .exit, process.terminationStatus == 0 else {
    throw ToolFailure(
      "Command failed (\(process.terminationStatus)): \(arguments.joined(separator: " "))")
  }
  return capture ? try String(contentsOf: output, encoding: .utf8) : ""
}

func synchronize(at root: URL, check: Bool) throws {
  var mismatches: [String] = []
  let articles = try children(root.appendingPathComponent("Docs")).filter {
    $0.pathExtension == "md"
  }
  for module in modules {
    let guides = root.appendingPathComponent("Sources/\(module)/\(module).docc/Guides")
    var expected: [String: String] = [:]
    for article in articles {
      let name =
        article.lastPathComponent == "README.md" ? "Handbook.md" : article.lastPathComponent
      expected[name] = try String(contentsOf: article, encoding: .utf8)
        .replacingOccurrences(of: "](README.md)", with: "](Handbook.md)")
    }
    for name in expected.keys.sorted() {
      let destination = guides.appendingPathComponent(name)
      if (try? String(contentsOf: destination, encoding: .utf8)) != expected[name] {
        mismatches.append("\(module)/Guides/\(name)")
        if !check {
          try directory(guides)
          try expected[name]!.write(to: destination, atomically: true, encoding: .utf8)
        }
      }
    }
    if files.fileExists(atPath: guides.path) {
      for stale in try children(guides)
      where stale.pathExtension == "md" && expected[stale.lastPathComponent] == nil {
        mismatches.append("\(module)/Guides/\(stale.lastPathComponent)")
        if !check { try files.removeItem(at: stale) }
      }
    }
  }
  if check && !mismatches.isEmpty {
    throw ToolFailure("DocC articles out of sync:\n" + mismatches.joined(separator: "\n"))
  }
  print(check ? "DocC articles verified" : "DocC articles synchronized")
}

func generateAPI(symbols root: URL, output: URL) throws {
  guard let enumerator = files.enumerator(at: root, includingPropertiesForKeys: nil) else {
    throw ToolFailure("Cannot enumerate symbol graphs: \(root.path)")
  }
  let graphs = enumerator.compactMap { $0 as? URL }.filter {
    $0.lastPathComponent.hasSuffix(".symbols.json")
  }
  .sorted { $0.path < $1.path }
  var byModule: [String: [String: [String: Any]]] = [:]
  for graphURL in graphs {
    guard
      let graph = try JSONSerialization.jsonObject(with: Data(contentsOf: graphURL))
        as? [String: Any],
      let module = graph["module"] as? [String: Any], let name = module["name"] as? String
    else { throw ToolFailure("Invalid symbol graph: \(graphURL.path)") }
    guard modules.contains(name) else { continue }
    for symbol in graph["symbols"] as? [[String: Any]] ?? []
    where symbol["accessLevel"] as? String == "public" {
      guard let identifier = symbol["identifier"] as? [String: Any],
        let precise = identifier["precise"] as? String
      else {
        throw ToolFailure("Missing public symbol identifier in \(graphURL.path)")
      }
      byModule[name, default: [:]][precise] = symbol
    }
  }
  // Reject incomplete extraction instead of publishing a silently empty API reference.
  for module in modules where byModule[module]?.isEmpty != false {
    throw ToolFailure("No public symbols found for \(module)")
  }
  var lines = [
    "# Komplett offentlig API-referanse", "",
    "Generert fra Swift-symbolgraphs. Ikke rediger deklarasjonene manuelt.", "",
    "Se [håndboken](README.md) for defaults, eksempler, sikkerhetsgrenser og lifecycle. Referansen inkluderer alle offentlige deklarasjoner og eventuelle syntetiserte protokollmedlemmer fra den bygde toolchainen.",
    "",
  ]
  for module in modules {
    let symbols = byModule[module]!.sorted { left, right in
      let a = left.value["pathComponents"] as? [String] ?? []
      let b = right.value["pathComponents"] as? [String] ?? []
      return a == b ? left.key < right.key : a.lexicographicallyPrecedes(b)
    }
    lines += ["## \(module)", "", "\(symbols.count) offentlige symboler.", ""]
    for (_, symbol) in symbols {
      let names = symbol["names"] as? [String: Any] ?? [:]
      let title = (symbol["pathComponents"] as? [String] ?? [names["title"] as? String ?? ""])
        .joined(separator: ".")
      let declaration = (symbol["declarationFragments"] as? [[String: Any]] ?? [])
        .compactMap { $0["spelling"] as? String }.joined()
      lines += ["### \(title)", "", "```swift", declaration, "```", ""]
      let comment = symbol["docComment"] as? [String: Any] ?? [:]
      let doc = (comment["lines"] as? [[String: Any]] ?? []).compactMap { $0["text"] as? String }
        .joined(separator: "\n")
      if !doc.isEmpty && symbol["location"] is [String: Any] { lines += [doc, ""] }
    }
  }
  try directory(output.deletingLastPathComponent())
  try lines.joined(separator: "\n").write(to: output, atomically: true, encoding: .utf8)
  print("Generated \(output.path): \(byModule.values.reduce(0) { $0 + $1.count }) public symbols")
}

func buildDocumentation(at root: URL, scratch: URL, output: URL, shipped: Bool) throws {
  if shipped { try synchronize(at: root, check: true) }
  let cache = scratch.appendingPathComponent("module-cache")
  let symbols = output.appendingPathComponent("symbolgraphs")
  try directory(cache)
  try directory(symbols)
  try run(
    [
      "swift", "build", "--disable-sandbox", "--scratch-path", scratch.path,
      "-Xswiftc", "-module-cache-path", "-Xswiftc", cache.path,
    ], at: root,
    environment: [
      "CLANG_MODULE_CACHE_PATH": cache.path, "SWIFTPM_MODULECACHE_OVERRIDE": cache.path,
    ])
  let sdk = try run(["xcrun", "--sdk", "macosx", "--show-sdk-path"], capture: true)
    .trimmingCharacters(in: .whitespacesAndNewlines)
  let architecture = try run(["uname", "-m"], capture: true).trimmingCharacters(
    in: .whitespacesAndNewlines)
  for module in modules {
    let moduleSymbols = symbols.appendingPathComponent(module)
    try directory(moduleSymbols)
    for stale in try children(moduleSymbols)
    where stale.lastPathComponent.hasSuffix(".symbols.json") {
      try files.removeItem(at: stale)
    }
    try run(
      [
        "xcrun", "swift-symbolgraph-extract", "-module-name", module,
        "-I", scratch.appendingPathComponent("debug/Modules").path,
        "-target", "\(architecture)-apple-macosx13.0", "-sdk", sdk,
        "-module-cache-path", cache.path, "-minimum-access-level", "public", "-output-dir",
        moduleSymbols.path,
      ], at: root)
  }
  if !shipped {
    try generateAPI(symbols: symbols, output: root.appendingPathComponent("Docs/API.md"))
    try synchronize(at: root, check: false)
  }
  for module in modules {
    try run(
      [
        "xcrun", "docc", "convert",
        root.appendingPathComponent("Sources/\(module)/\(module).docc").path,
        "--warnings-as-errors", "--additional-symbol-graph-dir",
        symbols.appendingPathComponent(module).path,
        "--fallback-display-name", module, "--fallback-bundle-identifier", "com.teisrud.\(module)",
        "--output-path", output.appendingPathComponent("\(module).doccarchive").path,
      ], at: root)
  }
  print("Documentation archives: \(output.path)")
}

func checkDistribution() throws {
  let temporary = files.temporaryDirectory.appendingPathComponent(
    "networking-distribution-\(UUID().uuidString)")
  let package = temporary.appendingPathComponent("package")
  try directory(package)
  defer { try? files.removeItem(at: temporary) }
  for name in [
    "Sources", "Tests", "Docs", "Tools", "Package.swift", "README.md", "LICENSE", "SECURITY.md",
  ] {
    try files.copyItem(
      at: repository.appendingPathComponent(name), to: package.appendingPathComponent(name))
  }
  let guide = package.appendingPathComponent(
    "Sources/Networking/Networking.docc/Guides/GettingStarted.md")
  let data = try Data(contentsOf: guide)
  try files.removeItem(at: guide)
  do {
    try synchronize(at: package, check: true)
    throw ToolFailure("Missing distributed article was incorrectly accepted")
  } catch let error as ToolFailure {
    guard error.description.hasPrefix("DocC articles out of sync:") else { throw error }
  }
  try data.write(to: guide)
  print("Missing guide detection verified")
  try buildDocumentation(
    at: package, scratch: temporary.appendingPathComponent("build"),
    output: temporary.appendingPathComponent("docs"), shipped: true)
  print("Clean distribution documentation verified")
}

func testIOS() throws {
  let json = try run(["xcrun", "simctl", "list", "devices", "available", "-j"], capture: true)
  guard let graph = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any],
    let devices = graph["devices"] as? [String: [[String: Any]]]
  else { throw ToolFailure("Cannot decode simulator inventory") }
  let available = devices.keys.sorted { $0.compare($1, options: .numeric) == .orderedDescending }
    .filter { $0.contains("iOS") }.flatMap { devices[$0] ?? [] }
  guard
    let simulator = available.first(where: { ($0["name"] as? String)?.contains("iPhone") == true }),
    let identifier = simulator["udid"] as? String
  else { throw ToolFailure("No available iPhone simulator") }
  let temporary = URL(
    fileURLWithPath: ProcessInfo.processInfo.environment["RUNNER_TEMP"]
      ?? files.temporaryDirectory.appendingPathComponent(
        "networking-ios-tests-\(UUID().uuidString)"
      ).path)
  try directory(temporary)
  print("iOS test results: \(temporary.appendingPathComponent("networking-tests.xcresult").path)")
  try run([
    "xcodebuild", "-scheme", "Networking-Package", "-destination",
    "platform=iOS Simulator,id=\(identifier)",
    "-derivedDataPath", temporary.appendingPathComponent("networking-derived-data").path,
    "-resultBundlePath", temporary.appendingPathComponent("networking-tests.xcresult").path, "test",
  ])
}

let usage = """
  Usage: swift Tools/RepositoryTools.swift <command>
    sync [--check]                          Synchronize or verify shipped DocC guides
    api <symbolgraphs-directory> <output>   Generate API Markdown from all four modules
    docs [--scratch PATH] [--output PATH] [--use-shipped-guides]
                                           Build API reference and DocC archives
    distribution                           Verify a clean package and missing-guide detection
    ios-test                               Test all products on an available iPhone simulator
  """

do {
  let arguments = Array(CommandLine.arguments.dropFirst())
  switch arguments.first {
  case "sync":
    guard arguments.count == 1 || arguments == ["sync", "--check"] else { throw ToolFailure(usage) }
    try synchronize(at: repository, check: arguments.count == 2)
  case "api":
    guard arguments.count == 3 else { throw ToolFailure(usage) }
    try generateAPI(
      symbols: URL(fileURLWithPath: arguments[1]), output: URL(fileURLWithPath: arguments[2]))
  case "docs":
    var scratch = URL(fileURLWithPath: "/tmp/networking-documentation-build")
    var output = URL(fileURLWithPath: "/tmp/networking-documentation")
    var shipped = false
    var index = 1
    while index < arguments.count {
      switch arguments[index] {
      case "--use-shipped-guides": shipped = true
      case "--scratch", "--output":
        guard index + 1 < arguments.count else { throw ToolFailure(usage) }
        let value = URL(fileURLWithPath: arguments[index + 1])
        if arguments[index] == "--scratch" { scratch = value } else { output = value }
        index += 1
      default: throw ToolFailure(usage)
      }
      index += 1
    }
    try buildDocumentation(at: repository, scratch: scratch, output: output, shipped: shipped)
  case "distribution":
    guard arguments.count == 1 else { throw ToolFailure(usage) }
    try checkDistribution()
  case "ios-test":
    guard arguments.count == 1 else { throw ToolFailure(usage) }
    try testIOS()
  case "--help", "help": print(usage)
  default: throw ToolFailure(usage)
  }
} catch {
  FileHandle.standardError.write(Data("Error: \(error)\n".utf8))
  exit(1)
}
