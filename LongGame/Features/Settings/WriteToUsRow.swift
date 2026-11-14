import SwiftUI
#if os(iOS)
import MessageUI
import UIKit
#else
import AppKit
#endif

/// The real device's mail abilities.
@MainActor
struct SystemMail: MailEnvironment {
    var canSendMail: Bool {
        #if os(iOS)
        MFMailComposeViewController.canSendMail()
        #else
        false
        #endif
    }

    func open(_ url: URL) async -> Bool {
        #if os(iOS)
        await UIApplication.shared.open(url)
        #else
        NSWorkspace.shared.open(url)
        #endif
    }

    /// The footer's facts: the real version, build, system and device model.
    static var footer: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        #if os(iOS)
        let system = UIDevice.current.systemName
        let systemVersion = UIDevice.current.systemVersion
        #else
        let system = "macOS"
        let v = ProcessInfo.processInfo.operatingSystemVersion
        let systemVersion = v.patchVersion > 0 ? "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)" : "\(v.majorVersion).\(v.minorVersion)"
        #endif
        return WriteToUs.footerLine(version: version, build: build, system: system, systemVersion: systemVersion, device: modelName)
    }

    /// The model code ("iPhone17,3", "Mac15,3"); in the Simulator, the simulated device's.
    static var modelName: String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] { return simulated }
        #if os(iOS)
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
        #else
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: max(1, size))
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(decoding: model.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
        #endif
    }

    static func copyAddress() {
        #if os(iOS)
        UIPasteboard.general.string = Support.email
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(Support.email, forType: .string)
        #endif
    }
}

/// Help · "Write to us": an envelope in ember on a peach tile, the address and what to write about, a chevron.
struct WriteToUsRow: View {
    /// Shows the app's toast ("Email address copied").
    let onCopied: () -> Void
    @State private var composing = false

    var body: some View {
        Button(action: tap) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LGColor.peachTile)
                    .frame(width: 32, height: 32)
                    .overlay { Image(systemName: "envelope").lgIcon(15, weight: .semibold).foregroundStyle(LGColor.ember) }
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Write to us").lgText(.row)
                    Text("\(Support.email) · questions, ideas, bugs")
                        .lgText(LGTextStyle(size: 12, weight: .regular, relativeTo: .caption), color: LGColor.inkMuted)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").lgIcon(13, weight: .semibold).foregroundStyle(LGColor.inkMuted)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 10)
            .frame(minHeight: 54)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: String(localized: "Write to us") + ", " + Support.email))
        .accessibilityAddTraits(.isButton)
        #if os(iOS)
        .sheet(isPresented: $composing) {
            MailComposer(body: WriteToUs.body(footer: SystemMail.footer)).ignoresSafeArea()
        }
        #endif
    }

    private func tap() {
        let url = WriteToUs.mailtoURL(body: WriteToUs.body(footer: SystemMail.footer))
        Task { @MainActor in
            switch await WriteToUs.route(SystemMail(), url: url) {
            case .mailSheet: composing = true
            case .mailto: break
            case .copy:
                SystemMail.copyAddress()
                Haptics.play(.copied)
                AccessibilityNotification.Announcement(String(localized: "Email address copied")).post()
                onCopied()
            }
        }
    }
}

#if os(iOS)
/// The Mail compose sheet, filled in. Closing it does nothing else (no thank-you screen).
private struct MailComposer: UIViewControllerRepresentable {
    let body: String

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.setToRecipients([Support.email])
        vc.setSubject(Support.subject)
        vc.setMessageBody(body, isHTML: false)
        vc.mailComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        nonisolated func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult,
                                               error: Error?) {
            Task { @MainActor in controller.dismiss(animated: true) }
        }
    }
}
#endif
