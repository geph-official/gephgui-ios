import Foundation
import UIKit
import WebKit
import NetworkExtension

extension ViewController: WKScriptMessageHandler {
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
              try await self.inject_success(callback, res)
            case "stop_daemon":

              let manager = try await getManager()
              manager.connection.stopVPNTunnel()

              Task {
                while true {
                  if manager.connection.status == NEVPNStatus.disconnected {
                    do {
                      eprint("callback = ", callback)
                      try await self.inject_success(callback, "")
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
              try await inject_success(callback, ret)
            case "daemon_rpc":
              let res = try await handle_daemon_rpc(args)
              try await inject_success(callback, res)
            case "binder_rpc":
              let ret = await callBlockingSyncFunc {
                try handle_binder_rpc(args)
              }
              eprint("binder_rpc before calling inject_success!!!!!")
              try await inject_success(callback, ret)
              eprint("binder_rpc successfully called inject_success~~~~~")
            case "export_logs":
              try self.handle_export_debugpack()
              try await inject_success(callback, "")
            case "version":
              let version = try handle_version()
              try await inject_success(callback, jsonify(version))
            case _:
              throw "invalid rpc input!"
            }
          }
        } catch {
          NSLog("ERROR!! %@", error.localizedDescription)
          try await self.inject_reject(callback, jsonify(error.localizedDescription))
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
