import DesignSystem
import Localization
import Persistence
import SFSafeSymbols
import SwiftData
import SwiftUI

#if DEBUG
  struct DebugStorageSection: View {
    @Environment(\.modelContext)
    private var modelContext
    @AppStorage(AppSettingsKey.storageMode)
    private var storageMode = DebugStorageMode.local.rawValue
    @State private var restartPrompt: RestartPrompt?
    @State private var testDataGeneration = TestDataGenerationController()

    var body: some View {
      Section(L10n.Settings.database) {
        Picker(L10n.Settings.database, selection: storageModeBinding) {
          ForEach(DebugStorageMode.allCases) { mode in
            Text(mode.localizedTitle).tag(mode.rawValue)
          }
        }

        Button(L10n.Settings.resetTestData, systemImage: SFSymbol.arrowCounterclockwise.rawValue) {
          testDataGeneration.start(modelContext: modelContext)
        }
        .disabled(testDataGeneration.isGenerating)
        .testDataGenerationFeedback(testDataGeneration, modelContext: modelContext)
      }
      .alert(item: restartPromptBinding) { _ in
        Alert(
          title: Text(L10n.Settings.storageRestartRequiredTitle),
          message: Text(L10n.Settings.storageRestartRequiredMessage),
          dismissButton: .default(Text(L10n.Common.ok))
        )
      }
    }

    private var storageModeBinding: Binding<String> {
      Binding {
        storageMode
      } set: { newValue in
        guard storageMode != newValue else { return }
        storageMode = newValue
        restartPrompt = RestartPrompt()
      }
    }

    private var restartPromptBinding: Binding<RestartPrompt?> {
      Binding {
        restartPrompt
      } set: {
        restartPrompt = $0
      }
    }
  }

  private struct RestartPrompt: Identifiable {
    let id = UUID()
  }
#endif
