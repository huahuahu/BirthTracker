import Foundation
import Testing

@Suite("Settings debug navigation")
struct SettingsDebugSectionTests {
  @Test("Settings home links to debug settings without embedding debug controls")
  func settingsHomeLinksToDebugSettings() throws {
    let source = try settingsSource(named: "SettingsView.swift")

    #expect(source.contains("NavigationLink"))
    #expect(source.contains("SettingsDebugView()"))
    #expect(!source.contains("SettingsDebugSection()"))
  }

  @Test("Debug settings view hosts the existing debug section in a form")
  func debugSettingsViewHostsDebugSection() throws {
    let source = try settingsSource(named: "SettingsDebugSection.swift")
    let viewRange = try #require(source.range(of: "struct SettingsDebugView: View"))
    let formRange = try #require(source.range(of: "Form {"))
    let sectionRange = try #require(source.range(of: "SettingsDebugSection()"))

    #expect(viewRange.lowerBound < formRange.lowerBound)
    #expect(formRange.lowerBound < sectionRange.lowerBound)
  }

  @Test("Generate button is disabled before feedback overlay is attached")
  func generateButtonDisablesBeforeFeedbackOverlay() throws {
    let source = try settingsSource(named: "SettingsDebugSection.swift")
    let disabledRange = try #require(source.range(of: ".disabled(testDataGeneration.isGenerating)"))
    let feedbackRange = try #require(source.range(of: ".testDataGenerationFeedback("))

    #expect(disabledRange.lowerBound < feedbackRange.lowerBound)
  }

  private func settingsSource(named fileName: String) throws -> String {
    let sourceURL = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appending(path: "Sources/Features/Settings/\(fileName)")

    return try String(contentsOf: sourceURL, encoding: .utf8)
  }
}
