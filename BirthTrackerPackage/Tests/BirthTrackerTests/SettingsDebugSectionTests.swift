import Foundation
import Testing

@Suite("Settings debug section")
struct SettingsDebugSectionTests {
  @Test("Generate button is disabled before feedback overlay is attached")
  func generateButtonDisablesBeforeFeedbackOverlay() throws {
    let sourceURL = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appending(path: "Sources/Features/Settings/SettingsDebugSection.swift")
    let source = try String(contentsOf: sourceURL, encoding: .utf8)
    let disabledRange = try #require(source.range(of: ".disabled(testDataGeneration.isGenerating)"))
    let feedbackRange = try #require(source.range(of: ".testDataGenerationFeedback("))

    #expect(disabledRange.lowerBound < feedbackRange.lowerBound)
  }
}
