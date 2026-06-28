import Foundation
import Testing

@Suite("Settings debug navigation")
struct SettingsDebugSectionTests {
  @Test("Settings home links to debug settings without embedding debug controls")
  func settingsHomeLinksToDebugSettings() throws {
    let source = try sourceFile(at: "Sources/Features/Settings/SettingsView.swift")

    #expect(source.contains("NavigationLink"))
    #expect(source.contains("SettingsDebugView()"))
    #expect(!source.contains("SettingsDebugSection()"))
  }

  @Test("Debug settings view hosts the existing debug section in a form")
  func debugSettingsViewHostsDebugSection() throws {
    let source = try sourceFile(at: "Sources/Features/Settings/SettingsDebugSection.swift")
    let viewRange = try #require(source.range(of: "struct SettingsDebugView: View"))
    let formRange = try #require(source.range(of: "Form {"))
    let sectionRange = try #require(source.range(of: "SettingsDebugSection()"))

    #expect(viewRange.lowerBound < formRange.lowerBound)
    #expect(formRange.lowerBound < sectionRange.lowerBound)
  }

  @Test("Debug settings delegates storage controls to the Debug Storage directory")
  func debugSettingsDelegatesStorageControlsToDebugStorageDirectory() throws {
    let debugSource = try sourceFile(at: "Sources/Features/Settings/SettingsDebugSection.swift")
    let storageSource = try sourceFile(at: "Sources/Features/Settings/Debug/Storage/DebugStorageSection.swift")

    #expect(debugSource.contains("DebugStorageSection()"))
    #expect(storageSource.contains("struct DebugStorageSection: View"))
    #expect(storageSource.contains("Picker(L10n.Settings.database"))
    #expect(storageSource.contains("L10n.Settings.resetTestData"))
  }

  @Test("Reset button is disabled before feedback overlay is attached")
  func resetButtonDisablesBeforeFeedbackOverlay() throws {
    let source = try sourceFile(at: "Sources/Features/Settings/Debug/Storage/DebugStorageSection.swift")
    let disabledRange = try #require(source.range(of: ".disabled(testDataGeneration.isGenerating)"))
    let feedbackRange = try #require(source.range(of: ".testDataGenerationFeedback("))

    #expect(disabledRange.lowerBound < feedbackRange.lowerBound)
  }

  @Test("Generation state is cleared before feedback alert is shown")
  func generationStateClearsBeforeFeedbackAlert() throws {
    let source = try sourceFile(at: "Sources/Features/Settings/Debug/Storage/TestDataGenerationController.swift")
    let taskRange = try #require(source.range(of: "generationTask = Task"))
    let feedbackRange = try #require(source.range(of: "finishGeneration()\n      feedback = nextFeedback"))

    #expect(taskRange.lowerBound < feedbackRange.lowerBound)
  }

  @Test("Test data controller resets rather than appending samples")
  func testDataControllerResetsRatherThanAppendingSamples() throws {
    let source = try sourceFile(at: "Sources/Features/Settings/Debug/Storage/TestDataGenerationController.swift")

    #expect(source.contains("TestDataGenerator.resetSamplePeople(into: modelContext)"))
    #expect(!source.contains("TestDataGenerator.generateSamplePeople(into: modelContext)"))
  }

  private func sourceFile(at relativePath: String) throws -> String {
    let sourceURL = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appending(path: relativePath)

    return try String(contentsOf: sourceURL, encoding: .utf8)
  }
}
