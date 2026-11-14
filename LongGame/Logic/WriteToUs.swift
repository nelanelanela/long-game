import Foundation

/// Where "Write to us" goes. One constant, so it is easy to change.
enum Support {
    static let email = "yes@wehavesun.com"
    static let subject = "Long Game"
}

/// What the device can do to send an email, so the choice can be tested without one.
@MainActor
protocol MailEnvironment {
    /// The Mail compose sheet is available (a Mail account is set up).
    var canSendMail: Bool { get }
    /// Opens a `mailto:` link in the default mail app; false when nothing answered.
    func open(_ url: URL) async -> Bool
}

enum WriteToUs {
    /// "Long Game 1.0 (42) · iOS 26.1 · iPhone17,3": so a bug report comes with context, and nothing else.
    static func footerLine(version: String, build: String, system: String, systemVersion: String, device: String) -> String {
        "Long Game \(version) (\(build)) · \(system) \(systemVersion) · \(device)"
    }

    /// Two empty lines to write in, then a quiet footer.
    static func body(footer: String) -> String { "\n\n—\n\(footer)" }

    static func mailtoURL(body: String, to address: String = Support.email, subject: String = Support.subject) -> URL? {
        var c = URLComponents()
        c.scheme = "mailto"
        c.path = address
        c.queryItems = [URLQueryItem(name: "subject", value: subject), URLQueryItem(name: "body", value: body)]
        // URLComponents leaves "+" alone, which mail apps read as a space; spaces must be %20.
        return c.url
    }

    /// What a tap did.
    enum Route: Equatable, Sendable {
        /// The Mail compose sheet should open.
        case mailSheet
        /// A mail app opened the `mailto:` link.
        case mailto
        /// Nothing could send it: the address was copied ("Email address copied").
        case copy
    }

    /// The order: the Mail sheet, then a `mailto:` link (Gmail or another default mail app), then copying the address.
    @MainActor
    static func route(_ env: MailEnvironment, url: URL?) async -> Route {
        if env.canSendMail { return .mailSheet }
        if let url, await env.open(url) { return .mailto }
        return .copy
    }
}
