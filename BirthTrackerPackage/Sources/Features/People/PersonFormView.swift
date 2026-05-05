import DesignSystem
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
        Section("Person") {
          TextField("Name", text: $name)
            .textContentType(.name)
          TextField("Notes", text: $notes, axis: .vertical)
            .lineLimit(2...5)
        }

        Section("Birthday") {
          Picker("Calendar", selection: $calendarKind) {
            ForEach(calendarKinds) { kind in
              Text(kind.title).tag(kind)
            }
          }

          DatePicker("Birth date", selection: $birthDate, displayedComponents: .date)
            .environment(\.calendar, calendarKind.calendar)
        }
      }
      .navigationTitle("Add Birthday")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }

        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
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
