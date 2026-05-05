import SwiftData
import SwiftUI

@main
struct BirthTrackerApp: App {
  private let modelContainer: ModelContainer

  init() {
    do {
      modelContainer = try BirthTrackerModelContainer.make()
    } catch {
      fatalError("Unable to create model container: \(error)")
    }
  }

  var body: some Scene {
    WindowGroup {
      PeopleTimelineView()
    }
    .modelContainer(modelContainer)
  }
}
