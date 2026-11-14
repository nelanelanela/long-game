import Testing
import Foundation
@testable import LongGame

// Update 46: Write to us.

@MainActor
private final class FakeMail: MailEnvironment {
    var canSendMail: Bool
    var opens: Bool
    var opened: [URL] = []
    init(canSendMail: Bool, opens: Bool) { self.canSendMail = canSendMail; self.opens = opens }
    func open(_ url: URL) async -> Bool { opened.append(url); return opens }
}

@MainActor
struct WriteToUsTests {
    @Test func theFooterLine() {
        #expect(WriteToUs.footerLine(version: "1.0", build: "42", system: "iOS", systemVersion: "26.1", device: "iPhone17,3")
                == "Long Game 1.0 (42) · iOS 26.1 · iPhone17,3")
        #expect(WriteToUs.body(footer: "F") == "\n\n—\nF")
    }

    @Test func theAddressLivesInOnePlace() {
        #expect(Support.email == "yes@wehavesun.com")
        #expect(Support.subject == "Long Game")
    }

    @Test func theMailtoLink() throws {
        let url = try #require(WriteToUs.mailtoURL(body: "\n\n—\nLong Game 1.0 (1)"))
        #expect(url.scheme == "mailto")
        let parts = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(parts.path == "yes@wehavesun.com")
        #expect(parts.queryItems?.first { $0.name == "subject" }?.value == "Long Game")
        #expect(parts.queryItems?.first { $0.name == "body" }?.value == "\n\n—\nLong Game 1.0 (1)")
        #expect(!url.absoluteString.contains(" "))
    }

    @Test func theMailSheetFirst() async {
        let mail = FakeMail(canSendMail: true, opens: true)
        #expect(await WriteToUs.route(mail, url: WriteToUs.mailtoURL(body: "")) == .mailSheet)
        #expect(mail.opened.isEmpty)
    }

    @Test func thenAMailtoLink() async {
        let mail = FakeMail(canSendMail: false, opens: true)
        #expect(await WriteToUs.route(mail, url: WriteToUs.mailtoURL(body: "")) == .mailto)
        #expect(mail.opened.count == 1)
    }

    @Test func thenCopyingTheAddress() async {
        let mail = FakeMail(canSendMail: false, opens: false)
        #expect(await WriteToUs.route(mail, url: WriteToUs.mailtoURL(body: "")) == .copy)
        #expect(await WriteToUs.route(mail, url: nil) == .copy)
    }
}
