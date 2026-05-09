import Localization
import SwiftData
import SwiftUI

#if DEBUG
  extension View {
    func testDataGenerationFeedback(
      _ controller: TestDataGenerationController,
      modelContext: ModelContext
    ) -> some View {
      self
        .overlay {
          if controller.isShowingHUD {
            TestDataGenerationHUD(title: L10n.Settings.creatingTestData) {
              controller.cancel()
            }
          }
        }
        .onAppear {
          controller.onAppear()
        }
        .onDisappear {
          controller.onDisappear()
        }
        .alert(item: feedbackBinding(controller)) { feedback in
          switch feedback {
          case .success:
            return Alert(
              title: Text(L10n.Settings.testDataCreated),
              dismissButton: .default(Text(L10n.Common.ok))
            )
          case .failure(let message):
            return Alert(
              title: Text(L10n.Settings.testDataCreationFailedTitle),
              message: Text(message),
              primaryButton: .default(Text(L10n.Common.retry)) {
                controller.start(modelContext: modelContext)
              },
              secondaryButton: .cancel()
            )
          }
        }
    }

    private func feedbackBinding(_ controller: TestDataGenerationController)
      -> Binding<TestDataGenerationController.Feedback?>
    {
      Binding(
        get: { controller.feedback },
        set: { controller.feedback = $0 }
      )
    }
  }

  private struct TestDataGenerationHUD: View {
    let title: LocalizedStringResource
    let cancel: @MainActor () -> Void

    var body: some View {
      ZStack {
        Color.black.opacity(0.1)
          .ignoresSafeArea()
          .allowsHitTesting(false)

        VStack(spacing: 12) {
          ProgressView(title)
            .multilineTextAlignment(.center)
          Button(L10n.Common.cancel) {
            cancel()
          }
          .buttonStyle(.bordered)
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }
#endif
