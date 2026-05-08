import DesignSystem
import Localization
import Models
import SwiftUI

public struct PersonFormView: View {
  @Environment(\.dismiss) private var dismiss

  public let calendarKinds: [BirthdayCalendarKind]
  public let onSave: (TrackedPerson) -> Void

  @State private var name = ""
  @State private var notes = ""
  @State private var calendarKind: BirthdayCalendarKind
  @State private var birthDate = Date.now

  public init(
    calendarKinds: [BirthdayCalendarKind] = BirthdayCalendarKind.defaultSelectionKinds,
    onSave: @escaping (TrackedPerson) -> Void
  ) {
    let calendarKinds = calendarKinds.isEmpty ? BirthdayCalendarKind.defaultSelectionKinds : calendarKinds

    self.calendarKinds = calendarKinds
    self.onSave = onSave
    _calendarKind = State(initialValue: calendarKinds.first ?? .gregorian)
  }

  public var body: some View {
    NavigationStack {
      Form {
        Section(L10n.PersonForm.person) {
          TextField(L10n.PersonForm.name, text: $name)
            .textContentType(.name)
          TextField(L10n.PersonForm.notes, text: $notes, axis: .vertical)
            .lineLimit(2...5)
        }

        Section(L10n.PersonForm.birthday) {
          Picker(L10n.Common.calendar, selection: $calendarKind) {
            ForEach(calendarKinds) { kind in
              Text(kind.localizedTitle).tag(kind)
            }
          }

          DatePicker(
            L10n.PersonForm.birthDate, selection: $birthDate, displayedComponents: .date
          )
          .environment(\.calendar, calendarKind.calendar)
        }
      }
      .navigationTitle(L10n.PersonForm.addBirthday)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(L10n.Common.cancel) { dismiss() }
        }

        ToolbarItem(placement: .confirmationAction) {
          Button(L10n.Common.save) {
            let person = TrackedPerson(
              name: name.trimmingCharacters(in: .whitespacesAndNewlines),
              birthday: Birthday(date: birthDate, calendarKind: calendarKind),
              notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            onSave(person)
            dismiss()
          }
          .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
    }
  }
}

#Preview {
  PersonFormView { _ in }
}
