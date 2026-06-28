import DesignSystem
import Features
import Persistence
import SwiftData
import SwiftUI

public struct BirthTrackerRootView: View {
  #if DEBUG
    private static let debugStartupStorageMode = DebugStorageMode.current

    @State private var activeDebugStorageMode: DebugStorageMode
  #endif
  @State private var modelContainer: ModelContainer

  public init() {
    #if DEBUG
      _activeDebugStorageMode = State(initialValue: Self.debugStartupStorageMode)
      _modelContainer = State(initialValue: Self.makeModelContainer(storageMode: Self.debugStartupStorageMode))
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
