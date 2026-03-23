@testable import Instra
import Testing

@Suite("WhitespaceEnvelope")
struct WhitespaceEnvelopeTests {
    @Test("extracts leading and trailing whitespace")
    func extractLeadingAndTrailing() {
        let envelope = WhitespaceEnvelope.extract(from: "  hello world  ")
        #expect(envelope.leading == "  ")
        #expect(envelope.body == "hello world")
        #expect(envelope.trailing == "  ")
    }

    @Test("handles text with no whitespace")
    func noWhitespace() {
        let envelope = WhitespaceEnvelope.extract(from: "hello")
        #expect(envelope.leading == "")
        #expect(envelope.body == "hello")
        #expect(envelope.trailing == "")
    }

    @Test("handles only whitespace")
    func onlyWhitespace() {
        let envelope = WhitespaceEnvelope.extract(from: "   ")
        #expect(envelope.body == "")
    }

    @Test("handles empty string")
    func emptyString() {
        let envelope = WhitespaceEnvelope.extract(from: "")
        #expect(envelope.leading == "")
        #expect(envelope.body == "")
        #expect(envelope.trailing == "")
    }

    @Test("preserves newlines as whitespace")
    func newlines() {
        let envelope = WhitespaceEnvelope.extract(from: "\nhello\n")
        #expect(envelope.leading == "\n")
        #expect(envelope.body == "hello")
        #expect(envelope.trailing == "\n")
    }

    @Test("rebuild restores original structure")
    func rebuild() {
        let original = "  hello world  "
        let envelope = WhitespaceEnvelope.extract(from: original)
        let rebuilt = envelope.rebuild(with: "你好世界")
        #expect(rebuilt == "  你好世界  ")
    }

    @Test("rebuild with empty body")
    func rebuildEmpty() {
        let envelope = WhitespaceEnvelope.extract(from: "  test  ")
        let rebuilt = envelope.rebuild(with: "")
        #expect(rebuilt == "    ")
    }
}
