import Foundation

public struct RelationshipResolution: Equatable, Identifiable, Sendable {
  public var id: UUID { targetPersonID }

  public let targetPersonID: UUID
  public let primaryLabel: String?
  public let additionalLabels: [String]
  public let inferencePaths: [RelationshipInferencePath]
  public let diagnostics: Set<RelationshipResolutionDiagnostic>

  public var hasConflict: Bool {
    diagnostics.contains(.conflict)
  }

  public var hasMissingEndpoint: Bool {
    diagnostics.contains(.missingEndpoint)
  }

  public init(
    targetPersonID: UUID,
    primaryLabel: String? = nil,
    additionalLabels: [String] = [],
    inferencePaths: [RelationshipInferencePath] = [],
    diagnostics: Set<RelationshipResolutionDiagnostic> = []
  ) {
    self.targetPersonID = targetPersonID
    self.primaryLabel = primaryLabel
    self.additionalLabels = additionalLabels
    self.inferencePaths = inferencePaths
    self.diagnostics = diagnostics
  }
}

public struct RelationshipResolverResult: Equatable, Sendable {
  public let resolutions: [RelationshipResolution]
  public let diagnostics: Set<RelationshipResolutionDiagnostic>

  public var hasMissingEndpoint: Bool {
    diagnostics.contains(.missingEndpoint)
  }

  public init(
    resolutions: [RelationshipResolution],
    diagnostics: Set<RelationshipResolutionDiagnostic> = []
  ) {
    self.resolutions = resolutions
    self.diagnostics = diagnostics
  }
}

public enum RelationshipResolutionDiagnostic: Hashable, Sendable {
  case missingEndpoint
  case conflict
}

public enum InferredRelationshipKind: String, Hashable, Sendable {
  case parent
  case child
  case spouse
  case sibling
  case grandparent
  case grandchild
  case parentSibling
  case siblingChild
  case cousin
  case social
}

public enum RelationshipInferencePath: Hashable, Sendable {
  case primaryPreference(factID: UUID)
  case direct(factID: UUID, kind: RelationshipKind)
  case inferred(kind: InferredRelationshipKind, viaPersonIDs: [UUID])
  case social(factID: UUID, kind: RelationshipKind)
}
