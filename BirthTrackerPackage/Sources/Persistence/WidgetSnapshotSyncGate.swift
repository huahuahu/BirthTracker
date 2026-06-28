public enum WidgetSnapshotSyncGate {
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
