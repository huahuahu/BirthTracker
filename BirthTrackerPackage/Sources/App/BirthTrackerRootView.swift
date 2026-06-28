import DesignSystem
import Features
import Persistence
import SwiftData
import SwiftUI

public struct BirthTrackerRootView: View {
  #if DEBUG
    @State private var activeDebugStorageMode: DebugStorageMode
  #endif
  @State private var modelContainer: ModelContainer

  public init() {
    #if DEBUG
      let startupStorageMode = DebugStorageMode.current
      _activeDebugStorageMode = State(initialValue: startupStorageMode)
      _modelContainer = State(initialValue: Self.makeModelContainer(storageMode: startupStorageMode))
    #else
      _modelContainer = State(initialValue: Self.makeModelContainer())
    #endif
  }

  public var body: some View {
    PeopleTimelineView()
      .modelContainer(modelContainer)
      #if DEBUG
        .environment(\.activeDebugStorageMode, activeDebugStorageMode)
      #endif
  }

  private static func makeModelContainer(storageMode: DebugStorageMode = DebugStorageMode.current) -> ModelContainer {
    do {
      return try BirthTrackerModelContainer.make(storageMode: storageMode)
    } catch {
      fatalError("Unable to create model container: \(error)")
    }
  }
}
