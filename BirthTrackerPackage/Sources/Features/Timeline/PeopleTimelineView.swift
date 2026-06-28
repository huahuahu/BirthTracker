import DesignSystem
import Localization
import Models
import Persistence
import SwiftData
import SwiftUI
import WidgetKit

public struct PeopleTimelineView: View {
  @Environment(\.modelContext)
  private var modelContext
  @Query(sort: \TrackedPerson.name)
  private var people: [TrackedPerson]
  @AppStorage(AppSettingsKey.enabledCalendarKinds)
  private var enabledCalendarKinds =
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
            L10n.Timeline.noBirthdays,
            systemImage: "calendar.badge.plus",
            description: Text(L10n.Timeline.emptyDescription)
          )
        } else {
          Section(L10n.Timeline.upcoming) {
            ForEach(upcomingBirthdays) { birthday in
              BirthdayTimelineRow(birthday: birthday)
            }
          }
        }

        if !people.isEmpty {
          Section(L10n.Timeline.people) {
            ForEach(people) { person in
              VStack(alignment: .leading, spacing: 4) {
                Text(person.name)
                  .font(.headline)
                Text(person.calendarKind.localizedTitle)
                  .font(.subheadline)
                  .foregroundStyle(.secondary)
              }
            }
            .onDelete(perform: deletePeople)
          }
        }
      }
      .navigationTitle(L10n.Common.birthdays)
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Button(L10n.Timeline.addPerson, systemImage: "plus") {
            isAddingPerson = true
          }
        }

        ToolbarItem(placement: .navigation) {
          NavigationLink {
            SettingsView()
          } label: {
            Label(L10n.Common.settings, systemImage: "gearshape")
          }
        }
      }
      .sheet(isPresented: $isAddingPerson) {
        PersonFormView(calendarKinds: BirthdayCalendarKind.selectionKinds(from: enabledCalendarKinds)) { person in
          modelContext.insert(person)
          WidgetSnapshotSyncGate.runAfterSuccessfulSave(
            save: {
              try modelContext.save()
            },
            sync: {
              persistWidgetSnapshots(for: people + [person])
            })
        }
      }
      .onAppear {
        persistWidgetSnapshots()
      }
      .onChange(of: people.map(\.id)) {
        WidgetSnapshotSyncGate.runWhenNoPendingChanges(
          hasPendingChanges: modelContext.hasChanges,
          sync: {
            persistWidgetSnapshots()
          })
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
    WidgetSnapshotSyncGate.runAfterSuccessfulSave(
      save: {
        try modelContext.save()
      },
      sync: {
        persistWidgetSnapshots(for: remainingPeople)
      })
  }

  private func persistWidgetSnapshots(for people: [TrackedPerson]? = nil) {
    let snapshots = WidgetSnapshotBuilder.makeSnapshots(from: people ?? self.people)

    do {
      try WidgetSnapshotStore.rebuild(with: snapshots)
      WidgetCenter.shared.reloadTimelines(ofKind: BirthTrackerWidgetKind.upcomingBirthdays)
    } catch {
      assertionFailure("Unable to persist widget snapshots: \(error)")
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
        let ageLabel = L10n.Timeline.ageAccessibilityLabel(age)

        Text("\(age)")
          .font(.headline.monospacedDigit())
          .accessibilityLabel(Text(ageLabel))
      }
    }
  }
}

#Preview {
  PeopleTimelineView()
    .modelContainer(for: TrackedPerson.self, inMemory: true)
}
