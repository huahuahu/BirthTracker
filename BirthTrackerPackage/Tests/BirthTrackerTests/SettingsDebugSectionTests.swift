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
    let disabledRange = try #require(
      source.range(of: ".disabled(testDataGeneration.isGenerating || hasPendingStorageModeChange)"))
    let feedbackRange = try #require(source.range(of: ".testDataGenerationFeedback("))

    #expect(disabledRange.lowerBound < feedbackRange.lowerBound)
  }

  @Test("Debug storage disables reset and shows restart guidance when storage mode is pending")
  func debugStorageDisablesResetAndShowsRestartGuidanceWhenStorageModeIsPending() throws {
    let source = try sourceFile(at: "Sources/Features/Settings/Debug/Storage/DebugStorageSection.swift")
    let environmentRange = try #require(source.range(of: "@Environment(\\.activeDebugStorageMode)"))
    let pendingRange = try #require(source.range(of: "storageMode != activeDebugStorageMode.rawValue"))
    let disabledRange = try #require(
      source.range(of: ".disabled(testDataGeneration.isGenerating || hasPendingStorageModeChange)"))
    let messageRange = try #require(source.range(of: "Text(L10n.Settings.storageRestartRequiredMessage)"))

    #expect(environmentRange.lowerBound < disabledRange.lowerBound)
    #expect(pendingRange.lowerBound > disabledRange.lowerBound)
    #expect(disabledRange.lowerBound < messageRange.lowerBound)
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

  @Test("Root view does not hot swap model containers when debug storage changes")
  func rootViewDoesNotHotSwapModelContainersWhenDebugStorageChanges() throws {
    let source = try sourceFile(at: "Sources/App/BirthTrackerRootView.swift")

    #expect(!source.contains("@AppStorage(AppSettingsKey.storageMode)"))
    #expect(!source.contains(".onChange(of: storageMode)"))
    #expect(!source.contains("modelContainerID"))
  }

  @Test("Root view injects active debug storage mode captured at startup")
  func rootViewInjectsActiveDebugStorageModeCapturedAtStartup() throws {
    let source = try sourceFile(at: "Sources/App/BirthTrackerRootView.swift")
    let stateRange = try #require(source.range(of: "@State private var activeDebugStorageMode: DebugStorageMode"))
    let captureRange = try #require(source.range(of: "let startupStorageMode = DebugStorageMode.current"))
    let containerRange = try #require(
      source.range(of: "Self.makeModelContainer(storageMode: startupStorageMode)"))
    let environmentRange = try #require(
      source.range(of: ".environment(\\.activeDebugStorageMode, activeDebugStorageMode)"))

    #expect(stateRange.lowerBound < captureRange.lowerBound)
    #expect(captureRange.lowerBound < containerRange.lowerBound)
    #expect(containerRange.lowerBound < environmentRange.lowerBound)
  }

  @Test("Features module defines active debug storage mode environment value")
  func featuresModuleDefinesActiveDebugStorageModeEnvironmentValue() throws {
    let source = try sourceFile(at: "Sources/Features/Support/ActiveDebugStorageModeEnvironment.swift")

    #expect(source.contains("struct ActiveDebugStorageModeKey: EnvironmentKey"))
    #expect(source.contains("static let defaultValue: DebugStorageMode = .local"))
    #expect(source.contains("var activeDebugStorageMode: DebugStorageMode"))
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
