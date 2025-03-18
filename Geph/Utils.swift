import Foundation
import NetworkExtension
import StoreKit

// MARK: - Path Constants
let CREDENTIAL_CACHE_PATH = path_to("geph-credentials")
let DEBUGPACK_PATH = path_to("geph-debugpack.db")
let EXPORTED_DEBUGPACK_PATH = path_to("geph-debugpack-exported.db")
let DAEMON_RPC_SECRET_PATH_KEY = "daemonRpcSecretPath"
var DAEMON_KEY: Int32 = 0

let defaults = UserDefaults.standard

// MARK: - Path Utilities
func path_to(_ filename: String) -> String {
    let fmanager = FileManager.default
    let shared_dir_url = fmanager.containerURL(forSecurityApplicationGroupIdentifier: "group.geph.io")
    return shared_dir_url!.path + "/" + filename
}

// MARK: - Error Extensions
extension String: LocalizedError {
    public var errorDescription: String? { return self }
}

extension Int32: Error {}

// MARK: - Logging Utilities
struct StderrOutputStream: TextOutputStream {
    mutating func write(_ string: String) { fputs(string, stderr) }
}

var errStream = StderrOutputStream()

func eprint(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    let str = items.map{String(describing: $0)}.joined(separator: " ")
    print(_: str, separator: separator, terminator: terminator, to: &errStream)
}

// MARK: - Random String Generation
func generateRandomString(length: Int, characters: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789") -> String {
    let charactersArray = Array(characters)
    return String((0..<length).map { _ in charactersArray.randomElement()! })
}

// MARK: - Daemon RPC Utilities
func daemon_rpc(_ url_str: String) async throws -> String {
    return try await withCheckedThrowingContinuation { continuation in
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let result = try GephDaemonBridge.daemonRpc(request: url_str)
                continuation.resume(returning: result)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

// MARK: - Starting/Stopping Daemon
func start_tunnel(_ message: String, _ manager: NETunnelProviderManager) throws -> String {
    eprint("STARTING THE DAEMON!!!")
    let args_map = ["args" : NSString(string: message)]
    assert(manager.isEnabled)
    try manager.connection.startVPNTunnel(options: args_map)
    eprint("The VPN started successfully\n", manager.connection.status)
    return "\"\""
}

// MARK: - Debug Pack Handling
func handle_debugpack() throws {
    if DAEMON_KEY == 0 {
        throw "You can only export debugpacks when Geph is connected"
    }
    
    // With the new Geph5 client, we might need to implement a different approach
    // This is a placeholder using the old API for now
    let retcode = debugpack(DAEMON_KEY, EXPORTED_DEBUGPACK_PATH)
    if retcode < 0 {
        throw retcode
    }
}

// MARK: - Sync Handling
func handle_sync(_ message: String) throws -> String {
    let args = try JSONSerialization.jsonObject(with: message.data(using: .utf8)!, options: []) as! [Any]
    let username = args[0] as! String
    let password = args[1] as! String
    let force_flag = args[2] as! Bool
    
    // This function has changed in Geph5, this is a placeholder
    // We need to implement the new approach based on Geph5 client API
    var args_arr = ["sync", "--credential-cache", CREDENTIAL_CACHE_PATH, "auth-password", "--username", username, "--password", password]
    if force_flag {
        args_arr.append("--force")
    }
    
    // This is a placeholder. In the actual implementation, we should use the new Geph5 client API
    // For now, returning empty string to avoid errors
    return "{}"
}

// MARK: - Version Handling
func handle_version() throws -> String {
    // This will need to be updated for Geph5
    // For now, returning a placeholder version
    return "\"5.0.0\""
}