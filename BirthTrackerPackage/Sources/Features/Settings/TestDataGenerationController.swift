import Localization
import Persistence
import SwiftData

@MainActor
final class TestDataGenerationController: ObservableObject {
  enum Alert: Identifiable {
    case success
    case failure(message: String)

    var id: String {
      switch self {
      case .success: "success"
      case .failure: "failure"
      }
    }
  }

  @Published private(set) var isGenerating = false
  @Published private(set) var isShowingHUD = false
  @Published var alert: Alert?

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

    alert = nil
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
      defer {
        isGenerating = false
        isShowingHUD = false
        generationTask = nil
        hudDelayTask?.cancel()
        hudDelayTask = nil
      }

      do {
        try await generate(modelContext)
        guard !Task.isCancelled else { return }
        guard isViewVisible else { return }
        alert = .success
      } catch is CancellationError {
        // Cancellation is user intent: no success/failure prompt.
      } catch {
        guard isViewVisible else { return }
        let message = L10n.Settings.testDataCreationFailedMessage(error.localizedDescription)
        alert = .failure(message: message)
      }
    }
  }

  func cancel() {
    generationTask?.cancel()
    hudDelayTask?.cancel()
    generationTask = nil
    hudDelayTask = nil
    isGenerating = false
    isShowingHUD = false
  }
}

