import Foundation
import Testing

@testable import Models

// swiftlint:disable file_length

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

  @Test("Sibling facts share known parents and enable three generation inference")
  func siblingFactsShareKnownParentsAndEnableThreeGenerationInference() throws {
    let childID = id(1)
    let fatherID = id(2)
    let motherID = id(3)
    let paternalGrandfatherID = id(4)
    let paternalGrandmotherID = id(5)
    let maternalGrandfatherID = id(6)
    let maternalGrandmotherID = id(7)
    let uncleID = id(8)
    let auntID = id(9)
    let cousinID = id(10)
    let siblingID = id(11)
    let nephewID = id(12)
    let grandchildID = id(13)
    let daughterID = id(14)

    let people = [
      person(childID, birthday: birthday(1995), gender: .male),
      person(fatherID, birthday: birthday(1965), gender: .male),
      person(motherID, birthday: birthday(1968), gender: .female),
      person(paternalGrandfatherID, gender: .male),
      person(paternalGrandmotherID, gender: .female),
      person(maternalGrandfatherID, gender: .male),
      person(maternalGrandmotherID, gender: .female),
      person(uncleID, gender: .male),
      person(auntID, gender: .female),
      person(cousinID, birthday: birthday(1992), gender: .female),
      person(siblingID, gender: .male),
      person(nephewID, gender: .male),
      person(grandchildID, gender: .female),
      person(daughterID, gender: .female),
    ]
    let facts = [
      fact(id: id(301), a: fatherID, b: childID, kind: .parentChild, aRole: .parent, bRole: .child),
      fact(id: id(302), a: motherID, b: childID, kind: .parentChild, aRole: .parent, bRole: .child),
      fact(id: id(303), a: paternalGrandfatherID, b: fatherID, kind: .parentChild, aRole: .parent, bRole: .child),
      fact(id: id(304), a: paternalGrandmotherID, b: fatherID, kind: .parentChild, aRole: .parent, bRole: .child),
      fact(id: id(305), a: maternalGrandfatherID, b: motherID, kind: .parentChild, aRole: .parent, bRole: .child),
      fact(id: id(306), a: maternalGrandmotherID, b: motherID, kind: .parentChild, aRole: .parent, bRole: .child),
      fact(id: id(307), a: fatherID, b: uncleID, kind: .sibling, aRole: .sibling, bRole: .sibling),
      fact(id: id(308), a: motherID, b: auntID, kind: .sibling, aRole: .sibling, bRole: .sibling),
      fact(id: id(309), a: uncleID, b: cousinID, kind: .parentChild, aRole: .parent, bRole: .child),
      fact(id: id(310), a: siblingID, b: childID, kind: .sibling, aRole: .sibling, bRole: .sibling),
      fact(id: id(311), a: siblingID, b: nephewID, kind: .parentChild, aRole: .parent, bRole: .child),
      fact(id: id(312), a: childID, b: daughterID, kind: .parentChild, aRole: .parent, bRole: .child),
      fact(id: id(313), a: daughterID, b: grandchildID, kind: .parentChild, aRole: .parent, bRole: .child),
    ]

    let resolutions = RelationshipResolver.resolve(people: people, facts: facts, perspectivePersonID: childID)

    #expect(resolution(paternalGrandfatherID, in: resolutions).primaryLabel == "爷爷")
    #expect(resolution(paternalGrandmotherID, in: resolutions).primaryLabel == "奶奶")
    #expect(resolution(maternalGrandfatherID, in: resolutions).primaryLabel == "外公")
    #expect(resolution(maternalGrandmotherID, in: resolutions).primaryLabel == "外婆")
    #expect(resolution(uncleID, in: resolutions).primaryLabel == "叔伯")
    #expect(resolution(auntID, in: resolutions).primaryLabel == "姨妈")
    #expect(resolution(cousinID, in: resolutions).primaryLabel == "堂姐")
    #expect(resolution(nephewID, in: resolutions).primaryLabel == "侄子")
    #expect(resolution(grandchildID, in: resolutions).primaryLabel == "外孙女")
    #expect(
      resolution(paternalGrandfatherID, in: resolutions).inferencePaths == [
        .inferred(kind: .grandparent, viaPersonIDs: [fatherID])
      ])
    #expect(
      resolution(uncleID, in: resolutions).inferencePaths == [
        .inferred(kind: .parentSibling, viaPersonIDs: [fatherID])
      ])
    #expect(
      resolution(nephewID, in: resolutions).inferencePaths == [
        .inferred(kind: .siblingChild, viaPersonIDs: [siblingID])
      ])
    #expect(
      resolution(cousinID, in: resolutions).inferencePaths == [
        .inferred(kind: .cousin, viaPersonIDs: [fatherID, uncleID])
      ])
    #expect(
      resolution(grandchildID, in: resolutions).inferencePaths == [
        .inferred(kind: .grandchild, viaPersonIDs: [daughterID])
      ])
  }

  @Test("Unknown gender and missing birthdays fall back to neutral kinship labels")
  func unknownGenderAndMissingBirthdaysFallBackToNeutralKinshipLabels() throws {
    let childID = id(1)
    let parentID = id(2)
    let grandparentID = id(3)
    let siblingID = id(4)
    let cousinID = id(5)
    let people = [
      person(childID),
      person(parentID),
      person(grandparentID),
      person(siblingID),
      person(cousinID),
    ]
    let facts = [
      fact(id: id(401), a: parentID, b: childID, kind: .parentChild, aRole: .parent, bRole: .child),
      fact(id: id(402), a: grandparentID, b: parentID, kind: .parentChild, aRole: .parent, bRole: .child),
      fact(id: id(403), a: parentID, b: siblingID, kind: .sibling, aRole: .sibling, bRole: .sibling),
      fact(id: id(404), a: siblingID, b: cousinID, kind: .parentChild, aRole: .parent, bRole: .child),
    ]

    let resolutions = RelationshipResolver.resolve(people: people, facts: facts, perspectivePersonID: childID)

    #expect(resolution(grandparentID, in: resolutions).primaryLabel == "祖父母")
    #expect(resolution(siblingID, in: resolutions).primaryLabel == "叔伯姑姨")
    #expect(resolution(cousinID, in: resolutions).primaryLabel == "堂表亲")
  }
}

extension RelationshipResolverTests {
  @Test("Direct child label stays primary when perspective also has known parents")
  func directChildLabelStaysPrimaryWhenPerspectiveAlsoHasKnownParents() throws {
    let currentID = id(1)
    let parentID = id(2)
    let childID = id(3)
    let people = [
      person(currentID),
      person(parentID),
      person(childID, gender: .female),
    ]
    let facts = [
      fact(id: id(501), a: parentID, b: currentID, kind: .parentChild, aRole: .parent, bRole: .child),
      fact(id: id(502), a: currentID, b: childID, kind: .parentChild, aRole: .parent, bRole: .child),
    ]

    let resolutions = RelationshipResolver.resolve(people: people, facts: facts, perspectivePersonID: currentID)

    #expect(resolution(childID, in: resolutions).primaryLabel == "女儿")
    #expect(resolution(childID, in: resolutions).additionalLabels.contains("孙女") == false)
  }

  @Test("Cousin label falls back when lineage gender is unknown even with birthdays")
  func cousinLabelFallsBackWhenLineageGenderIsUnknownEvenWithBirthdays() throws {
    let currentID = id(1)
    let parentID = id(2)
    let parentSiblingID = id(3)
    let cousinID = id(4)
    let people = [
      person(currentID, birthday: birthday(1995)),
      person(parentID),
      person(parentSiblingID, gender: .male),
      person(cousinID, birthday: birthday(1990), gender: .female),
    ]
    let facts = [
      fact(id: id(601), a: parentID, b: currentID, kind: .parentChild, aRole: .parent, bRole: .child),
      fact(id: id(602), a: parentID, b: parentSiblingID, kind: .sibling, aRole: .sibling, bRole: .sibling),
      fact(id: id(603), a: parentSiblingID, b: cousinID, kind: .parentChild, aRole: .parent, bRole: .child),
    ]

    let resolutions = RelationshipResolver.resolve(people: people, facts: facts, perspectivePersonID: currentID)

    #expect(resolution(cousinID, in: resolutions).primaryLabel == "堂表亲")
  }
}

extension RelationshipResolverTests {
  @Test("Duplicate facts do not duplicate labels")
  func duplicateFactsDoNotDuplicateLabels() throws {
    let perspectiveID = id(1)
    let friendID = id(2)
    let people = [person(perspectiveID), person(friendID)]
    let duplicateA = fact(
      id: id(501),
      a: perspectiveID,
      b: friendID,
      kind: .friend,
      aRole: .friend,
      bRole: .friend)
    let duplicateB = fact(
      id: id(502),
      a: perspectiveID,
      b: friendID,
      kind: .friend,
      aRole: .friend,
      bRole: .friend)

    let result = resolution(
      friendID,
      in: RelationshipResolver.resolve(
        people: people,
        facts: [duplicateA, duplicateB],
        perspectivePersonID: perspectiveID))

    #expect(result.primaryLabel == "朋友")
    #expect(result.additionalLabels.isEmpty)
    #expect(result.inferencePaths.count == 1)
  }

  @Test("Duplicate facts merge directional primary preferences")
  func duplicateFactsMergeDirectionalPrimaryPreferences() throws {
    let perspectiveID = id(1)
    let classmateID = id(2)
    let people = [person(perspectiveID), person(classmateID)]
    let duplicateWithoutPrimary = fact(
      id: id(511),
      a: perspectiveID,
      b: classmateID,
      kind: .classmate,
      aRole: .classmate,
      bRole: .classmate,
      createdAt: Date(timeIntervalSince1970: 100))
    let duplicateWithPrimary = fact(
      id: id(512),
      a: perspectiveID,
      b: classmateID,
      kind: .classmate,
      aRole: .classmate,
      bRole: .classmate,
      isPrimaryFromA: true,
      createdAt: Date(timeIntervalSince1970: 200))

    let result = resolution(
      classmateID,
      in: RelationshipResolver.resolve(
        people: people,
        facts: [duplicateWithoutPrimary, duplicateWithPrimary],
        perspectivePersonID: perspectiveID))

    #expect(result.primaryLabel == "同学")
    #expect(
      result.inferencePaths == [
        .primaryPreference(factID: id(512)),
        .social(factID: id(511), kind: .classmate),
      ])
  }

  @Test("Reversed duplicate facts merge primary preferences by person")
  func reversedDuplicateFactsMergePrimaryPreferencesByPerson() throws {
    let perspectiveID = id(1)
    let classmateID = id(2)
    let people = [person(perspectiveID), person(classmateID)]
    let canonicalDuplicate = fact(
      id: id(513),
      a: perspectiveID,
      b: classmateID,
      kind: .classmate,
      aRole: .classmate,
      bRole: .classmate,
      createdAt: Date(timeIntervalSince1970: 100))
    let reversedDuplicateWithPrimary = fact(
      id: id(514),
      a: classmateID,
      b: perspectiveID,
      kind: .classmate,
      aRole: .classmate,
      bRole: .classmate,
      isPrimaryFromB: true,
      createdAt: Date(timeIntervalSince1970: 200))

    let fromPerspective = resolution(
      classmateID,
      in: RelationshipResolver.resolve(
        people: people,
        facts: [canonicalDuplicate, reversedDuplicateWithPrimary],
        perspectivePersonID: perspectiveID))
    let fromClassmate = resolution(
      perspectiveID,
      in: RelationshipResolver.resolve(
        people: people,
        facts: [canonicalDuplicate, reversedDuplicateWithPrimary],
        perspectivePersonID: classmateID))

    #expect(
      fromPerspective.inferencePaths == [
        .primaryPreference(factID: id(514)),
        .social(factID: id(513), kind: .classmate),
      ])
    #expect(
      fromClassmate.inferencePaths == [
        .social(factID: id(513), kind: .classmate)
      ])
  }

  @Test("Sibling graph produces first order inferred family labels")
  func siblingGraphProducesFirstOrderInferredFamilyLabels() throws {
    let parentID = id(1)
    let olderChildID = id(2)
    let middleChildID = id(3)
    let youngerChildID = id(4)
    let people = [
      person(parentID, gender: .female),
      person(olderChildID, birthday: birthday(1990), gender: .male),
      person(middleChildID, birthday: birthday(1993), gender: .female),
      person(youngerChildID, birthday: birthday(1996), gender: .male),
    ]
    let facts = [
      fact(id: id(521), a: parentID, b: olderChildID, kind: .parentChild, aRole: .parent, bRole: .child),
      fact(id: id(522), a: olderChildID, b: middleChildID, kind: .sibling, aRole: .sibling, bRole: .sibling),
      fact(id: id(523), a: middleChildID, b: youngerChildID, kind: .sibling, aRole: .sibling, bRole: .sibling),
    ]

    let fromOlderChild = RelationshipResolver.resolve(
      people: people,
      facts: facts,
      perspectivePersonID: olderChildID)
    let fromMiddleChild = RelationshipResolver.resolve(
      people: people,
      facts: facts,
      perspectivePersonID: middleChildID)
    let fromParent = RelationshipResolver.resolve(
      people: people,
      facts: facts,
      perspectivePersonID: parentID)

    #expect(resolution(youngerChildID, in: fromOlderChild).primaryLabel == "弟弟")
    #expect(
      resolution(youngerChildID, in: fromOlderChild).inferencePaths.contains(
        .inferred(kind: .sibling, viaPersonIDs: [middleChildID])))
    #expect(resolution(parentID, in: fromMiddleChild).primaryLabel == "母亲")
    #expect(
      resolution(parentID, in: fromMiddleChild).inferencePaths.contains(
        .inferred(kind: .parent, viaPersonIDs: [olderChildID])))
    #expect(resolution(middleChildID, in: fromParent).primaryLabel == "女儿")
    #expect(
      resolution(middleChildID, in: fromParent).inferencePaths.contains(
        .inferred(kind: .child, viaPersonIDs: [olderChildID])))
  }

  @Test("Inferred kinship wins over social labels without an explicit primary")
  func inferredKinshipWinsOverSocialLabelsWithoutExplicitPrimary() throws {
    let perspectiveID = id(1)
    let parentID = id(2)
    let uncleID = id(3)
    let cousinID = id(4)
    let people = [
      person(perspectiveID, birthday: birthday(1995), gender: .male),
      person(parentID, gender: .male),
      person(uncleID, gender: .male),
      person(cousinID, birthday: birthday(1990), gender: .female),
    ]
    let facts = [
      fact(id: id(531), a: parentID, b: perspectiveID, kind: .parentChild, aRole: .parent, bRole: .child),
      fact(id: id(532), a: parentID, b: uncleID, kind: .sibling, aRole: .sibling, bRole: .sibling),
      fact(id: id(533), a: uncleID, b: cousinID, kind: .parentChild, aRole: .parent, bRole: .child),
      fact(id: id(534), a: perspectiveID, b: cousinID, kind: .classmate, aRole: .classmate, bRole: .classmate),
    ]

    let result = resolution(
      cousinID,
      in: RelationshipResolver.resolve(people: people, facts: facts, perspectivePersonID: perspectiveID))

    #expect(result.primaryLabel == "堂姐")
    #expect(result.additionalLabels.contains("同学"))
  }

  @Test("Explicit primary social label still wins over inferred kinship")
  func explicitPrimarySocialLabelStillWinsOverInferredKinship() throws {
    let perspectiveID = id(1)
    let parentID = id(2)
    let uncleID = id(3)
    let cousinID = id(4)
    let people = [
      person(perspectiveID, birthday: birthday(1995), gender: .male),
      person(parentID, gender: .male),
      person(uncleID, gender: .male),
      person(cousinID, birthday: birthday(1990), gender: .female),
    ]
    let facts = [
      fact(id: id(541), a: parentID, b: perspectiveID, kind: .parentChild, aRole: .parent, bRole: .child),
      fact(id: id(542), a: parentID, b: uncleID, kind: .sibling, aRole: .sibling, bRole: .sibling),
      fact(id: id(543), a: uncleID, b: cousinID, kind: .parentChild, aRole: .parent, bRole: .child),
      fact(
        id: id(544),
        a: perspectiveID,
        b: cousinID,
        kind: .classmate,
        aRole: .classmate,
        bRole: .classmate,
        isPrimaryFromA: true),
    ]

    let result = resolution(
      cousinID,
      in: RelationshipResolver.resolve(people: people, facts: facts, perspectivePersonID: perspectiveID))

    #expect(result.primaryLabel == "同学")
    #expect(result.additionalLabels.contains("堂姐"))
  }

  @Test("Perspective missing endpoint is exposed as resolver diagnostic")
  func perspectiveMissingEndpointIsExposedAsResolverDiagnostic() throws {
    let perspectiveID = id(1)
    let targetID = id(2)
    let missingID = id(999)
    let people = [person(perspectiveID), person(targetID)]
    let facts = [
      fact(id: id(551), a: perspectiveID, b: missingID, kind: .friend, aRole: .friend, bRole: .friend)
    ]

    let result = RelationshipResolver.resolveWithDiagnostics(
      people: people,
      facts: facts,
      perspectivePersonID: perspectiveID)

    #expect(result.diagnostics == [.missingEndpoint])
    #expect(result.resolutions.map(\.targetPersonID) == [targetID])
  }

  @Test("Facts with missing endpoints mark known participants and are ignored for inference")
  func factsWithMissingEndpointsMarkKnownParticipantsAndAreIgnoredForInference() throws {
    let perspectiveID = id(1)
    let knownID = id(2)
    let missingID = id(999)
    let people = [person(perspectiveID), person(knownID)]
    let facts = [
      fact(id: id(601), a: perspectiveID, b: knownID, kind: .friend, aRole: .friend, bRole: .friend),
      fact(
        id: id(602),
        a: knownID,
        b: missingID,
        kind: .parentChild,
        aRole: .parent,
        bRole: .child),
    ]

    let result = resolution(
      knownID,
      in: RelationshipResolver.resolve(people: people, facts: facts, perspectivePersonID: perspectiveID))

    #expect(result.primaryLabel == "朋友")
    #expect(result.hasMissingEndpoint)
  }

  @Test("Conflicting kinship facts mark both affected resolutions")
  func conflictingKinshipFactsMarkBothAffectedResolutions() throws {
    let perspectiveID = id(1)
    let targetID = id(2)
    let people = [person(perspectiveID), person(targetID)]
    let facts = [
      fact(id: id(701), a: perspectiveID, b: targetID, kind: .sibling, aRole: .sibling, bRole: .sibling),
      fact(
        id: id(702),
        a: perspectiveID,
        b: targetID,
        kind: .parentChild,
        aRole: .parent,
        bRole: .child),
    ]

    let result = resolution(
      targetID,
      in: RelationshipResolver.resolve(people: people, facts: facts, perspectivePersonID: perspectiveID))

    #expect(result.hasConflict)
    #expect(result.primaryLabel == "子女")
  }

  @Test("Birth order compares era for era-based calendars")
  func birthOrderComparesEraForEraBasedCalendars() throws {
    let earlierChineseBirthday = birthday(10, calendarKind: .chinese, era: 78)
    let laterChineseBirthday = birthday(1, calendarKind: .chinese, era: 79)
    let missingEraChineseBirthday = birthday(10, calendarKind: .chinese)
    let gregorianOlderBirthday = birthday(1990)
    let gregorianYoungerBirthday = birthday(1992)
    let gregorianBirthdayWithEra = birthday(1990, calendarKind: .gregorian, era: 1)

    #expect(earlierChineseBirthday.birthOrderCompared(to: laterChineseBirthday) == .older)
    #expect(laterChineseBirthday.birthOrderCompared(to: earlierChineseBirthday) == .younger)
    #expect(earlierChineseBirthday.birthOrderCompared(to: earlierChineseBirthday) == .sameAge)
    #expect(missingEraChineseBirthday.birthOrderCompared(to: laterChineseBirthday) == nil)
    #expect(missingEraChineseBirthday.birthOrderCompared(to: missingEraChineseBirthday) == nil)
    #expect(gregorianOlderBirthday.birthOrderCompared(to: gregorianYoungerBirthday) == .older)
    #expect(gregorianBirthdayWithEra.birthOrderCompared(to: gregorianOlderBirthday) == nil)
  }

  @Test("Relationship inference paths preserve direct social primary and inferred provenance")
  func relationshipInferencePathsPreserveDirectSocialPrimaryAndInferredProvenance() throws {
    let perspectiveID = id(1)
    let parentID = id(2)
    let friendID = id(3)
    let classmateID = id(4)
    let grandparentID = id(5)
    let people = [
      person(perspectiveID),
      person(parentID),
      person(friendID),
      person(classmateID),
      person(grandparentID),
    ]
    let parentFact = fact(
      id: id(801),
      a: parentID,
      b: perspectiveID,
      kind: .parentChild,
      aRole: .parent,
      bRole: .child)
    let friendFact = fact(
      id: id(802),
      a: perspectiveID,
      b: friendID,
      kind: .friend,
      aRole: .friend,
      bRole: .friend)
    let primaryClassmateFact = fact(
      id: id(803),
      a: perspectiveID,
      b: classmateID,
      kind: .classmate,
      aRole: .classmate,
      bRole: .classmate,
      isPrimaryFromA: true)
    let grandparentFact = fact(
      id: id(804),
      a: grandparentID,
      b: parentID,
      kind: .parentChild,
      aRole: .parent,
      bRole: .child)

    let result = RelationshipResolver.resolve(
      people: people,
      facts: [parentFact, friendFact, primaryClassmateFact, grandparentFact],
      perspectivePersonID: perspectiveID)

    #expect(
      resolution(parentID, in: result).inferencePaths == [
        .direct(factID: id(801), kind: .parentChild)
      ])
    #expect(
      resolution(friendID, in: result).inferencePaths == [
        .social(factID: id(802), kind: .friend)
      ])
    #expect(
      resolution(classmateID, in: result).inferencePaths == [
        .primaryPreference(factID: id(803)),
        .social(factID: id(803), kind: .classmate),
      ])
    #expect(
      resolution(grandparentID, in: result).inferencePaths == [
        .inferred(kind: .grandparent, viaPersonIDs: [parentID])
      ])
  }

  @Test("Opposite parent child directions for the same pair mark conflict")
  func oppositeParentChildDirectionsForSamePairMarkConflict() throws {
    let perspectiveID = id(1)
    let targetID = id(2)
    let people = [person(perspectiveID), person(targetID)]
    let facts = [
      fact(
        id: id(901),
        a: perspectiveID,
        b: targetID,
        kind: .parentChild,
        aRole: .parent,
        bRole: .child),
      fact(
        id: id(902),
        a: targetID,
        b: perspectiveID,
        kind: .parentChild,
        aRole: .parent,
        bRole: .child),
    ]

    let result = resolution(
      targetID,
      in: RelationshipResolver.resolve(people: people, facts: facts, perspectivePersonID: perspectiveID))

    #expect(result.hasConflict)
  }

  @Test("Cousin neutral fallback preserves known lineage side")
  func cousinNeutralFallbackPreservesKnownLineageSide() throws {
    let cases: [(RelationshipGender, RelationshipGender, String)] = [
      (.male, .male, "堂兄弟姐妹"),
      (.male, .female, "姑表兄弟姐妹"),
      (.female, .male, "舅表兄弟姐妹"),
      (.female, .female, "姨表兄弟姐妹"),
    ]

    for (index, testCase) in cases.enumerated() {
      let base = 1_000 + index * 10
      let perspectiveID = id(base + 1)
      let parentID = id(base + 2)
      let parentSiblingID = id(base + 3)
      let cousinID = id(base + 4)
      let people = [
        person(perspectiveID),
        person(parentID, gender: testCase.0),
        person(parentSiblingID, gender: testCase.1),
        person(cousinID),
      ]
      let facts = [
        fact(
          id: id(base + 5),
          a: parentID,
          b: perspectiveID,
          kind: .parentChild,
          aRole: .parent,
          bRole: .child),
        fact(
          id: id(base + 6),
          a: parentID,
          b: parentSiblingID,
          kind: .sibling,
          aRole: .sibling,
          bRole: .sibling),
        fact(
          id: id(base + 7),
          a: parentSiblingID,
          b: cousinID,
          kind: .parentChild,
          aRole: .parent,
          bRole: .child),
      ]

      let result = RelationshipResolver.resolve(people: people, facts: facts, perspectivePersonID: perspectiveID)

      #expect(resolution(cousinID, in: result).primaryLabel == testCase.2)
    }
  }
}

private func id(_ value: Int) -> UUID {
  guard let uuid = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value)) else {
    preconditionFailure("Invalid deterministic UUID fixture")
  }
  return uuid
}

private func birthday(
  _ year: Int,
  _ month: Int = 1,
  _ day: Int = 1,
  calendarKind: BirthdayCalendarKind = .gregorian,
  era: Int? = nil
) -> RelationshipBirthday {
  RelationshipBirthday(calendarKind: calendarKind, era: era, year: year, month: month, day: day)
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
  a personAID: UUID,
  b personBID: UUID,
  kind: RelationshipKind,
  aRole: RelationshipRole,
  bRole: RelationshipRole,
  isPrimaryFromA: Bool = false,
  isPrimaryFromB: Bool = false,
  createdAt: Date = Date()
) -> RelationshipFact {
  fact(
    id: id,
    personAID: personAID,
    personBID: personBID,
    kind: kind,
    aRole: aRole,
    bRole: bRole,
    isPrimaryFromA: isPrimaryFromA,
    isPrimaryFromB: isPrimaryFromB,
    createdAt: createdAt)
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
