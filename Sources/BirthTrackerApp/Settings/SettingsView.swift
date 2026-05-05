import SwiftData
import SwiftUI

struct SettingsView: View {
  @Environment(\.modelContext) private var modelContext
  @AppStorage(AppSettingsKey.appearanceMode) private var appearanceMode = AppearanceMode.system.rawValue
  @AppStorage(AppSettingsKey.enabledCalendarKinds) private var enabledCalendarKinds =
    BirthdayCalendarKind.rawSelectionKinds(
      BirthdayCalendarKind.defaultSelectionKinds)
  #if DEBUG
    @AppStorage(AppSettingsKey.storageMode) private var storageMode = DebugStorageMode.local.rawValue
  #endif

  private var selectedCalendarKinds: [BirthdayCalendarKind] {
    BirthdayCalendarKind.selectionKinds(from: enabledCalendarKinds)
  }

  var body: some View {
    Form {
      Section("Appearance") {
        Picker("Mode", selection: $appearanceMode) {
          ForEach(AppearanceMode.allCases) { mode in
            Text(mode.title).tag(mode.rawValue)
          }
        }
      }

      Section("Calendar") {
        ForEach(BirthdayCalendarKind.allCases) { kind in
          Toggle(kind.title, isOn: calendarBinding(for: kind))
        }
      }

      #if DEBUG
        Section("Debug") {
          Picker("Database", selection: $storageMode) {
            ForEach(DebugStorageMode.allCases) { mode in
              Text(mode.title).tag(mode.rawValue)
            }
          }

          if storageMode == DebugStorageMode.memory.rawValue {
            Button("Generate Test Data", systemImage: "sparkles") {
              generateTestData()
            }
          }
        }
      #endif
    }
    .navigationTitle("Settings")
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
    private func generateTestData() {
      let examples: [(String, Birthday, String)] = [
        ("Alex Chen", Birthday(calendarKind: .gregorian, year: 1990, month: 1, day: 12), "Sample local contact"),
        ("Jamie Lin", Birthday(calendarKind: .gregorian, year: 1988, month: 5, day: 5), "Sample coworker"),
        ("Morgan Lee", Birthday(calendarKind: .gregorian, year: 2016, month: 11, day: 23), "Sample family member"),
      ]

      for example in examples {
        modelContext.insert(TrackedPerson(name: example.0, birthday: example.1, notes: example.2))
      }

      try? modelContext.save()
    }
  #endif
}

#Preview {
  NavigationStack {
    SettingsView()
  }
  .modelContainer(for: TrackedPerson.self, inMemory: true)
}
