import Foundation
import Testing

@testable import Models

@Suite("Relationship resolver")
struct RelationshipResolverTests {
  @Test("Direct family and social relationships resolve from the current perspective")
  func directFamilyAndSocialRelationshipsResolveFromCurrentPerspective() throws {
    let childID = id(1)
    let fatherID = id(2)
    let motherID = id(3)
    let spouseID = id(4)
    let olderSisterID = id(5)
    let friendID = id(6)
    let people = [
      person(childID, birthday: birthday(1995, 6, 10), gender: .male),
      person(fatherID, birthday: birthday(1965, 1, 1), gender: .male),
      person(motherID, birthday: birthday(1968, 2, 2), gender: .female),
      person(spouseID, birthday: birthday(1994, 3, 3), gender: .female),
      person(olderSisterID, birthday: birthday(1990, 4, 4), gender: .female),
      person(friendID, gender: .unknown),
    ]
    let facts = [
      fact(id: id(101), personAID: fatherID, personBID: childID, kind: .parentChild, aRole: .parent, bRole: .child),
      fact(id: id(102), personAID: motherID, personBID: childID, kind: .parentChild, aRole: .parent, bRole: .child),
      fact(id: id(103), personAID: spouseID, personBID: childID, kind: .spouse, aRole: .spouse, bRole: .spouse),
      fact(id: id(104), personAID: olderSisterID, personBID: childID, kind: .sibling, aRole: .sibling, bRole: .sibling),
      fact(id: id(105), personAID: friendID, personBID: childID, kind: .friend, aRole: .friend, bRole: .friend),
    ]

    let resolutions = RelationshipResolver.resolve(people: people, facts: facts, perspectivePersonID: childID)
    let fromFather = RelationshipResolver.resolve(people: people, facts: facts, perspectivePersonID: fatherID)

    #expect(resolution(fatherID, in: resolutions).primaryLabel == "父亲")
    #expect(resolution(motherID, in: resolutions).primaryLabel == "母亲")
    #expect(resolution(spouseID, in: resolutions).primaryLabel == "妻子")
    #expect(resolution(olderSisterID, in: resolutions).primaryLabel == "姐姐")
    #expect(resolution(friendID, in: resolutions).primaryLabel == "朋友")
    #expect(resolution(childID, in: fromFather).primaryLabel == "儿子")
  }

  @Test("Primary display fact wins over direct kinship for that direction only")
  func primaryDisplayFactWinsOverDirectKinshipForThatDirectionOnly() throws {
    let personAID = id(1)
    let personBID = id(2)
    let people = [
      person(personAID, gender: .male),
      person(personBID, gender: .female),
    ]
    let siblingFact = fact(
      id: id(201),
      personAID: personAID,
      personBID: personBID,
      kind: .sibling,
      aRole: .sibling,
      bRole: .sibling,
      isPrimaryFromA: false,
      isPrimaryFromB: true)
    let classmateFact = fact(
      id: id(202),
      personAID: personAID,
      personBID: personBID,
      kind: .classmate,
      aRole: .classmate,
      bRole: .classmate,
      isPrimaryFromA: true,
      isPrimaryFromB: false)

    let fromA = RelationshipResolver.resolve(
      people: people,
      facts: [siblingFact, classmateFact],
      perspectivePersonID: personAID)
    let fromB = RelationshipResolver.resolve(
      people: people,
      facts: [siblingFact, classmateFact],
      perspectivePersonID: personBID)

    #expect(resolution(personBID, in: fromA).primaryLabel == "同学")
    #expect(resolution(personBID, in: fromA).additionalLabels.contains("兄弟姐妹"))
    #expect(resolution(personAID, in: fromB).primaryLabel == "兄弟姐妹")
    #expect(resolution(personAID, in: fromB).additionalLabels.contains("同学"))
  }

  @Test("Multiple primary facts choose the earliest stable fact and mark conflict")
  func multiplePrimaryFactsChooseEarliestStableFactAndMarkConflict() throws {
    let currentID = id(1)
    let targetID = id(2)
    let people = [
      person(currentID, gender: .male),
      person(targetID, gender: .female),
    ]
    let laterFriendFact = fact(
      id: id(302),
      personAID: currentID,
      personBID: targetID,
      kind: .friend,
      aRole: .friend,
      bRole: .friend,
      isPrimaryFromA: true,
      createdAt: Date(timeIntervalSince1970: 200))
    let earlierClassmateFact = fact(
      id: id(301),
      personAID: currentID,
      personBID: targetID,
      kind: .classmate,
      aRole: .classmate,
      bRole: .classmate,
      isPrimaryFromA: true,
      createdAt: Date(timeIntervalSince1970: 100))

    let resolutions = RelationshipResolver.resolve(
      people: people,
      facts: [laterFriendFact, earlierClassmateFact],
      perspectivePersonID: currentID)
    let targetResolution = resolution(targetID, in: resolutions)

    #expect(targetResolution.primaryLabel == "同学")
    #expect(targetResolution.additionalLabels == ["朋友"])
    #expect(targetResolution.diagnostics == [.conflict])
    #expect(targetResolution.hasConflict)
  }

  @Test("Direct kinship wins over earlier social fact when no primary is set")
  func directKinshipWinsOverEarlierSocialFactWhenNoPrimaryIsSet() throws {
    let currentID = id(1)
    let targetID = id(2)
    let people = [
      person(currentID, gender: .male),
      person(targetID, gender: .female),
    ]
    let earlierFriendFact = fact(
      id: id(401),
      personAID: currentID,
      personBID: targetID,
      kind: .friend,
      aRole: .friend,
      bRole: .friend,
      createdAt: Date(timeIntervalSince1970: 100))
    let laterSpouseFact = fact(
      id: id(402),
      personAID: currentID,
      personBID: targetID,
      kind: .spouse,
      aRole: .spouse,
      bRole: .spouse,
      createdAt: Date(timeIntervalSince1970: 200))

    let resolutions = RelationshipResolver.resolve(
      people: people,
      facts: [earlierFriendFact, laterSpouseFact],
      perspectivePersonID: currentID)
    let targetResolution = resolution(targetID, in: resolutions)

    #expect(targetResolution.primaryLabel == "妻子")
    #expect(targetResolution.additionalLabels == ["朋友"])
  }

  @Test("Known people without direct labels remain sorted by UUID")
  func knownPeopleWithoutDirectLabelsRemainSortedByUUID() throws {
    let currentID = id(1)
    let secondID = id(2)
    let firstID = id(3)
    let people = [
      person(firstID),
      person(currentID),
      person(secondID),
    ]

    let resolutions = RelationshipResolver.resolve(people: people, facts: [], perspectivePersonID: currentID)

    #expect(resolutions.map(\.targetPersonID) == [secondID, firstID])
    #expect(resolutions.map(\.primaryLabel) == [nil, nil])
  }

  @Test("Facts with one missing endpoint mark the known target without labels")
  func factsWithOneMissingEndpointMarkKnownTargetWithoutLabels() throws {
    let currentID = id(1)
    let targetID = id(2)
    let missingID = id(999)
    let people = [
      person(currentID),
      person(targetID),
    ]
    let facts = [
      fact(id: id(301), personAID: missingID, personBID: targetID, kind: .friend, aRole: .friend, bRole: .friend)
    ]

    let resolutions = RelationshipResolver.resolve(people: people, facts: facts, perspectivePersonID: currentID)
    let targetResolution = resolution(targetID, in: resolutions)

    #expect(targetResolution.primaryLabel == nil)
    #expect(targetResolution.additionalLabels.isEmpty)
    #expect(targetResolution.diagnostics == [.missingEndpoint])
    #expect(targetResolution.hasMissingEndpoint)
  }
}

private func id(_ value: Int) -> UUID {
  guard let uuid = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value)) else {
    preconditionFailure("Invalid deterministic UUID fixture")
  }
  return uuid
}

private func birthday(_ year: Int, _ month: Int = 1, _ day: Int = 1) -> RelationshipBirthday {
  RelationshipBirthday(calendarKind: .gregorian, year: year, month: month, day: day)
}

private func person(
  _ id: UUID,
  birthday: RelationshipBirthday? = nil,
  gender: RelationshipGender = .unknown
) -> RelationshipPersonInput {
  RelationshipPersonInput(id: id, birthday: birthday, relationshipGender: gender)
}

private func fact(
  id: UUID,
  personAID: UUID,
  personBID: UUID,
  kind: RelationshipKind,
  aRole: RelationshipRole,
  bRole: RelationshipRole,
  isPrimaryFromA: Bool = false,
  isPrimaryFromB: Bool = false,
  createdAt: Date = Date()
) -> RelationshipFact {
  RelationshipFact(
    id: id,
    personAID: personAID,
    personBID: personBID,
    kind: kind,
    personARole: aRole,
    personBRole: bRole,
    isPrimaryFromPersonA: isPrimaryFromA,
    isPrimaryFromPersonB: isPrimaryFromB,
    createdAt: createdAt,
    updatedAt: createdAt)
}

private func resolution(_ id: UUID, in resolutions: [RelationshipResolution]) -> RelationshipResolution {
  guard let resolution = resolutions.first(where: { $0.targetPersonID == id }) else {
    Issue.record("Missing relationship resolution for \(id)")
    return RelationshipResolution(targetPersonID: id)
  }
  return resolution
}
