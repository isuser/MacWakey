import Foundation
import Security

/// Accepts XPC connections only from Wakey's own app and widget, signed by the same team as the helper.
final class ListenerDelegate: NSObject, NSXPCListenerDelegate {
    private let service: HelperService
    private let requirement: String?

    init(service: HelperService) {
        self.service = service
        if let team = Self.ownTeamID() {
            requirement = """
            anchor apple generic and certificate leaf[subject.OU] = "\(team)" \
            and (identifier "\(WakeyIDs.app)" or identifier "\(WakeyIDs.widget)")
            """
        } else {
            requirement = nil
            NSLog("Wakey helper: no team ID in own signature; all connections will be rejected.")
        }
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        guard let requirement else { return false }
        connection.setCodeSigningRequirement(requirement)
        connection.exportedInterface = NSXPCInterface(with: WakeyHelperProtocol.self)
        connection.exportedObject = service
        connection.resume()
        return true
    }

    /// Team ID from the helper's own code signature (works for free Apple ID teams too).
    private static func ownTeamID() -> String? {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return nil }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else { return nil }
        var info: CFDictionary?
        guard SecCodeCopySigningInformation(
            staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &info
        ) == errSecSuccess,
            let dict = info as? [String: Any]
        else { return nil }
        return dict[kSecCodeInfoTeamIdentifier as String] as? String
    }
}
