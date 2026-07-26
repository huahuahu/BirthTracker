import Persistence
import SwiftUI

struct ContactAgeFormatIndicator: View {
  let displayFormat: ContactAgeDisplayFormat

  var body: some View {
    HStack(spacing: 4) {
      ForEach(ContactAgeDisplayFormat.allCases, id: \.rawValue) { format in
        Circle()
          .fill(format == displayFormat ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
          .frame(width: 5, height: 5)
      }
    }
    .accessibilityHidden(true)
  }
}
