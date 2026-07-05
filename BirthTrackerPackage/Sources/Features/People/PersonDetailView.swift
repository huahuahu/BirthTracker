import DesignSystem
import Localization
import Models
import SFSafeSymbols
import SwiftUI

public struct PersonDetailView: View {
  public let person: TrackedPerson
  public let calendarKinds: [BirthdayCalendarKind]
  public let onSave: (TrackedPerson, PersonFormState) throws -> Void

  @State private var isEditing = false

  public init(
    person: TrackedPerson,
    calendarKinds: [BirthdayCalendarKind] = BirthdayCalendarKind.defaultSelectionKinds,
    onSave: @escaping (TrackedPerson, PersonFormState) throws -> Void
  ) {
    self.person = person
    self.calendarKinds = calendarKinds.isEmpty ? BirthdayCalendarKind.defaultSelectionKinds : calendarKinds
    self.onSave = onSave
  }

  public var body: some View {
    let summary = PersonBirthdaySummary.make(for: person)

    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        header
        metricGrid(summary: summary)
        widgetPreview(summary: summary)
        notesSection
      }
      .padding()
    }
    .background(.groupedBackground)
    .navigationTitle(L10n.PersonDetail.contactDetails)
    .platformNavigationBarTitleDisplayModeInline()
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button(L10n.PersonDetail.edit) {
          isEditing = true
        }
      }
    }
    .sheet(isPresented: $isEditing) {
      PersonFormView(
        mode: .edit,
        calendarKinds: calendarKinds,
        initialState: PersonFormState(person: person)
      ) { state in
        try onSave(person, state)
      }
    }
  }

  private var header: some View {
    HStack(alignment: .center, spacing: 14) {
      ZStack {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
          .fill(.pink.gradient)
        Text(person.name.prefix(1).uppercased())
          .font(.title.bold())
          .foregroundStyle(.white)
      }
      .frame(width: 68, height: 68)

      VStack(alignment: .leading, spacing: 8) {
        Text(person.name)
          .font(.largeTitle.bold())
          .lineLimit(2)
          .minimumScaleFactor(0.75)

        HStack(spacing: 8) {
          Label {
            Text(person.calendarKind.localizedTitle)
          } icon: {
            Image(systemSymbol: .calendar)
          }

          Label {
            Text(person.relationshipGender.localizedTitle)
          } icon: {
            Image(systemSymbol: .person)
          }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(.background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
  }

  private func metricGrid(summary: PersonBirthdaySummary) -> some View {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
      if let duration = summary.birthDuration {
        PersonMetricCard(
          title: L10n.PersonDetail.bornFor,
          value: L10n.PersonDetail.birthDuration(duration.years, duration.months, duration.days),
          symbol: .clock)
      }

      if let days = summary.daysUntilNextBirthday {
        PersonMetricCard(
          title: L10n.PersonDetail.daysUntilBirthday,
          value: L10n.PersonDetail.daysUntilBirthday(days),
          symbol: .calendarBadgeClock)
      }

      if let birthDate = summary.birthDate {
        PersonMetricCard(
          title: L10n.PersonDetail.birthDate,
          value: birthDate.formatted(.dateTime.year().month(.wide).day()),
          symbol: .birthdayCake)
      } else if person.birthday == nil {
        PersonMetricCard(
          title: L10n.PersonDetail.birthDate,
          value: L10n.string(L10n.PersonDetail.noBirthday),
          symbol: .calendarBadgeExclamationmark)
      }

      if let age = summary.nextAge {
        PersonMetricCard(
          title: L10n.PersonDetail.nextAge,
          value: L10n.PersonDetail.nextAge(age),
          symbol: .number)
      }
    }
  }

  private func widgetPreview(summary: PersonBirthdaySummary) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Label {
        Text(L10n.PersonDetail.widgetPreview)
      } icon: {
        Image(systemSymbol: .appsIphone)
      }
      .font(.headline)

      if let duration = summary.birthDuration {
        Text(L10n.PersonDetail.birthDuration(duration.years, duration.months, duration.days))
          .font(.title3.bold())
          .monospacedDigit()
        if let days = summary.daysUntilNextBirthday {
          Text(L10n.PersonDetail.daysUntilBirthday(days))
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      } else {
        Text(person.calendarKind.localizedTitle)
          .font(.title3.bold())
        Text(L10n.PersonDetail.noBirthday)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .foregroundStyle(.white)
    .background(.black, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
  }

  private var notesSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(L10n.PersonDetail.notes)
        .font(.headline)
      Text(person.notes.isEmpty ? L10n.string(L10n.PersonDetail.noNotes) : person.notes)
        .foregroundStyle(person.notes.isEmpty ? .secondary : .primary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(.background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
  }
}

private struct PersonMetricCard: View {
  let title: LocalizedStringResource
  let value: String
  let symbol: SFSymbol

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Image(systemSymbol: symbol)
        .font(.title3)
        .foregroundStyle(.pink)
      Text(value)
        .font(.headline.monospacedDigit())
        .lineLimit(2)
        .minimumScaleFactor(0.75)
      Text(title)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
    .padding()
    .background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
  }
}

extension ShapeStyle where Self == Color {
  fileprivate static var groupedBackground: Color {
    #if os(iOS)
      Color(.systemGroupedBackground)
    #else
      Color(nsColor: .windowBackgroundColor)
    #endif
  }
}

extension View {
  @ViewBuilder
  fileprivate func platformNavigationBarTitleDisplayModeInline() -> some View {
    #if os(iOS)
      navigationBarTitleDisplayMode(.inline)
    #else
      self
    #endif
  }
}

#Preview {
  NavigationStack {
    PersonDetailView(
      person: TrackedPerson(
        name: "An An",
        birthday: Birthday(calendarKind: .gregorian, year: 2024, month: 7, day: 5),
        notes: "Likes strawberries.",
        relationshipGender: .female)
    ) { _, _ in }
  }
}
