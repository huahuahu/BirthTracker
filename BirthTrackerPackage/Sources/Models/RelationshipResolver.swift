import Foundation

// swiftlint:disable file_length

public enum RelationshipResolver {
  public static func resolve(
    people: [RelationshipPersonInput],
    facts: [RelationshipFact],
    perspectivePersonID: UUID
  ) -> [RelationshipResolution] {
    resolveWithDiagnostics(
      people: people,
      facts: facts,
      perspectivePersonID: perspectivePersonID
    ).resolutions
  }

  public static func resolveWithDiagnostics(
    people: [RelationshipPersonInput],
    facts: [RelationshipFact],
    perspectivePersonID: UUID
  ) -> RelationshipResolverResult {
    let peopleByID = Dictionary(uniqueKeysWithValues: people.map { ($0.id, $0) })
    var accumulators = Dictionary(
      uniqueKeysWithValues:
        people
        .filter { $0.id != perspectivePersonID }
        .map { ($0.id, ResolutionAccumulator(targetPersonID: $0.id)) })
    var kinshipKindsByPair: [FactPairKey: Set<RelationshipKind>] = [:]
    var parentChildDirectionsByPair: [FactPairKey: ParentChildDirection] = [:]
    var resolverDiagnostics = Set<RelationshipResolutionDiagnostic>()
    var directInferredKindsByTarget: [UUID: Set<InferredRelationshipKind>] = [:]
    var graph = KinshipGraph(peopleIDs: Set(people.map(\.id)))

    for fact in deduplicatedFacts(facts.sorted(by: factSortPrecedes)) {
      let personAExists = peopleByID[fact.personAID] != nil
      let personBExists = peopleByID[fact.personBID] != nil
      if !personAExists && !personBExists {
        continue
      }
      if !personAExists || !personBExists {
        let knownID = personAExists ? fact.personAID : fact.personBID
        if knownID != perspectivePersonID {
          accumulators[knownID]?.addDiagnostic(RelationshipResolutionDiagnostic.missingEndpoint)
        } else {
          resolverDiagnostics.insert(.missingEndpoint)
        }
        continue
      }

      if fact.kind.isKinship {
        let pairKey = FactPairKey(fact.personAID, fact.personBID)
        let existingKinds = kinshipKindsByPair[pairKey, default: []]
        if existingKinds.isEmpty == false, existingKinds.contains(fact.kind) == false {
          accumulators[fact.personAID]?.addDiagnostic(.conflict)
          accumulators[fact.personBID]?.addDiagnostic(.conflict)
        }
        kinshipKindsByPair[pairKey, default: []].insert(fact.kind)

        if fact.kind == .parentChild, let direction = ParentChildDirection(fact) {
          let hasOppositeDirection = parentChildDirectionsByPair[pairKey].map { $0 != direction } ?? false
          if hasOppositeDirection {
            accumulators[fact.personAID]?.addDiagnostic(.conflict)
            accumulators[fact.personBID]?.addDiagnostic(.conflict)
          } else {
            parentChildDirectionsByPair[pairKey] = direction
          }
        }
      }

      graph.add(fact)

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
          factID: directContext.factID,
          primaryFactID: directContext.primaryFactID,
          kind: directContext.kind,
          priority: labelPriority(for: directContext.kind),
          createdAt: directContext.createdAt))
      if let inferredKind = directContext.inferredRelationshipKind {
        directInferredKindsByTarget[directContext.target.id, default: []].insert(inferredKind)
      }
    }

    graph.propagateKnownParentsAcrossSiblingGroups()
    addInferenceCandidates(
      graph: graph,
      peopleByID: peopleByID,
      perspectivePersonID: perspectivePersonID,
      directInferredKindsByTarget: directInferredKindsByTarget,
      accumulators: &accumulators)

    let resolutions =
      people
      .filter { $0.id != perspectivePersonID }
      .compactMap { accumulators[$0.id]?.resolution }
      .sorted { $0.targetPersonID.uuidString < $1.targetPersonID.uuidString }
    return RelationshipResolverResult(resolutions: resolutions, diagnostics: resolverDiagnostics)
  }
}

private struct CanonicalRelationshipFact {
  let id: UUID
  let personAID: UUID
  let personBID: UUID
  let kind: RelationshipKind
  let personARole: RelationshipRole
  let personBRole: RelationshipRole
  var isPrimaryFromPersonA: Bool
  var isPrimaryFromPersonB: Bool
  var primaryFactIDFromPersonA: UUID?
  var primaryFactIDFromPersonB: UUID?
  let createdAt: Date

  init(_ fact: RelationshipFact) {
    self.id = fact.id
    self.personAID = fact.personAID
    self.personBID = fact.personBID
    self.kind = fact.kind
    self.personARole = fact.personARole
    self.personBRole = fact.personBRole
    self.isPrimaryFromPersonA = fact.isPrimaryFromPersonA
    self.isPrimaryFromPersonB = fact.isPrimaryFromPersonB
    self.primaryFactIDFromPersonA = fact.isPrimaryFromPersonA ? fact.id : nil
    self.primaryFactIDFromPersonB = fact.isPrimaryFromPersonB ? fact.id : nil
    self.createdAt = fact.createdAt
  }

  mutating func mergePrimaryPreferences(from fact: RelationshipFact) {
    if fact.isPrimaryFromPersonA {
      mergePrimaryPreference(fromPersonID: fact.personAID, factID: fact.id)
    }
    if fact.isPrimaryFromPersonB {
      mergePrimaryPreference(fromPersonID: fact.personBID, factID: fact.id)
    }
  }

  private mutating func mergePrimaryPreference(fromPersonID: UUID, factID: UUID) {
    if fromPersonID == personAID {
      isPrimaryFromPersonA = true
      primaryFactIDFromPersonA = primaryFactIDFromPersonA ?? factID
    } else if fromPersonID == personBID {
      isPrimaryFromPersonB = true
      primaryFactIDFromPersonB = primaryFactIDFromPersonB ?? factID
    }
  }
}

private struct DirectRelationshipContext {
  let perspective: RelationshipPersonInput
  let target: RelationshipPersonInput
  let kind: RelationshipKind
  let targetRole: RelationshipRole
  let isPrimary: Bool
  let factID: UUID
  let primaryFactID: UUID?
  let createdAt: Date

  init?(
    fact: CanonicalRelationshipFact,
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
      self.factID = fact.id
      self.primaryFactID = fact.primaryFactIDFromPersonA
      self.createdAt = fact.createdAt
    } else if fact.personBID == perspectivePersonID, let target = peopleByID[fact.personAID] {
      self.perspective = perspective
      self.target = target
      self.kind = fact.kind
      self.targetRole = fact.personARole
      self.isPrimary = fact.isPrimaryFromPersonB
      self.factID = fact.id
      self.primaryFactID = fact.primaryFactIDFromPersonB
      self.createdAt = fact.createdAt
    } else {
      return nil
    }
  }

  var inferredRelationshipKind: InferredRelationshipKind? {
    switch kind {
    case .parentChild:
      switch targetRole {
      case .parent:
        return .parent
      case .child:
        return .child
      case .sibling, .spouse, .friend, .classmate, .coworker:
        return nil
      }
    case .sibling:
      return .sibling
    case .spouse:
      return .spouse
    case .friend, .classmate, .coworker:
      return nil
    }
  }
}

private struct LabelCandidate: Equatable {
  let label: String
  let isPrimary: Bool
  let inferencePaths: [RelationshipInferencePath]
  let priority: Int
  let createdAt: Date
  let sortKey: String

  init(
    label: String,
    isPrimary: Bool,
    factID: UUID,
    primaryFactID: UUID? = nil,
    kind: RelationshipKind,
    priority: Int,
    createdAt: Date
  ) {
    self.label = label
    self.isPrimary = isPrimary
    var paths: [RelationshipInferencePath] = []
    if isPrimary {
      paths.append(.primaryPreference(factID: primaryFactID ?? factID))
    }
    paths.append(kind.isKinship ? .direct(factID: factID, kind: kind) : .social(factID: factID, kind: kind))
    self.inferencePaths = paths
    self.priority = priority
    self.createdAt = createdAt
    self.sortKey = factID.uuidString
  }

  init(inferredLabel label: String, kind: InferredRelationshipKind, viaPersonIDs: [UUID], priority: Int) {
    self.label = label
    self.isPrimary = false
    self.inferencePaths = [.inferred(kind: kind, viaPersonIDs: viaPersonIDs)]
    self.priority = priority
    self.createdAt = .distantFuture
    self.sortKey = label
  }
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
    let sortedCandidates =
      [primaryCandidate].compactMap { $0 }
      + candidates.sorted(by: candidateSortPrecedes).filter { $0 != primaryCandidate }
    let additionalLabels =
      sortedCandidates
      .filter { $0 != primaryCandidate }
      .filter { $0.label != primaryCandidate?.label }
      .map(\.label)
      .deduplicated()
    let inferencePaths =
      sortedCandidates
      .flatMap(\.inferencePaths)
      .deduplicated()

    return RelationshipResolution(
      targetPersonID: targetPersonID,
      primaryLabel: primaryCandidate?.label,
      additionalLabels: additionalLabels,
      inferencePaths: inferencePaths,
      diagnostics: diagnostics)
  }
}

private func deduplicatedFacts(_ facts: [RelationshipFact]) -> [CanonicalRelationshipFact] {
  var factsByKey: [FactKey: Int] = [:]
  var deduplicatedFacts: [CanonicalRelationshipFact] = []

  for fact in facts {
    let key = FactKey(fact)
    if let index = factsByKey[key] {
      deduplicatedFacts[index].mergePrimaryPreferences(from: fact)
    } else {
      factsByKey[key] = deduplicatedFacts.count
      deduplicatedFacts.append(CanonicalRelationshipFact(fact))
    }
  }

  return deduplicatedFacts
}

private struct FactKey: Hashable {
  let firstPersonID: UUID
  let secondPersonID: UUID
  let kind: RelationshipKind
  let firstPersonRole: RelationshipRole
  let secondPersonRole: RelationshipRole

  init(_ fact: RelationshipFact) {
    self.kind = fact.kind
    if fact.personAID.uuidString <= fact.personBID.uuidString {
      self.firstPersonID = fact.personAID
      self.secondPersonID = fact.personBID
      self.firstPersonRole = fact.personARole
      self.secondPersonRole = fact.personBRole
    } else {
      self.firstPersonID = fact.personBID
      self.secondPersonID = fact.personAID
      self.firstPersonRole = fact.personBRole
      self.secondPersonRole = fact.personARole
    }
  }
}

private struct FactPairKey: Hashable {
  let firstPersonID: UUID
  let secondPersonID: UUID

  init(_ lhs: UUID, _ rhs: UUID) {
    if lhs.uuidString <= rhs.uuidString {
      self.firstPersonID = lhs
      self.secondPersonID = rhs
    } else {
      self.firstPersonID = rhs
      self.secondPersonID = lhs
    }
  }
}

private struct ParentChildRelationKey: Hashable {
  let parentID: UUID
  let childID: UUID
}

private struct ParentChildDirection: Equatable {
  let parentID: UUID
  let childID: UUID

  init?(_ fact: CanonicalRelationshipFact) {
    if fact.personARole == .parent, fact.personBRole == .child {
      self.parentID = fact.personAID
      self.childID = fact.personBID
    } else if fact.personBRole == .parent, fact.personARole == .child {
      self.parentID = fact.personBID
      self.childID = fact.personAID
    } else {
      return nil
    }
  }
}

private struct KinshipGraph {
  private(set) var parentsByChild: [UUID: Set<UUID>] = [:]
  private(set) var childrenByParent: [UUID: Set<UUID>] = [:]
  private(set) var spousesByPerson: [UUID: Set<UUID>] = [:]
  private var inferredParentSourcesByRelation: [ParentChildRelationKey: Set<UUID>] = [:]
  private var siblingEdgesByPerson: [UUID: Set<UUID>] = [:]
  private var siblingGroups: UnionFind

  init(peopleIDs: Set<UUID>) {
    siblingGroups = UnionFind(peopleIDs)
  }

  mutating func add(_ fact: CanonicalRelationshipFact) {
    switch fact.kind {
    case .parentChild:
      addParentChildFact(fact)
    case .sibling:
      guard fact.personARole == .sibling, fact.personBRole == .sibling else { return }
      siblingGroups.union(fact.personAID, fact.personBID)
      siblingEdgesByPerson[fact.personAID, default: []].insert(fact.personBID)
      siblingEdgesByPerson[fact.personBID, default: []].insert(fact.personAID)
    case .spouse:
      guard fact.personARole == .spouse, fact.personBRole == .spouse else { return }
      spousesByPerson[fact.personAID, default: []].insert(fact.personBID)
      spousesByPerson[fact.personBID, default: []].insert(fact.personAID)
    case .friend, .classmate, .coworker:
      return
    }
  }

  mutating func propagateKnownParentsAcrossSiblingGroups() {
    for group in siblingGroups.groups() where group.count > 1 {
      let parentSourcesByParentID = group.reduce(into: [UUID: Set<UUID>]()) { sources, member in
        for parent in parentsByChild[member, default: []] {
          sources[parent, default: []].insert(member)
        }
      }

      for member in group {
        for (parent, sourceMembers) in parentSourcesByParentID where parent != member {
          if parentsByChild[member, default: []].contains(parent) == false {
            inferredParentSourcesByRelation[
              ParentChildRelationKey(parentID: parent, childID: member),
              default: []
            ].formUnion(sourceMembers.subtracting([member]))
          }
          parentsByChild[member, default: []].insert(parent)
          childrenByParent[parent, default: []].insert(member)
        }
      }
    }
  }

  func parents(of childID: UUID) -> Set<UUID> {
    parentsByChild[childID, default: []]
  }

  func children(of parentID: UUID) -> Set<UUID> {
    childrenByParent[parentID, default: []]
  }

  func siblings(of personID: UUID) -> Set<UUID> {
    siblingGroups.group(containing: personID).subtracting([personID])
  }

  func inferredParentViaPersonIDs(parentID: UUID, childID: UUID) -> [UUID] {
    inferredParentSourcesByRelation[
      ParentChildRelationKey(parentID: parentID, childID: childID),
      default: []
    ].sortedByUUIDString()
  }

  func inferredSiblingViaPersonIDs(_ personID: UUID, siblingID: UUID) -> [UUID] {
    if siblingEdgesByPerson[personID, default: []].contains(siblingID) {
      return []
    }

    let commonDirectSiblings = siblingEdgesByPerson[personID, default: []]
      .intersection(siblingEdgesByPerson[siblingID, default: []])
    if commonDirectSiblings.isEmpty == false {
      return commonDirectSiblings.sortedByUUIDString()
    }

    return siblings(of: personID)
      .intersection(siblings(of: siblingID))
      .subtracting([personID, siblingID])
      .sortedByUUIDString()
  }

  private mutating func addParentChildFact(_ fact: CanonicalRelationshipFact) {
    if fact.personARole == .parent, fact.personBRole == .child {
      addParent(fact.personAID, child: fact.personBID)
    } else if fact.personBRole == .parent, fact.personARole == .child {
      addParent(fact.personBID, child: fact.personAID)
    }
  }

  private mutating func addParent(_ parent: UUID, child: UUID) {
    guard parent != child else { return }
    parentsByChild[child, default: []].insert(parent)
    childrenByParent[parent, default: []].insert(child)
  }
}

private struct UnionFind {
  private var parentByID: [UUID: UUID]

  init(_ ids: Set<UUID>) {
    parentByID = Dictionary(uniqueKeysWithValues: ids.map { ($0, $0) })
  }

  mutating func union(_ lhs: UUID, _ rhs: UUID) {
    let lhsRoot = root(of: lhs)
    let rhsRoot = root(of: rhs)
    guard lhsRoot != rhsRoot else { return }
    if lhsRoot.uuidString < rhsRoot.uuidString {
      parentByID[rhsRoot] = lhsRoot
    } else {
      parentByID[lhsRoot] = rhsRoot
    }
  }

  mutating func root(of id: UUID) -> UUID {
    let parent = parentByID[id, default: id]
    parentByID[id] = parent
    if parent == id {
      return id
    }

    let rootID = root(of: parent)
    parentByID[id] = rootID
    return rootID
  }

  mutating func groups() -> [[UUID]] {
    for id in parentByID.keys {
      _ = root(of: id)
    }

    return Dictionary(grouping: parentByID.keys) { parentByID[$0, default: $0] }
      .values
      .map { $0.sortedByUUIDString() }
  }

  func group(containing id: UUID) -> Set<UUID> {
    guard let rootID = resolvedRoot(of: id) else { return [id] }
    return Set(parentByID.keys.filter { resolvedRoot(of: $0) == rootID })
  }

  private func resolvedRoot(of id: UUID) -> UUID? {
    guard let parent = parentByID[id] else { return nil }
    if parent == id { return id }
    return resolvedRoot(of: parent)
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

private func addInferenceCandidates(
  graph: KinshipGraph,
  peopleByID: [UUID: RelationshipPersonInput],
  perspectivePersonID: UUID,
  directInferredKindsByTarget: [UUID: Set<InferredRelationshipKind>],
  accumulators: inout [UUID: ResolutionAccumulator]
) {
  guard let perspective = peopleByID[perspectivePersonID] else { return }
  let context = InferenceContext(
    graph: graph,
    peopleByID: peopleByID,
    perspective: perspective,
    perspectivePersonID: perspectivePersonID,
    perspectiveParents: graph.parents(of: perspectivePersonID),
    directInferredKindsByTarget: directInferredKindsByTarget)

  addParentCandidates(context: context, accumulators: &accumulators)
  addChildCandidates(context: context, accumulators: &accumulators)
  addSiblingCandidates(context: context, accumulators: &accumulators)
  addGrandparentCandidates(context: context, accumulators: &accumulators)
  addGrandchildCandidates(context: context, accumulators: &accumulators)
  let lineageParentIDsByParentSiblingID = addParentSiblingCandidates(context: context, accumulators: &accumulators)
  addSiblingChildCandidates(context: context, accumulators: &accumulators)
  addCousinCandidates(
    context: context,
    lineageParentIDsByParentSiblingID: lineageParentIDsByParentSiblingID,
    accumulators: &accumulators)
}

private struct InferenceContext {
  let graph: KinshipGraph
  let peopleByID: [UUID: RelationshipPersonInput]
  let perspective: RelationshipPersonInput
  let perspectivePersonID: UUID
  let perspectiveParents: Set<UUID>
  let directInferredKindsByTarget: [UUID: Set<InferredRelationshipKind>]

  func hasDirectCandidate(targetID: UUID, kind: InferredRelationshipKind) -> Bool {
    directInferredKindsByTarget[targetID, default: []].contains(kind)
  }
}

private func addParentCandidates(
  context: InferenceContext,
  accumulators: inout [UUID: ResolutionAccumulator]
) {
  for parentID in context.perspectiveParents.sortedByUUIDString()
  where context.hasDirectCandidate(targetID: parentID, kind: .parent) == false {
    guard let parent = context.peopleByID[parentID] else { continue }
    accumulators[parentID]?.addCandidate(
      LabelCandidate(
        inferredLabel: parentLabel(for: parent.relationshipGender),
        kind: .parent,
        viaPersonIDs: context.graph.inferredParentViaPersonIDs(
          parentID: parentID,
          childID: context.perspectivePersonID),
        priority: inferredLabelPriority))
  }
}

private func addChildCandidates(
  context: InferenceContext,
  accumulators: inout [UUID: ResolutionAccumulator]
) {
  for childID in context.graph.children(of: context.perspectivePersonID).sortedByUUIDString() {
    guard childID != context.perspectivePersonID else { continue }
    let hasDirectChildCandidate = context.hasDirectCandidate(targetID: childID, kind: .child)
    guard hasDirectChildCandidate == false else { continue }
    guard let child = context.peopleByID[childID] else { continue }
    accumulators[childID]?.addCandidate(
      LabelCandidate(
        inferredLabel: childLabel(for: child.relationshipGender),
        kind: .child,
        viaPersonIDs: context.graph.inferredParentViaPersonIDs(
          parentID: context.perspectivePersonID,
          childID: childID),
        priority: inferredLabelPriority))
  }
}

private func addSiblingCandidates(
  context: InferenceContext,
  accumulators: inout [UUID: ResolutionAccumulator]
) {
  for siblingID in context.graph.siblings(of: context.perspectivePersonID).sortedByUUIDString()
  where context.hasDirectCandidate(targetID: siblingID, kind: .sibling) == false {
    guard let sibling = context.peopleByID[siblingID] else { continue }
    accumulators[siblingID]?.addCandidate(
      LabelCandidate(
        inferredLabel: siblingLabel(perspective: context.perspective, target: sibling),
        kind: .sibling,
        viaPersonIDs: context.graph.inferredSiblingViaPersonIDs(
          context.perspectivePersonID,
          siblingID: siblingID),
        priority: inferredLabelPriority))
  }
}

private func addGrandparentCandidates(
  context: InferenceContext,
  accumulators: inout [UUID: ResolutionAccumulator]
) {
  for parentID in context.perspectiveParents.sortedByUUIDString() {
    guard let parent = context.peopleByID[parentID] else { continue }
    for grandparentID in context.graph.parents(of: parentID).sortedByUUIDString()
    where grandparentID != context.perspectivePersonID {
      guard let grandparent = context.peopleByID[grandparentID] else { continue }
      accumulators[grandparentID]?.addCandidate(
        LabelCandidate(
          inferredLabel: grandparentLabel(parent: parent, grandparent: grandparent),
          kind: .grandparent,
          viaPersonIDs: [parentID],
          priority: inferredLabelPriority))
    }
  }
}

private func addGrandchildCandidates(
  context: InferenceContext,
  accumulators: inout [UUID: ResolutionAccumulator]
) {
  for childID in context.graph.children(of: context.perspectivePersonID).sortedByUUIDString() {
    guard let child = context.peopleByID[childID] else { continue }
    for grandchildID in context.graph.children(of: childID).sortedByUUIDString()
    where grandchildID != context.perspectivePersonID {
      guard let grandchild = context.peopleByID[grandchildID] else { continue }
      accumulators[grandchildID]?.addCandidate(
        LabelCandidate(
          inferredLabel: grandchildLabel(child: child, grandchild: grandchild),
          kind: .grandchild,
          viaPersonIDs: [childID],
          priority: inferredLabelPriority))
    }
  }
}

private func addParentSiblingCandidates(
  context: InferenceContext,
  accumulators: inout [UUID: ResolutionAccumulator]
) -> [UUID: UUID] {
  var lineageParentIDsByParentSiblingID: [UUID: UUID] = [:]
  for parentID in context.perspectiveParents.sortedByUUIDString() {
    guard let parent = context.peopleByID[parentID] else { continue }
    for parentSiblingID in context.graph.siblings(of: parentID).sortedByUUIDString()
    where parentSiblingID != context.perspectivePersonID {
      guard let parentSibling = context.peopleByID[parentSiblingID] else { continue }
      lineageParentIDsByParentSiblingID[parentSiblingID] = parentID
      accumulators[parentSiblingID]?.addCandidate(
        LabelCandidate(
          inferredLabel: parentSiblingLabel(parent: parent, parentSibling: parentSibling),
          kind: .parentSibling,
          viaPersonIDs: [parentID],
          priority: inferredLabelPriority))
    }
  }
  return lineageParentIDsByParentSiblingID
}

private func addSiblingChildCandidates(
  context: InferenceContext,
  accumulators: inout [UUID: ResolutionAccumulator]
) {
  for siblingID in context.graph.siblings(of: context.perspectivePersonID).sortedByUUIDString() {
    guard let sibling = context.peopleByID[siblingID] else { continue }
    for siblingChildID in context.graph.children(of: siblingID).sortedByUUIDString()
    where siblingChildID != context.perspectivePersonID {
      guard let siblingChild = context.peopleByID[siblingChildID] else { continue }
      accumulators[siblingChildID]?.addCandidate(
        LabelCandidate(
          inferredLabel: siblingChildLabel(sibling: sibling, siblingChild: siblingChild),
          kind: .siblingChild,
          viaPersonIDs: [siblingID],
          priority: inferredLabelPriority))
    }
  }
}

private func addCousinCandidates(
  context: InferenceContext,
  lineageParentIDsByParentSiblingID: [UUID: UUID],
  accumulators: inout [UUID: ResolutionAccumulator]
) {
  for parentSiblingID in lineageParentIDsByParentSiblingID.keys.sortedByUUIDString() {
    guard let parentSibling = context.peopleByID[parentSiblingID] else { continue }
    addCousins(
      for: parentSibling,
      parentSiblingID: parentSiblingID,
      lineageParentID: lineageParentIDsByParentSiblingID[parentSiblingID],
      context: context,
      accumulators: &accumulators)
  }
}

private func addCousins(
  for parentSibling: RelationshipPersonInput,
  parentSiblingID: UUID,
  lineageParentID: UUID?,
  context: InferenceContext,
  accumulators: inout [UUID: ResolutionAccumulator]
) {
  let lineageParent = lineageParentID.flatMap { context.peopleByID[$0] }
  for cousinID in context.graph.children(of: parentSiblingID).sortedByUUIDString()
  where cousinID != context.perspectivePersonID {
    guard let cousin = context.peopleByID[cousinID] else { continue }
    accumulators[cousinID]?.addCandidate(
      LabelCandidate(
        inferredLabel: cousinLabel(
          perspective: context.perspective,
          lineageParent: lineageParent,
          parentSibling: parentSibling,
          cousin: cousin),
        kind: .cousin,
        viaPersonIDs: [lineageParentID, parentSiblingID].compactMap { $0 },
        priority: inferredLabelPriority))
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
    return "子女"
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

private func grandparentLabel(
  parent: RelationshipPersonInput,
  grandparent: RelationshipPersonInput
) -> String {
  switch (parent.relationshipGender, grandparent.relationshipGender) {
  case (.male, .male):
    return "爷爷"
  case (.male, .female):
    return "奶奶"
  case (.female, .male):
    return "外公"
  case (.female, .female):
    return "外婆"
  case (_, .unknown), (.unknown, _):
    return "祖父母"
  }
}

private func grandchildLabel(
  child: RelationshipPersonInput,
  grandchild: RelationshipPersonInput
) -> String {
  switch (child.relationshipGender, grandchild.relationshipGender) {
  case (.male, .male):
    return "孙子"
  case (.male, .female):
    return "孙女"
  case (.female, .male):
    return "外孙"
  case (.female, .female):
    return "外孙女"
  case (.female, .unknown):
    return "外孙辈"
  case (.male, .unknown), (.unknown, _):
    return "孙辈"
  }
}

private func parentSiblingLabel(
  parent: RelationshipPersonInput,
  parentSibling: RelationshipPersonInput
) -> String {
  switch (parent.relationshipGender, parentSibling.relationshipGender) {
  case (.male, .male):
    return "叔伯"
  case (.male, .female):
    return "姑妈"
  case (.female, .male):
    return "舅舅"
  case (.female, .female):
    return "姨妈"
  case (_, .unknown), (.unknown, _):
    return "叔伯姑姨"
  }
}

private func siblingChildLabel(
  sibling: RelationshipPersonInput,
  siblingChild: RelationshipPersonInput
) -> String {
  switch (sibling.relationshipGender, siblingChild.relationshipGender) {
  case (.male, .male):
    return "侄子"
  case (.male, .female):
    return "侄女"
  case (.female, .male):
    return "外甥"
  case (.female, .female):
    return "外甥女"
  case (_, .unknown), (.unknown, _):
    return "侄甥"
  }
}

private func cousinLabel(
  perspective: RelationshipPersonInput,
  lineageParent: RelationshipPersonInput?,
  parentSibling: RelationshipPersonInput,
  cousin: RelationshipPersonInput
) -> String {
  guard
    let lineageParent,
    lineageParent.relationshipGender != .unknown,
    parentSibling.relationshipGender != .unknown
  else {
    return "堂表亲"
  }

  let isTang = lineageParent.relationshipGender == .male && parentSibling.relationshipGender == .male
  let prefix = isTang ? "堂" : "表"
  let neutralLabel = neutralCousinLabel(lineageParent: lineageParent, parentSibling: parentSibling)

  guard
    let perspectiveBirthday = perspective.birthday,
    let cousinBirthday = cousin.birthday,
    let birthOrder = cousinBirthday.birthOrderCompared(to: perspectiveBirthday)
  else {
    return neutralLabel
  }

  switch (birthOrder, cousin.relationshipGender) {
  case (.older, .male):
    return "\(prefix)哥"
  case (.older, .female):
    return "\(prefix)姐"
  case (.younger, .male):
    return "\(prefix)弟"
  case (.younger, .female):
    return "\(prefix)妹"
  case (.sameAge, _), (_, .unknown):
    return neutralLabel
  }
}

private func neutralCousinLabel(
  lineageParent: RelationshipPersonInput,
  parentSibling: RelationshipPersonInput
) -> String {
  switch (lineageParent.relationshipGender, parentSibling.relationshipGender) {
  case (.male, .male):
    return "堂兄弟姐妹"
  case (.male, .female):
    return "姑表兄弟姐妹"
  case (.female, .male):
    return "舅表兄弟姐妹"
  case (.female, .female):
    return "姨表兄弟姐妹"
  case (_, .unknown), (.unknown, _):
    return "堂表亲"
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
  return lhs.sortKey < rhs.sortKey
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
    return 4
  case .classmate:
    return 5
  case .coworker:
    return 6
  }
}

private let inferredLabelPriority = 3

extension RelationshipKind {
  fileprivate var isKinship: Bool {
    switch self {
    case .parentChild, .sibling, .spouse:
      return true
    case .friend, .classmate, .coworker:
      return false
    }
  }
}

extension Array where Element: Hashable {
  fileprivate func deduplicated() -> [Element] {
    var seen = Set<Element>()
    return filter { seen.insert($0).inserted }
  }
}

extension Sequence where Element == UUID {
  fileprivate func sortedByUUIDString() -> [UUID] {
    sorted { $0.uuidString < $1.uuidString }
  }
}
