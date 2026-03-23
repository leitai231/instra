@testable import Instra
import Foundation
import Testing

@Suite("OpenAITranslationService")
struct OpenAITranslationServiceTests {
    private static func makeConfiguration() -> TranslationConfiguration {
        TranslationConfiguration(
            apiKey: "sk-test",
            model: "gpt-4.1-mini",
            languageA: "Chinese (Simplified)",
            languageB: "English",
            tone: .natural
        )
    }

    @Test("rejects whitespace-only input")
    func emptyInput() async throws {
        let service = OpenAITranslationService()
        do {
            _ = try await service.translate("   ", configuration: Self.makeConfiguration())
            Issue.record("Expected error to be thrown")
        } catch is TranslationPipelineError {
            // Expected
        }
    }

    @Test("rejects empty string")
    func emptyString() async throws {
        let service = OpenAITranslationService()
        do {
            _ = try await service.translate("", configuration: Self.makeConfiguration())
            Issue.record("Expected error to be thrown")
        } catch is TranslationPipelineError {
            // Expected
        }
    }

    @Test("rejects newlines-only input")
    func newlinesOnly() async throws {
        let service = OpenAITranslationService()
        do {
            _ = try await service.translate("\n\n\n", configuration: Self.makeConfiguration())
            Issue.record("Expected error to be thrown")
        } catch is TranslationPipelineError {
            // Expected
        }
    }
}
