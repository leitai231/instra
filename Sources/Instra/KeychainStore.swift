import Foundation
import Security

struct KeychainStore {
    enum KeychainError: LocalizedError {
        case unexpectedStatus(OSStatus)
        case invalidEncoding

        var errorDescription: String? {
            switch self {
            case .unexpectedStatus(let status):
                return "Keychain operation failed with status \(status)."
            case .invalidEncoding:
                return "Stored keychain data could not be decoded as UTF-8."
            }
        }
    }

    func load(service: String, account: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw KeychainError.invalidEncoding
            }
            guard let value = String(data: data, encoding: .utf8) else {
                throw KeychainError.invalidEncoding
            }
            return value
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func save(_ value: String, service: String, account: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var createQuery = query
            createQuery[kSecValueData as String] = data
            let createStatus = SecItemAdd(createQuery as CFDictionary, nil)
            guard createStatus == errSecSuccess else {
                throw KeychainError.unexpectedStatus(createStatus)
            }
        default:
            throw KeychainError.unexpectedStatus(updateStatus)
        }
    }

    func delete(service: String, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}
