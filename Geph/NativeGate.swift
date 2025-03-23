import Foundation
import NetworkExtension
import UIKit
import WebKit

extension ViewController: WKScriptMessageHandler {
  // MARK: - JavaScript Interaction

  /// Injects success callback into JavaScript
  func injectSuccess(_ callback: String, _ message: String) async throws {
    let js = "\(callback)[0](\(message)); delete \(callback)"
    try await webView.evaluateJavaScript(js)
  }

  /// Injects rejection callback into JavaScript
  func injectReject(_ callback: String, _ message: String) async throws {
    let js = "\(callback)[1](\(message)); delete \(callback)"
    try await webView.evaluateJavaScript(js)
  }

  func userContentController(
    _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
  ) {
    Task {
      if let messageBody = message.body as? [String] {
        eprint("WebView CALLED \(message.name) WITH \(messageBody)")
        let verb = messageBody[0]
        let args = messageBody[1]  // args is a json string
        let callback = messageBody[2]

        do {
          if message.name == "callRpc" {
            switch verb {
            case "start_daemon":
              try await startTunnel(args)
              try await injectSuccess(callback, "")

            case "stop_daemon":
              try await stopTunnel()
              try await injectSuccess(callback, "")

            case "daemon_rpc":
              // First try connecting via TCP
              do {
                let resp = try await daemonRpcVPN(args)
                try await injectSuccess(callback, resp)
              } catch {
                let resp = try daemonRpc(args)
                try await injectSuccess(callback, resp)
              }

            case "pay_invoice":
              let user_id = Int(args)!
              inAppPurchase(user_id)
              try await injectSuccess(callback, "")

            case _:
              throw "invalid rpc input!"
            }
          }
        } catch {
          NSLog("NativeGate Error: %@", error.localizedDescription)
          try await injectReject(callback, jsonify(error.localizedDescription))
        }
      } else {
        NSLog("cannot parse rpc argument!!")
      }
    }
  }
}

// Helper function to jsonify error messages
func jsonify(_ message: String) -> String {
  let data = try! JSONSerialization.data(withJSONObject: message, options: [])
  return String(data: data, encoding: .utf8)!
}

func startTunnel(_ clientArgsJson: String) async throws {
  eprint("starting the NetworkExtension")
  let manager = try await getManager()
  assert(manager.isEnabled)

  // assemble config for geph5-client
  let jsonData = clientArgsJson.data(using: .utf8)!
  let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any]
  let config = runningConfig(args: jsonObject!)
  eprint("geph5ClientConfig: \n", config)
  let configStr = configToJsonString(config)!

  // start VPNTunnel
  let args_map = ["config": NSString(string: configStr)]
  try manager.connection.startVPNTunnel(options: args_map)

  eprint("NetworkExtension started:\n", manager.connection.status)
}

func stopTunnel() async throws {
  let manager = try await getManager()
  manager.connection.stopVPNTunnel()

  // wait for VPNTunnel to fully die
  while true {
    if manager.connection.status == NEVPNStatus.disconnected {
      return
    } else {
      try await Task.sleep(nanoseconds: 100_000_000)
    }
  }
}

func getManager() async throws -> NETunnelProviderManager {
  let managers = try await NETunnelProviderManager.loadAllFromPreferences()
  if managers.isEmpty {
    let manager = NETunnelProviderManager()
    manager.localizedDescription = "geph-daemon"
    let proto = NETunnelProviderProtocol()
    // WARNING: This must match the bundle identifier of the app extension containing packet tunnel provider.
    proto.providerBundleIdentifier = "geph.io.daemon"
    proto.serverAddress = "geph"
    manager.protocolConfiguration = proto
    try await manager.loadFromPreferences()
    manager.isEnabled = true
    try await manager.saveToPreferences()
    try await manager.loadFromPreferences()
    return manager
  } else {
    let man = managers[0]
    man.isEnabled = true
    try await man.saveToPreferences()
    return man
  }
}
