import Foundation

// swiftlint:disable file_length

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
    var kinshipKindsByPair: [FactPairKey: Set<RelationshipKind>] = [:]
    var parentChildDirectionsByPair: [FactPairKey: ParentChildDirection] = [:]
    var graph = KinshipGraph(peopleIDs: Set(people.map(\.id)))

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
          factID: fact.id,
          kind: directContext.kind,
          priority: labelPriority(for: directContext.kind),
          createdAt: fact.createdAt))
    }

    graph.propagateKnownParentsAcrossSiblingGroups()
    addInferenceCandidates(
      graph: graph,
      peopleByID: peopleByID,
      perspectivePersonID: perspectivePersonID,
      accumulators: &accumulators)

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
  let inferencePaths: [RelationshipInferencePath]
  let priority: Int
  let createdAt: Date
  let sortKey: String

  init(
    label: String,
    isPrimary: Bool,
    factID: UUID,
    kind: RelationshipKind,
    priority: Int,
    createdAt: Date
  ) {
    self.label = label
    self.isPrimary = isPrimary
    var paths: [RelationshipInferencePath] = []
    if isPrimary {
      paths.append(.primaryPreference(factID: factID))
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
    let additionalLabels =
      candidates
      .sorted(by: candidateSortPrecedes)
      .filter { $0 != primaryCandidate }
      .map(\.label)
      .deduplicated()
    let inferencePaths =
      candidates
      .sorted(by: candidateSortPrecedes)
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

private struct ParentChildDirection: Equatable {
  let parentID: UUID
  let childID: UUID

  init?(_ fact: RelationshipFact) {
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
  private var siblingGroups: UnionFind

  init(peopleIDs: Set<UUID>) {
    siblingGroups = UnionFind(peopleIDs)
  }

  mutating func add(_ fact: RelationshipFact) {
    switch fact.kind {
    case .parentChild:
      addParentChildFact(fact)
    case .sibling:
      guard fact.personARole == .sibling, fact.personBRole == .sibling else { return }
      siblingGroups.union(fact.personAID, fact.personBID)
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
      let knownParents = group.reduce(into: Set<UUID>()) { parents, member in
        parents.formUnion(parentsByChild[member, default: []])
      }

      for member in group {
        for parent in knownParents where parent != member {
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

  private mutating func addParentChildFact(_ fact: RelationshipFact) {
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
  accumulators: inout [UUID: ResolutionAccumulator]
) {
  guard let perspective = peopleByID[perspectivePersonID] else { return }
  let context = InferenceContext(
    graph: graph,
    peopleByID: peopleByID,
    perspective: perspective,
    perspectivePersonID: perspectivePersonID,
    perspectiveParents: graph.parents(of: perspectivePersonID))

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
    for grandchildID in context.graph.children(of: childID).sortedByUUIDString()
    where grandchildID != context.perspectivePersonID {
      guard let grandchild = context.peopleByID[grandchildID] else { continue }
      accumulators[grandchildID]?.addCandidate(
        LabelCandidate(
          inferredLabel: grandchildLabel(for: grandchild.relationshipGender),
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

private func grandchildLabel(for gender: RelationshipGender) -> String {
  switch gender {
  case .male:
    return "孙子"
  case .female:
    return "孙女"
  case .unknown:
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
    return 3
  case .classmate:
    return 4
  case .coworker:
    return 5
  }
}

private let inferredLabelPriority = 6

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
