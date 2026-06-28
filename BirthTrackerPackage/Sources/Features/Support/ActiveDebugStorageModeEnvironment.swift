import Persistence
import SwiftUI

#if DEBUG
  private struct ActiveDebugStorageModeKey: EnvironmentKey {
    static let defaultValue: DebugStorageMode = .local
  }

  extension EnvironmentValues {
    public var activeDebugStorageMode: DebugStorageMode {
      get { self[ActiveDebugStorageModeKey.self] }
      set { self[ActiveDebugStorageModeKey.self] = newValue }
    }
  }
#endif
