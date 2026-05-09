import DesignSystem
import Localization
import Models
import Persistence
import SwiftData
import SwiftUI

public struct SettingsView: View {
  @Environment(\.modelContext) private var modelContext
  @AppStorage(AppSettingsKey.appearanceMode) private var appearanceMode = AppearanceMode.system.rawValue
  @AppStorage(AppSettingsKey.enabledCalendarKinds) private var enabledCalendarKinds =
    BirthdayCalendarKind.rawSelectionKinds(
      BirthdayCalendarKind.defaultSelectionKinds)
  #if DEBUG
    @AppStorage(AppSettingsKey.storageMode) private var storageMode = DebugStorageMode.local.rawValue
    @StateObject private var testDataGeneration = TestDataGenerationController()
  #endif

  private var selectedCalendarKinds: [BirthdayCalendarKind] {
    BirthdayCalendarKind.selectionKinds(from: enabledCalendarKinds)
  }

  public init() {}

  public var body: some View {
    Form {
      Section(L10n.Settings.appearance) {
        Picker(L10n.Settings.mode, selection: $appearanceMode) {
          ForEach(AppearanceMode.allCases) { mode in
            Text(mode.localizedTitle).tag(mode.rawValue)
          }
        }
      }

      Section(L10n.Common.calendar) {
        ForEach(BirthdayCalendarKind.allCases) { kind in
          Toggle(kind.localizedTitle, isOn: calendarBinding(for: kind))
        }
      }

      #if DEBUG
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
            .disabled(testDataGeneration.isGenerating)
          }
        }
      #endif
    }
    .navigationTitle(L10n.Settings.title)
    #if DEBUG
      .overlay {
        if testDataGeneration.isShowingHUD {
          TestDataGenerationHUD(title: L10n.Settings.creatingTestData) {
            testDataGeneration.cancel()
          }
        }
      }
      .onAppear {
        testDataGeneration.onAppear()
      }
      .onDisappear {
        testDataGeneration.onDisappear()
      }
      .alert(item: testDataAlertBinding) { alert in
        switch alert {
        case .success:
          return Alert(
            title: Text(L10n.Settings.testDataCreated),
            dismissButton: .default(Text(L10n.Common.ok))
          )
        case .failure(let message):
          return Alert(
            title: Text(L10n.Settings.testDataCreationFailedTitle),
            message: Text(message),
            primaryButton: .default(Text(L10n.Common.retry)) {
              testDataGeneration.start(modelContext: modelContext)
            },
            secondaryButton: .cancel()
          )
        }
      }
    #endif
  }

  private func calendarBinding(for kind: BirthdayCalendarKind) -> Binding<Bool> {
    Binding {
      selectedCalendarKinds.contains(kind)
    } set: { isSelected in
      var kinds = selectedCalendarKinds

      if isSelected {
        if !kinds.contains(kind) {
          kinds.append(kind)
        }
      } else if kinds.count > 1 {
        kinds.removeAll { $0 == kind }
      }

      enabledCalendarKinds = BirthdayCalendarKind.rawSelectionKinds(kinds)
    }
  }

  #if DEBUG
    private var testDataAlertBinding: Binding<TestDataGenerationController.Alert?> {
      Binding(
        get: { testDataGeneration.alert },
        set: { testDataGeneration.alert = $0 }
      )
    }
  #endif
}

#if DEBUG
  private struct TestDataGenerationHUD: View {
    let title: LocalizedStringResource
    let cancel: @MainActor () -> Void

    var body: some View {
      ZStack {
        Color.black.opacity(0.1)
          .allowsHitTesting(false)

        VStack(spacing: 12) {
          ProgressView(title)
            .multilineTextAlignment(.center)
          Button(L10n.Common.cancel) {
            cancel()
          }
          .buttonStyle(.bordered)
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
      }
    }
  }
#endif

#Preview {
  NavigationStack {
    SettingsView()
  }
  .modelContainer(for: TrackedPerson.self, inMemory: true)
}
