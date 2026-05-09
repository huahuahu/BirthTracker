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
    @State private var testDataGeneration = TestDataGenerationController()
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
        SettingsDebugSection(
          storageMode: $storageMode,
          modelContext: modelContext,
          testDataGeneration: testDataGeneration
        )
      #endif
    }
    .navigationTitle(L10n.Settings.title)
    #if DEBUG
      .testDataGenerationFeedback(testDataGeneration, modelContext: modelContext)
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
}

#Preview {
  NavigationStack {
    SettingsView()
  }
  .modelContainer(for: TrackedPerson.self, inMemory: true)
}
