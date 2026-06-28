import DesignSystem
import Features
import Persistence
import SwiftData
import SwiftUI

public struct BirthTrackerRootView: View {
  @State private var modelContainer = makeModelContainer()

  public init() {}

  public var body: some View {
    PeopleTimelineView()
      .modelContainer(modelContainer)
  }

  private static func makeModelContainer(storageMode: DebugStorageMode = DebugStorageMode.current) -> ModelContainer {
    do {
      return try BirthTrackerModelContainer.make(storageMode: storageMode)
    } catch {
      fatalError("Unable to create model container: \(error)")
    }
  }
}
