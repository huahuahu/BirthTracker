import BirthTrackerWidgetIntents
import Foundation
import Testing

@Suite("Widget person selection")
struct WidgetPersonSelectionTests {
  @Test("Selection round trips the person and widget instance IDs")
  func selectionRoundTripsBothIDs() throws {
    let personID = UUID()
    let widgetInstanceID = UUID()
    let rawValue = WidgetPersonSelection(
      personID: personID,
      widgetInstanceID: widgetInstanceID
    ).rawValue

    let selection = try #require(WidgetPersonSelection(rawValue: rawValue))

    #expect(selection.personID == personID)
    #expect(selection.widgetInstanceID == widgetInstanceID)
  }

  @Test("Legacy person ID remains readable without an instance ID")
  func legacyPersonIDRemainsReadable() throws {
    let personID = UUID()
    let selection = try #require(
      WidgetPersonSelection(rawValue: personID.uuidString))

    #expect(selection.personID == personID)
    #expect(selection.widgetInstanceID == nil)
  }

  @Test(
    "Malformed selection is rejected",
    arguments: [
      "",
      "not-a-uuid",
      "\(UUID().uuidString)::not-a-uuid",
      "\(UUID().uuidString)::\(UUID().uuidString)::\(UUID().uuidString)",
    ])
  func malformedSelectionIsRejected(rawValue: String) {
    #expect(WidgetPersonSelection(rawValue: rawValue) == nil)
  }

  @Test("Two contact age widget configurations get different state IDs")
  func widgetConfigurationsGetDifferentStateIDs() throws {
    let personID = UUID()
    let firstInstanceID = UUID()
    let secondInstanceID = UUID()
    let first = SelectPersonIntent(
      personID: personID,
      widgetInstanceID: firstInstanceID)
    let second = SelectPersonIntent(
      personID: personID,
      widgetInstanceID: secondInstanceID)

    #expect(first.selectedPersonID == personID)
    #expect(second.selectedPersonID == personID)
    #expect(first.personID != second.personID)
    #expect(first.widgetInstanceID == firstInstanceID)
    #expect(second.widgetInstanceID == secondInstanceID)
    #expect(first.contactAgeStateID != second.contactAgeStateID)
  }

  @Test("An empty configuration does not invent an unsaved instance ID")
  func emptyConfigurationDoesNotCreateInstanceID() {
    let intent = SelectPersonIntent()

    #expect(intent.widgetInstanceID == nil)
    #expect(intent.contactAgeStateID == nil)
  }

  @Test("Restoring only the saved person selection preserves widget identity")
  func restoringSelectionPreservesIdentity() throws {
    let original = SelectPersonIntent(personID: UUID())
    let expectedStateID = try #require(original.contactAgeStateID)

    for _ in 0..<3 {
      let restored = SelectPersonIntent()
      restored.personID = original.personID

      #expect(restored.widgetInstanceIDValue == nil)
      #expect(restored.contactAgeStateID == expectedStateID)
      #expect(restored.selectedPersonID == original.selectedPersonID)
    }
  }

  @Test("Legacy configuration identity remains stable across restoration")
  func restoringLegacyConfigurationPreservesIdentity() {
    let personID = UUID().uuidString
    let first = SelectPersonIntent()
    first.personID = personID
    let restored = SelectPersonIntent()
    restored.personID = personID

    #expect(first.contactAgeStateID == restored.contactAgeStateID)
    #expect(first.widgetInstanceID == nil)
  }

  @Test("A previously persisted separate instance ID remains readable")
  func separateInstanceIDRemainsReadable() {
    let instanceID = UUID()
    let restored = SelectPersonIntent()
    restored.personID = UUID().uuidString
    restored.widgetInstanceIDValue = instanceID.uuidString

    #expect(restored.widgetInstanceID == instanceID)
    #expect(restored.contactAgeStateID == "instance:v1:\(instanceID.uuidString)")
  }

  @Test("An encoded legacy selection keeps its original instance ID")
  func encodedLegacySelectionKeepsOriginalInstanceID() {
    let personID = UUID()
    let legacyInstanceID = UUID()
    let intent = SelectPersonIntent()
    intent.personID =
      WidgetPersonSelection(
        personID: personID,
        widgetInstanceID: legacyInstanceID
      ).rawValue

    #expect(intent.selectedPersonID == personID)
    #expect(intent.widgetInstanceID == legacyInstanceID)
  }

  @Test("Legacy widget state separates different calendars and formats")
  func legacyWidgetStateSeparatesDifferentConfigurations() throws {
    let personID = UUID()
    let gregorian = SelectPersonIntent()
    gregorian.personID = personID.uuidString
    gregorian.widgetInstanceIDValue = nil
    gregorian.displayCalendar = WidgetDisplayCalendar.gregorian.rawValue
    gregorian.ageDisplayFormat = WidgetAgeDisplayFormat.monthDay.rawValue

    let islamic = SelectPersonIntent()
    islamic.personID = personID.uuidString
    islamic.widgetInstanceIDValue = nil
    islamic.displayCalendar = WidgetDisplayCalendar.islamicUmmAlQura.rawValue
    islamic.ageDisplayFormat = WidgetAgeDisplayFormat.day.rawValue

    #expect(gregorian.contactAgeStateID != islamic.contactAgeStateID)
  }
}
