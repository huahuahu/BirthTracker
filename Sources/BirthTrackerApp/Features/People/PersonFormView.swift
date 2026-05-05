import SwiftUI

struct PersonFormView: View {
  @Environment(\.dismiss) private var dismiss

  let onSave: (TrackedPerson) -> Void

  @State private var name = ""
  @State private var notes = ""
  @State private var calendarKind = BirthdayCalendarKind.gregorian
  @State private var birthDate = Date.now

  var body: some View {
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
            ForEach(BirthdayCalendarKind.allCases) { kind in
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
