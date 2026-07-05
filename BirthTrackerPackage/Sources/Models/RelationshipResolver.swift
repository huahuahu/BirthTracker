import Foundation

public enum RelationshipResolver {
  public static func resolve(
    people: [RelationshipPersonInput],
    facts: [RelationshipFact],
    perspectivePersonID: UUID
  ) -> [RelationshipResolution] {
    let peopleByID = Dictionary(uniqueKeysWithValues: people.map { ($0.id, $0) })
    var accumulators = Dictionary(
      uniqueKeysWithValues:
        people
        .filter { $0.id != perspectivePersonID }
        .map { ($0.id, ResolutionAccumulator(targetPersonID: $0.id)) })
    var seenFactKeys = Set<FactKey>()

    for fact in facts.sorted(by: factSortPrecedes) {
      let key = FactKey(fact)
      guard seenFactKeys.insert(key).inserted else { continue }

      let personAExists = peopleByID[fact.personAID] != nil
      let personBExists = peopleByID[fact.personBID] != nil
      if !personAExists && !personBExists {
        continue
      }
      if !personAExists || !personBExists {
        let knownID = personAExists ? fact.personAID : fact.personBID
        if knownID != perspectivePersonID {
          accumulators[knownID]?.addDiagnostic(RelationshipResolutionDiagnostic.missingEndpoint)
        }
        continue
      }

      guard
        let directContext = DirectRelationshipContext(
          fact: fact,
          peopleByID: peopleByID,
          perspectivePersonID: perspectivePersonID)
      else {
        continue
      }

      accumulators[directContext.target.id]?.addCandidate(
        LabelCandidate(
          label: directLabel(for: directContext),
          isPrimary: directContext.isPrimary,
          factID: fact.id,
          priority: labelPriority(for: directContext.kind),
          createdAt: fact.createdAt))
    }

    return
      people
      .filter { $0.id != perspectivePersonID }
      .compactMap { accumulators[$0.id]?.resolution }
      .sorted { $0.targetPersonID.uuidString < $1.targetPersonID.uuidString }
  }
}

private struct DirectRelationshipContext {
  let perspective: RelationshipPersonInput
  let target: RelationshipPersonInput
  let kind: RelationshipKind
  let targetRole: RelationshipRole
  let isPrimary: Bool

  init?(
    fact: RelationshipFact,
    peopleByID: [UUID: RelationshipPersonInput],
    perspectivePersonID: UUID
  ) {
    guard let perspective = peopleByID[perspectivePersonID] else { return nil }
    if fact.personAID == perspectivePersonID, let target = peopleByID[fact.personBID] {
      self.perspective = perspective
      self.target = target
      self.kind = fact.kind
      self.targetRole = fact.personBRole
      self.isPrimary = fact.isPrimaryFromPersonA
    } else if fact.personBID == perspectivePersonID, let target = peopleByID[fact.personAID] {
      self.perspective = perspective
      self.target = target
      self.kind = fact.kind
      self.targetRole = fact.personARole
      self.isPrimary = fact.isPrimaryFromPersonB
    } else {
      return nil
    }
  }
}

private struct LabelCandidate: Equatable {
  let label: String
  let isPrimary: Bool
  let factID: UUID
  let priority: Int
  let createdAt: Date
}

private struct ResolutionAccumulator {
  let targetPersonID: UUID
  private var candidates: [LabelCandidate] = []
  private var diagnostics: Set<RelationshipResolutionDiagnostic> = []

  init(targetPersonID: UUID) {
    self.targetPersonID = targetPersonID
  }

  mutating func addCandidate(_ candidate: LabelCandidate) {
    candidates.append(candidate)
  }

  mutating func addDiagnostic(_ diagnostic: RelationshipResolutionDiagnostic) {
    diagnostics.insert(diagnostic)
  }

  var resolution: RelationshipResolution {
    var diagnostics = diagnostics
    let primaryCandidates = candidates.filter(\.isPrimary)
    if primaryCandidates.count > 1 {
      diagnostics.insert(.conflict)
    }

    let primaryCandidate =
      primaryCandidates.sorted(by: primaryCandidateSortPrecedes).first
      ?? candidates.sorted(by: candidateSortPrecedes).first
    let additionalLabels =
      candidates
      .sorted(by: candidateSortPrecedes)
      .filter { $0 != primaryCandidate }
      .map(\.label)
      .deduplicated()
    let inferencePaths =
      candidates
      .sorted(by: candidateSortPrecedes)
      .map { RelationshipInferencePath.direct(factID: $0.factID) }
      .deduplicated()

    return RelationshipResolution(
      targetPersonID: targetPersonID,
      primaryLabel: primaryCandidate?.label,
      additionalLabels: additionalLabels,
      inferencePaths: inferencePaths,
      diagnostics: diagnostics)
  }
}

private struct FactKey: Hashable {
  let personAID: UUID
  let personBID: UUID
  let kind: RelationshipKind
  let personARole: RelationshipRole
  let personBRole: RelationshipRole

  init(_ fact: RelationshipFact) {
    self.personAID = fact.personAID
    self.personBID = fact.personBID
    self.kind = fact.kind
    self.personARole = fact.personARole
    self.personBRole = fact.personBRole
  }
}

private func directLabel(for context: DirectRelationshipContext) -> String {
  switch context.kind {
  case .parentChild:
    switch context.targetRole {
    case .parent:
      return parentLabel(for: context.target.relationshipGender)
    case .child:
      return childLabel(for: context.target.relationshipGender)
    case .sibling, .spouse, .friend, .classmate, .coworker:
      return "亲属"
    }
  case .sibling:
    return siblingLabel(perspective: context.perspective, target: context.target)
  case .spouse:
    return spouseLabel(for: context.target.relationshipGender)
  case .friend:
    return "朋友"
  case .classmate:
    return "同学"
  case .coworker:
    return "同事"
  }
}

private func parentLabel(for gender: RelationshipGender) -> String {
  switch gender {
  case .male:
    return "父亲"
  case .female:
    return "母亲"
  case .unknown:
    return "父母"
  }
}

private func childLabel(for gender: RelationshipGender) -> String {
  switch gender {
  case .male:
    return "儿子"
  case .female:
    return "女儿"
  case .unknown:
    return "孩子"
  }
}

private func spouseLabel(for gender: RelationshipGender) -> String {
  switch gender {
  case .male:
    return "丈夫"
  case .female:
    return "妻子"
  case .unknown:
    return "配偶"
  }
}

private func siblingLabel(perspective: RelationshipPersonInput, target: RelationshipPersonInput) -> String {
  guard
    let perspectiveBirthday = perspective.birthday,
    let targetBirthday = target.birthday,
    let birthOrder = targetBirthday.birthOrderCompared(to: perspectiveBirthday)
  else {
    return "兄弟姐妹"
  }

  switch (birthOrder, target.relationshipGender) {
  case (.older, .male):
    return "哥哥"
  case (.older, .female):
    return "姐姐"
  case (.younger, .male):
    return "弟弟"
  case (.younger, .female):
    return "妹妹"
  case (.sameAge, _), (_, .unknown):
    return "兄弟姐妹"
  }
}

private func factSortPrecedes(_ lhs: RelationshipFact, _ rhs: RelationshipFact) -> Bool {
  if lhs.createdAt != rhs.createdAt {
    return lhs.createdAt < rhs.createdAt
  }
  return lhs.id.uuidString < rhs.id.uuidString
}

private func candidateSortPrecedes(_ lhs: LabelCandidate, _ rhs: LabelCandidate) -> Bool {
  if lhs.priority != rhs.priority {
    return lhs.priority < rhs.priority
  }
  return primaryCandidateSortPrecedes(lhs, rhs)
}

private func primaryCandidateSortPrecedes(_ lhs: LabelCandidate, _ rhs: LabelCandidate) -> Bool {
  if lhs.createdAt != rhs.createdAt {
    return lhs.createdAt < rhs.createdAt
  }
  return lhs.factID.uuidString < rhs.factID.uuidString
}

private func labelPriority(for kind: RelationshipKind) -> Int {
  switch kind {
  case .parentChild:
    return 0
  case .spouse:
    return 1
  case .sibling:
    return 2
  case .friend:
    return 3
  case .classmate:
    return 4
  case .coworker:
    return 5
  }
}

extension Array where Element: Hashable {
  fileprivate func deduplicated() -> [Element] {
    var seen = Set<Element>()
    return filter { seen.insert($0).inserted }
  }
}
