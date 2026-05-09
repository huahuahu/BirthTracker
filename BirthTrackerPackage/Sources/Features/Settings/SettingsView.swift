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
    @State private var isGeneratingTestData = false
    @State private var isShowingTestDataHUD = false
    @State private var isViewVisible = false
    @State private var generateTestDataTask: Task<Void, Never>?
    @State private var generateTestDataHUDDelayTask: Task<Void, Never>?
    @State private var testDataAlert: TestDataAlert?
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
              startGenerateTestData()
            }
            .disabled(isGeneratingTestData)
          }
        }
      #endif
    }
    .navigationTitle(L10n.Settings.title)
    #if DEBUG
      .overlay {
        if isShowingTestDataHUD {
          TestDataGenerationHUD(title: L10n.Settings.creatingTestData) {
            cancelGenerateTestData()
          }
        }
      }
      .alert(item: $testDataAlert) { alert in
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
              startGenerateTestData()
            },
            secondaryButton: .cancel()
          )
        }
      }
      .onAppear {
        isViewVisible = true
      }
      .onDisappear {
        isViewVisible = false
        cancelGenerateTestData()
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
    private enum TestDataAlert: Identifiable {
      case success
      case failure(message: String)

      var id: String {
        switch self {
        case .success: "success"
        case .failure: "failure"
        }
      }
    }

    private func startGenerateTestData() {
      guard !isGeneratingTestData else { return }

      isGeneratingTestData = true
      isShowingTestDataHUD = false
      testDataAlert = nil

      generateTestDataHUDDelayTask?.cancel()
      generateTestDataHUDDelayTask = Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled, isGeneratingTestData else { return }
        isShowingTestDataHUD = true
      }

      generateTestDataTask?.cancel()
      generateTestDataTask = Task { @MainActor in
        defer {
          isGeneratingTestData = false
          isShowingTestDataHUD = false
          generateTestDataTask = nil
          generateTestDataHUDDelayTask?.cancel()
          generateTestDataHUDDelayTask = nil
        }

        do {
          try await TestDataGenerator.generateSamplePeople(into: modelContext)
          guard !Task.isCancelled else { return }
          guard isViewVisible else { return }
          testDataAlert = .success
        } catch is CancellationError {
          // Cancellation is user intent: no success/failure prompt.
        } catch {
          guard isViewVisible else { return }
          let message = L10n.Settings.testDataCreationFailedMessage(error.localizedDescription)
          testDataAlert = .failure(message: message)
        }
      }
    }

    private func cancelGenerateTestData() {
      generateTestDataTask?.cancel()
      generateTestDataHUDDelayTask?.cancel()
      generateTestDataTask = nil
      generateTestDataHUDDelayTask = nil
      isGeneratingTestData = false
      isShowingTestDataHUD = false
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
          .ignoresSafeArea()

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
