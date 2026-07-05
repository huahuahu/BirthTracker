import DesignSystem
import Localization
import Models
import SwiftUI

public struct PersonFormView: View {
  @Environment(\.dismiss)
  private var dismiss

  public let mode: PersonFormMode
  public let calendarKinds: [BirthdayCalendarKind]
  public let onSave: (PersonFormState) throws -> Void

  @State private var formState: PersonFormState
  @State private var saveErrorMessage: String?

  public init(
    mode: PersonFormMode = .add,
    calendarKinds: [BirthdayCalendarKind] = BirthdayCalendarKind.defaultSelectionKinds,
    initialState: PersonFormState? = nil,
    onSave: @escaping (PersonFormState) throws -> Void
  ) {
    let calendarKinds = calendarKinds.isEmpty ? BirthdayCalendarKind.defaultSelectionKinds : calendarKinds
    let defaultCalendarKind = calendarKinds.first ?? .gregorian

    self.mode = mode
    self.calendarKinds = calendarKinds
    self.onSave = onSave
    _formState = State(
      initialValue: initialState ?? PersonFormState.blank(defaultCalendarKind: defaultCalendarKind))
  }

  public var body: some View {
    NavigationStack {
      Form {
        Section(L10n.PersonForm.person) {
          TextField(L10n.PersonForm.name, text: $formState.name)
            .textContentType(.name)

          Picker(L10n.PersonForm.relationshipGender, selection: $formState.relationshipGender) {
            ForEach(RelationshipGender.allCases, id: \.self) { gender in
              Text(gender.localizedTitle).tag(gender)
            }
          }

          TextField(L10n.PersonForm.notes, text: $formState.notes, axis: .vertical)
            .lineLimit(2...5)
        }

        Section(L10n.PersonForm.birthday) {
          Picker(L10n.Common.calendar, selection: $formState.calendarKind) {
            ForEach(calendarKinds) { kind in
              Text(kind.localizedTitle).tag(kind)
            }
          }

          Toggle(L10n.PersonForm.knownBirthYear, isOn: $formState.birthYearIsKnown)

          DatePicker(
            L10n.PersonForm.birthDate,
            selection: $formState.birthDate,
            displayedComponents: .date
          )
          .environment(\.calendar, formState.calendarKind.calendar)
        }
      }
      .navigationTitle(navigationTitle)
      .alert(
        L10n.PersonForm.saveFailedTitle,
        isPresented: Binding(
          get: { saveErrorMessage != nil },
          set: { isPresented in
            if !isPresented {
              saveErrorMessage = nil
            }
          }
        )
      ) {
        Button(L10n.Common.ok) {
          saveErrorMessage = nil
        }
      } message: {
        Text(saveErrorMessage ?? "")
      }
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(L10n.Common.cancel) { dismiss() }
        }

        ToolbarItem(placement: .confirmationAction) {
          Button(L10n.Common.save) {
            save()
          }
          .disabled(!formState.canSave)
        }
      }
    }
  }

  private var navigationTitle: LocalizedStringResource {
    switch mode {
    case .add: L10n.PersonForm.addBirthday
    case .edit: L10n.PersonForm.editPerson
    }
  }

  private func save() {
    do {
      try formState.validate()
      try onSave(formState)
      dismiss()
    } catch PersonFormValidationError.emptyName {
      saveErrorMessage = L10n.string(L10n.PersonForm.nameRequired)
    } catch {
      saveErrorMessage = error.localizedDescription
    }
  }
}

#Preview("Add") {
  PersonFormView { _ in }
}

#Preview("Edit") {
  PersonFormView(
    mode: .edit,
    initialState: PersonFormState(
      name: "An An",
      notes: "Likes strawberries.",
      calendarKind: .gregorian,
      birthDate: .now,
      birthYearIsKnown: true,
      relationshipGender: .female)
  ) { _ in }
}
