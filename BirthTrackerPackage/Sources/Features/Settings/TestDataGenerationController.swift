import Localization
import Observation
import Persistence
import SwiftData

@MainActor
@Observable
final class TestDataGenerationController {
  enum Feedback: Identifiable {
    case success
    case failure(message: String)

    var id: String {
      switch self {
      case .success: "success"
      case .failure: "failure"
      }
    }
  }

  private(set) var isGenerating = false
  private(set) var isShowingHUD = false
  var feedback: Feedback?

  private var isViewVisible = false
  private var generationTask: Task<Void, Never>?
  private var hudDelayTask: Task<Void, Never>?
  private let hudDelay: Duration
  private let generate: @MainActor (ModelContext) async throws -> Void

  init(
    hudDelay: Duration = .milliseconds(300),
    generate: @escaping @MainActor (ModelContext) async throws -> Void = { modelContext in
      try await TestDataGenerator.generateSamplePeople(into: modelContext)
    }
  ) {
    self.hudDelay = hudDelay
    self.generate = generate
  }

  func onAppear() {
    isViewVisible = true
  }

  func onDisappear() {
    isViewVisible = false
    cancel()
  }

  func start(modelContext: ModelContext) {
    guard !isGenerating else { return }

    feedback = nil
    isGenerating = true
    isShowingHUD = false

    hudDelayTask?.cancel()
    hudDelayTask = Task { @MainActor in
      try? await Task.sleep(for: hudDelay)
      guard !Task.isCancelled, isGenerating else { return }
      isShowingHUD = true
    }

    generationTask?.cancel()
    generationTask = Task { @MainActor in
      let nextFeedback: Feedback?

      do {
        try await generate(modelContext)
        nextFeedback = Task.isCancelled || !isViewVisible ? nil : .success
      } catch is CancellationError {
        // Cancellation is user intent: no success/failure prompt.
        nextFeedback = nil
      } catch {
        if isViewVisible {
          let message = L10n.Settings.testDataCreationFailedMessage(error.localizedDescription)
          nextFeedback = .failure(message: message)
        } else {
          nextFeedback = nil
        }
      }

      finishGeneration()
      feedback = nextFeedback
    }
  }

  func cancel() {
    generationTask?.cancel()
    hudDelayTask?.cancel()
    finishGeneration()
  }

  private func finishGeneration() {
    hudDelayTask?.cancel()
    generationTask = nil
    hudDelayTask = nil
    isGenerating = false
    isShowingHUD = false
  }
}
