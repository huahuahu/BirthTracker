import DesignSystem
import Features
import Persistence
import SwiftData
import SwiftUI

public struct BirthTrackerRootView: View {
  @State private var modelContainer = makeModelContainer()
  @State private var modelContainerID = UUID()
  #if DEBUG
    @AppStorage(AppSettingsKey.storageMode) private var storageMode = DebugStorageMode.local.rawValue
  #endif

  public init() {}

  public var body: some View {
    PeopleTimelineView()
      .id(modelContainerID)
      .modelContainer(modelContainer)
      #if DEBUG
        .onChange(of: storageMode) {
          modelContainer = Self.makeModelContainer(storageMode: activeStorageMode)
          modelContainerID = UUID()
        }
      #endif
  }

  #if DEBUG
    private var activeStorageMode: DebugStorageMode {
      DebugStorageMode(rawValue: storageMode) ?? .local
    }
  #endif

  private static func makeModelContainer(storageMode: DebugStorageMode = DebugStorageMode.current) -> ModelContainer {
    do {
      return try BirthTrackerModelContainer.make(storageMode: storageMode)
    } catch {
      fatalError("Unable to create model container: \(error)")
    }
  }
}
