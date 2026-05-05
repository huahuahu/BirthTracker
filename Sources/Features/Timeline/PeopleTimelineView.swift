import DesignSystem
import Models
import Persistence
import SwiftData
import SwiftUI
import WidgetKit

public struct PeopleTimelineView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \TrackedPerson.name) private var people: [TrackedPerson]
  @AppStorage(AppSettingsKey.enabledCalendarKinds) private var enabledCalendarKinds =
    BirthdayCalendarKind.rawSelectionKinds(
      BirthdayCalendarKind.defaultSelectionKinds)
  @State private var isAddingPerson = false

  private var upcomingBirthdays: [UpcomingBirthday] {
    people
      .compactMap { $0.upcomingBirthday() }
      .sorted { $0.date < $1.date }
  }

  public init() {}

  public var body: some View {
    NavigationStack {
      List {
        if upcomingBirthdays.isEmpty {
          ContentUnavailableView(
            "No Birthdays",
            systemImage: "calendar.badge.plus",
            description: Text("Add a person to start the timeline.")
          )
        } else {
          Section("Upcoming") {
            ForEach(upcomingBirthdays) { birthday in
              BirthdayTimelineRow(birthday: birthday)
            }
          }
        }

        if !people.isEmpty {
          Section("People") {
            ForEach(people) { person in
              VStack(alignment: .leading, spacing: 4) {
                Text(person.name)
                  .font(.headline)
                Text(person.calendarKind.title)
                  .font(.subheadline)
                  .foregroundStyle(.secondary)
              }
            }
            .onDelete(perform: deletePeople)
          }
        }
      }
      .navigationTitle("Birthdays")
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Button("Add Person", systemImage: "plus") {
            isAddingPerson = true
          }
        }

        ToolbarItem(placement: .navigation) {
          NavigationLink {
            SettingsView()
          } label: {
            Label("Settings", systemImage: "gearshape")
          }
        }
      }
      .sheet(isPresented: $isAddingPerson) {
        PersonFormView(calendarKinds: BirthdayCalendarKind.selectionKinds(from: enabledCalendarKinds)) { person in
          modelContext.insert(person)
          try? modelContext.save()
          persistWidgetSnapshot(for: people + [person])
        }
      }
      .onAppear {
        persistWidgetSnapshot()
      }
      .onChange(of: people.map(\.id)) {
        persistWidgetSnapshot()
      }
    }
  }

  private func deletePeople(at offsets: IndexSet) {
    let remainingPeople = people.enumerated()
      .filter { !offsets.contains($0.offset) }
      .map(\.element)

    for index in offsets {
      modelContext.delete(people[index])
    }
    try? modelContext.save()
    persistWidgetSnapshot(for: remainingPeople)
  }

  private func persistWidgetSnapshot(for people: [TrackedPerson]? = nil) {
    let birthdays = (people ?? self.people)
      .compactMap { $0.upcomingBirthday() }
      .sorted { $0.date < $1.date }

    let snapshot = WidgetSnapshot(birthdays: Array(birthdays.prefix(8)))
    guard let url = AppGroup.snapshotURL else { return }

    do {
      let data = try JSONEncoder.birthTracker.encode(snapshot)
      try data.write(to: url, options: [.atomic])
      WidgetCenter.shared.reloadTimelines(ofKind: BirthTrackerWidgetKind.upcomingBirthdays)
    } catch {
      assertionFailure("Unable to persist widget snapshot: \(error)")
    }
  }
}

private struct BirthdayTimelineRow: View {
  let birthday: UpcomingBirthday

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "gift")
        .font(.title2)
        .foregroundStyle(.pink)
        .frame(width: 36, height: 36)

      VStack(alignment: .leading, spacing: 4) {
        Text(birthday.personName)
          .font(.headline)
        Text(birthday.date, format: .dateTime.month(.wide).day().year())
          .foregroundStyle(.secondary)
      }

      Spacer()

      if let age = birthday.age {
        Text("\(age)")
          .font(.headline.monospacedDigit())
          .accessibilityLabel("Turns \(age)")
      }
    }
  }
}

#Preview {
  PeopleTimelineView()
    .modelContainer(for: TrackedPerson.self, inMemory: true)
}
