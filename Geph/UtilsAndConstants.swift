import Foundation
import NetworkExtension

let CREDENTIAL_CACHE_PATH = path_to("geph-credentials")
let DEBUGPACK_PATH = path_to("geph-debugpack.db")
let EXPORTED_DEBUGPACK_PATH = path_to("geph-debugpack-exported.db")
let DAEMON_RPC_SECRET_PATH_KEY = "daemonRpcSecretPath"
var DAEMON_KEY: Int32 = 0

let defaults = UserDefaults.standard

func path_to(_ filename: String) -> String {
  let fmanager = FileManager.default
  let shared_dir_url = fmanager.containerURL(forSecurityApplicationGroupIdentifier: "group.geph.io")
  return shared_dir_url!.path + "/" + filename
}

// this is so that we can `throw String`
extension String: LocalizedError {
  public var errorDescription: String? { return self }
}

extension Int32: Error {
}

struct StderrOutputStream: TextOutputStream {
  mutating func write(_ string: String) { fputs(string, stderr) }
}

var errStream = StderrOutputStream()

func eprint(_ items: Any..., separator: String = " ", terminator: String = "\n") {
  let str = items.map { String(describing: $0) }.joined(separator: " ")
  print(_: str, separator: separator, terminator: terminator, to: &errStream)
}

func generateRandomString(
  length: Int, characters: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
) -> String {
  let charactersArray = Array(characters)
  return String((0..<length).map { _ in charactersArray.randomElement()! })
}

func get_daemon_rpc_secret() -> String {
  let sharedDefaults = UserDefaults(suiteName: "group.geph.io")
  guard let secret_path = sharedDefaults?.string(forKey: DAEMON_RPC_SECRET_PATH_KEY) else {
    fatalError("daemon-rpc secret path not set!")
  }
  return secret_path
}

func jsonify<T>(_ to_encode: T) throws -> String where T: Encodable {
  let encoder = JSONEncoder()
  let args_data = try encoder.encode(to_encode)
  let encoded = String(data: args_data, encoding: .utf8)!
  return encoded
}

func callBlockingSyncFunc(_ function: @escaping () throws -> String) async -> String {
  return await withCheckedContinuation { continuation in
    DispatchQueue.global(qos: .background).async {
      do {
        let result = try function()
        continuation.resume(returning: result)
      } catch {
        // Handle the error. For example, return a default value or error message.
        // Adjust this according to your needs.
        continuation.resume(returning: "Error: \(error)")
      }
    }
  }
}
