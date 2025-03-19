import Foundation
import UIKit
import WebKit
import NetworkExtension

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
        //                eprint("WebView CALLED \(message.name) WITH \(messageBody)")
        let verb = messageBody[0]
        let args = messageBody[1]  // args is a json-encoded array of strings
        let callback = messageBody[2]
        //                eprint("callback = ", callback)
        do {
          if message.name == "callRpc" {
            switch verb {
            case "start_daemon":
              let res = try start_tunnel(args, try await getManager())
              try await injectSuccess(callback, res)
            case "stop_daemon":

              let manager = try await getManager()
              manager.connection.stopVPNTunnel()

              Task {
                while true {
                  if manager.connection.status == NEVPNStatus.disconnected {
                    do {
                      eprint("callback = ", callback)
                      try await injectSuccess(callback, "")
                    } catch {
                      eprint("OH NO! ", error.localizedDescription)
                    }
                    break
                  } else {
                    try await Task.sleep(nanoseconds: 100_000_000)
                  }
                }
              }

            case "sync":
              let ret = await callBlockingSyncFunc {
                try handle_sync(args)
              }
              try await injectSuccess(callback, ret)
            case "daemon_rpc":
              let res = try await handle_daemon_rpc(args)
              try await injectSuccess(callback, res)
            case "binder_rpc":
              let ret = await callBlockingSyncFunc {
                try handle_binder_rpc(args)
              }
              eprint("binder_rpc before calling inject_success!!!!!")
              try await injectSuccess(callback, ret)
              eprint("binder_rpc successfully called inject_success~~~~~")
            case "export_logs":
              try self.handleExportDebugpack()
              try await injectSuccess(callback, "")
            case "version":
              let version = try handle_version()
              try await injectSuccess(callback, jsonify(version))
            case _:
              throw "invalid rpc input!"
            }
          }
        } catch {
          NSLog("ERROR!! %@", error.localizedDescription)
          try await injectReject(callback, jsonify(error.localizedDescription))
        }
      } else {
        NSLog("cannot parse rpc argument!!")
      }
    }
  }
}

func start_tunnel(_ message: String, _ manager: NETunnelProviderManager) throws -> String {
  eprint("STARTING THE DAEMON!!!")
  //    eprint("The manager looks like this: ", manager)
  let args_map = ["args": NSString(string: message)]
  //    eprint("the connection looks like", manager.connection)
  assert(manager.isEnabled)
  try manager.connection.startVPNTunnel(options: args_map)
  eprint("the vpn started lol\n", manager.connection.status)
  return "\"\""
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
