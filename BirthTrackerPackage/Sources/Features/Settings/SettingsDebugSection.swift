import Localization
import SwiftUI

#if DEBUG
  struct SettingsDebugView: View {
    var body: some View {
      Form {
        SettingsDebugSection()
      }
      .navigationTitle(L10n.Settings.debug)
    }
  }

  struct SettingsDebugSection: View {
    var body: some View {
      DebugStorageSection()
    }
  }
#endif
