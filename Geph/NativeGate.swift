import Foundation
import NetworkExtension
import UIKit
import WebKit
import OSLog

private let nativeGateLog = OSLog(subsystem: "geph.io.app", category: "NativeGate")

extension ViewController: WKScriptMessageHandler {
	// MARK: - JavaScript Interaction
	
	/// Injects success callback into JavaScript
	@MainActor
	func injectSuccess(_ callback: String, _ message: String) async throws {
		let js = "\(callback)[0](\(message)); delete \(callback)"
//		eprint("INJECTING JS", js)
		try await webView.evaluateJavaScript(js)
	}
	
	/// Injects rejection callback into JavaScript
	@MainActor
	func injectReject(_ callback: String, _ message: String) async throws {
		let js = "\(callback)[1](\(message)); delete \(callback)"
		try await webView.evaluateJavaScript(js)
	}
	
	func userContentController(
		_ userContentController: WKUserContentController, didReceive message: WKScriptMessage
	) {
		Task { @MainActor in
			if let messageBody = message.body as? [String] {
//                eprint("WebView CALLED \(message.name) WITH \(messageBody)")
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
							do {
								// first try RPC to the actual daemon
								let resp = try await daemonRpcVPN(args)
//								eprint("background daemonRpc ", args, "; resp = ", resp)
								try await injectSuccess(callback, resp)
							} catch {
								// if that fails, call the dry-run daemon
								let resp = try await foregroundDaemonRpc(args)
//								eprint("foreground daemonRpc ", args, "; resp = ", resp)
								try await injectSuccess(callback, resp)
							}

						case "apple_pay":
                            eprint("$$$$ pay_invoice called $$$$")
							let user_id = Int(args)!
                            try await inAppPurchase(user_id)
							try await injectSuccess(callback, "")

						case "open_browser":
							// `args` is the raw URL string (or a JSON string literal from callers
							// that pass an array element). Open it in the external browser.
							if let url = URL(string: args) {
								_ = await UIApplication.shared.open(url)
							}
							try await injectSuccess(callback, "")

						case "set_exit_constraint":
							// iOS has no in-engine exit switch, so honor a live exit change by
							// restarting the tunnel with the new exit merged into the last args.
							try await setExitConstraint(args)
							try await injectSuccess(callback, "")

						case "debug_logs":
							let logs = fetchAllLogs()
							let encoder = JSONEncoder()
							
							if let jsonData = try? encoder.encode(logs),
							   let jsonString = String(data: jsonData, encoding: .utf8) {
								try await injectSuccess(callback, jsonString)
							}
						case "ios_version":
							let version = UIDevice.current.systemVersion
							try await injectSuccess(callback, jsonify(version))
						case "ios_plus_price":
							let price = try await fetchIosPlusPrice()
							try await injectSuccess(callback, jsonify(price))
						case _:
							throw "invalid rpc input!"
						}
					}
				} catch {
					logPublic(
						"NativeGate Error: \(error.localizedDescription)", type: .error, log: nativeGateLog)
					try await injectReject(callback, jsonify(error.localizedDescription))
				}
			} else {
				logPublic("cannot parse rpc argument!!", type: .error, log: nativeGateLog)
			}
		}
	}
}

func foregroundDaemonRpc(_ args: String) async throws -> String {
	try await Task.detached(priority: .userInitiated) {
		try startClient(configToJsonString(inertConfig(defaultConfig()))!)
		return try daemonRpc(args)
	}.value
}

// Shared storage of the last daemon args (the DaemonArgs JSON the GUI passed to
// start_daemon), so a live exit switch can rebuild the running config. Stored in
// the app-group defaults so it survives an app relaunch while the tunnel is up.
private let lastDaemonArgsKey = "lastDaemonArgs"

private func saveLastDaemonArgs(_ clientArgsJson: String) {
	UserDefaults(suiteName: "group.geph.io")?.set(clientArgsJson, forKey: lastDaemonArgsKey)
}

private func loadLastDaemonArgs() -> String? {
	UserDefaults(suiteName: "group.geph.io")?.string(forKey: lastDaemonArgsKey)
}

// Switch the exit while connected by restarting the tunnel. `exitJson` is the
// ExitConstraint as sent by the GUI: the string "auto" or {"country","city"}.
func setExitConstraint(_ exitJson: String) async throws {
	guard let lastArgs = loadLastDaemonArgs(),
		  let argsData = lastArgs.data(using: .utf8),
		  var argsObject = try JSONSerialization.jsonObject(with: argsData) as? [String: Any]
	else {
		// Nothing running/remembered; the next start_daemon will carry the new
		// exit from the GUI's prefs, so there's nothing to do here.
		return
	}

	// Merge the new exit into the remembered args.
	let exitData = exitJson.data(using: .utf8)!
	argsObject["exit"] = try JSONSerialization.jsonObject(with: exitData, options: [.fragmentsAllowed])

	let updatedJson = String(
		data: try JSONSerialization.data(withJSONObject: argsObject), encoding: .utf8)!

	// Only restart if the tunnel is actually up; otherwise just remember it.
	let manager = try await getManager()
	if manager.connection.status == .connected {
		try await stopTunnel()
		try await startTunnel(updatedJson)
	} else {
		saveLastDaemonArgs(updatedJson)
	}
}

// returns when VpnTunnel is fully connected
func startTunnel(_ clientArgsJson: String) async throws {
	eprint("starting the NetworkExtension")
	saveLastDaemonArgs(clientArgsJson)
	let manager = try await getManager()
	assert(manager.isEnabled)
	
	// assemble config for geph5-client
	let jsonData = clientArgsJson.data(using: .utf8)!
	let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any]
	let config = runningConfig(args: jsonObject!)
//	eprint("geph5ClientConfig: \n", config)
	let configStr = configToJsonString(config)!
	
	// start VpnTunnel
	let args_map = ["config": NSString(string: configStr)]
	try manager.connection.startVPNTunnel(options: args_map)
	
	// wait for VpnTunnel to connect
    let deadline = ContinuousClock.now + .seconds(60)

    while ContinuousClock.now < deadline {
        if manager.connection.status == .connected {
            return
        } else {
            try await Task.sleep(for: .milliseconds(100))
        }
    }
    throw "Timed out waiting for VPN tunnel to connect"
}

// returns when VpnTunnel is fully stopped
func stopTunnel() async throws {
    let manager = try await getManager()
    
    // prevents undefined behavior caused by trying to stop a tunnel already in teardown
    if manager.connection.status == .connected {
        manager.connection.stopVPNTunnel()
        
        let deadline = ContinuousClock.now + .seconds(60)
        while ContinuousClock.now < deadline {
            if manager.connection.status == .disconnected {
                return
            } else {
                try await Task.sleep(for: .milliseconds(100))
            }
        }
        throw "Timed out waiting for VPN tunnel to disconnect"
    }
}

/// Runs an async operation with a deadline. If the deadline passes first, throws;
/// the losing operation is left to finish in the background (its result is discarded).
func withDeadline<T: Sendable>(seconds: Double, _ op: @escaping @Sendable () async throws -> T)
	async throws -> T
{
	try await withThrowingTaskGroup(of: T.self) { group in
		group.addTask { try await op() }
		group.addTask {
			try await Task.sleep(for: .seconds(seconds))
			throw "timed out after \(seconds)s"
		}
		let result = try await group.next()!
		group.cancelAll()
		return result
	}
}

/// Sends an RPC request to the daemon via VPN extension and returns the response
/// - Parameter args: JSON-RPC request string
/// - Returns: Response string from the daemon
/// - Throws: Error message if the RPC request fails
func daemonRpcVPN(_ args: String) async throws -> String {
	let manager = try await getManager()
	guard let session = manager.connection as? NETunnelProviderSession,
		  session.status == .connected else {
		throw "VPN tunnel is not connected"
	}

	// Create message data with the command and arguments
	let messageData = try JSONSerialization.data(withJSONObject: ["daemon_rpc": args], options: [])

	// A session can report .connected while the extension is dead or wedged (e.g.
	// after an unclean extension exit). Without a deadline, every RPC in the
	// startup storm hangs inside sendProviderMessage and the whole GUI stalls;
	// with one, we degrade to the in-process fallback after 2s.
	return try await withDeadline(seconds: 2.0) {
		try await withCheckedThrowingContinuation { continuation in
			do {
				// Send the message to the provider and handle the response in the callback
				try session.sendProviderMessage(messageData) { responseData in
					if let responseData = responseData {
						if let responseString = String(data: responseData, encoding: .utf8) {
							continuation.resume(returning: responseString)
						} else {
							continuation.resume(throwing: "Failed to decode response data")
						}
					} else {
						continuation.resume(throwing: "No response received from provider")
					}
				}
			} catch {
				continuation.resume(throwing: error)
			}
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
		if !man.isEnabled {
			man.isEnabled = true
			try await man.saveToPreferences()
		}
		return man
	}
}

func fetchAllLogs() -> String {
	var logOutput = ""
	
	do {
		// Access the log store for the current process
		let logStore = try OSLogStore(scope: .currentProcessIdentifier)
		
		// Retrieve log entries from the beginning of log store
		let entries = try logStore.getEntries()
		
		// Iterate through the entries and build the log string
		for entry in entries {
			if let logEntry = entry as? OSLogEntryLog {
				logOutput += "\(logEntry.date): \(logEntry.composedMessage)\n"
			}
		}
	} catch {
		logOutput += "Error accessing logs: \(error)\n"
	}
	return logOutput
}
