public enum WidgetSnapshotSyncGate {
  public static func runWhenNoPendingChanges(
    hasPendingChanges: Bool,
    sync: () -> Void,
    reportPendingChanges: () -> Void = {
      assertionFailure("Skipping widget snapshot sync because model context has unsaved changes.")
    }
  ) {
    guard !hasPendingChanges else {
      reportPendingChanges()
      return
    }

    sync()
  }

  public static func runAfterSuccessfulSave(
    save: () throws -> Void,
    sync: () -> Void,
    reportFailure: (Error) -> Void = { error in
      assertionFailure("Unable to save changes before syncing widget snapshots: \(error)")
    }
  ) {
    do {
      try save()
      sync()
    } catch {
      reportFailure(error)
    }
  }
}
