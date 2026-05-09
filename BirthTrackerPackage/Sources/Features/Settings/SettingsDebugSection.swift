import DesignSystem
import Localization
import Persistence
import SwiftData
import SwiftUI

#if DEBUG
  struct SettingsDebugSection: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppSettingsKey.storageMode) private var storageMode = DebugStorageMode.local.rawValue
    @State private var testDataGeneration = TestDataGenerationController()

    var body: some View {
      Section(L10n.Settings.debug) {
        Picker(L10n.Settings.database, selection: $storageMode) {
          ForEach(DebugStorageMode.allCases) { mode in
            Text(mode.localizedTitle).tag(mode.rawValue)
          }
        }

        if storageMode == DebugStorageMode.memory.rawValue {
          Button(L10n.Settings.generateTestData, systemImage: "sparkles") {
            testDataGeneration.start(modelContext: modelContext)
          }
          .testDataGenerationFeedback(testDataGeneration, modelContext: modelContext)
          .disabled(testDataGeneration.isGenerating)
        }
      }
    }
  }
#endif
