import Foundation
import NetworkExtension
import OSLog
import QuartzCore

private let daemonLog = OSLog(subsystem: "geph.io.daemon", category: "PacketTunnel")

private func logPublic(_ message: String, type: OSLogType = .default) {
    os_log("%{public}@", log: daemonLog, type: type, message)
}

class PacketTunnelProvider: NEPacketTunnelProvider {
	override func startTunnel(
		options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void
	) {

        logPublic("TUNNEL STARTED!")
        logPublic("TUNNEL STARTED!")
		
		// start geph5-client
			let config = geph5ClientConfig(start_tunnel_opts: options)
			do {
				try startClient(config)
				logPublic("geph5-client started")
            } catch {
                logPublic("startClient error: \(error.localizedDescription)", type: .error)
                completionHandler(error)
                return
            }
		
		// start packetTunnel
		setPacketTunnelSettings()
		vpnShuffle()
		completionHandler(nil)
	}
	
	override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
		//		logPublic("Received message from app")
		
		do {
			// Parse the incoming message
			if let json = try JSONSerialization.jsonObject(with: messageData, options: [])
				as? [String: String],
			   let rpcRequest = json["daemon_rpc"]
			{
//					logPublic("Processing daemon_rpc request: \(rpcRequest)")
				
				// Call the daemon_rpc function
				let response = try daemonRpc(rpcRequest)
				
				// Return the response
				if let handler = completionHandler {
					if let responseData = response.data(using: .utf8) {
						handler(responseData)
					} else {
						handler(nil)
					}
				}
			} else {
					logPublic("Invalid message format received", type: .error)
				completionHandler?(nil)
			}
		} catch {
				logPublic("Error handling app message: \(error.localizedDescription)", type: .error)
			completionHandler?(nil)
		}
	}
	
	private func setPacketTunnelSettings() {
		let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "1")
		let addresses: [String] = ["123.123.123.123"]
		let subnetMasks: [String] = ["255.255.255.255"]
		settings.ipv4Settings = NEIPv4Settings(addresses: addresses, subnetMasks: subnetMasks)
		settings.ipv4Settings?.includedRoutes = [NEIPv4Route.default()]  // all routes
		settings.dnsSettings = .init(servers: ["1.1.1.1"])
		settings.mtu = 1450
		
		setTunnelNetworkSettings(settings)
	}
	
	private func vpnShuffle() {
		Task {
			await withTaskGroup(of: Void.self) { group in
				// Add UP loop task
				group.addTask {
					while true {
						do {

							let (pkts, _) = await self.packetFlow.readPackets()
							try autoreleasepool {
								for p in pkts {
									try sendPacket(p)
//									logPublic("sent up packet")
								}
							}
							
						} catch {
							logPublic("Error in UP loop: \(error.localizedDescription)", type: .error)
							try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second
						}
					}
				}

				// Add DOWN loop task
				group.addTask {
					let prot = Array(repeating: NSNumber(2), count: 1)
					while true {
						do {
							try  autoreleasepool {
								let pkt = try receivePacket()
								self.packetFlow.writePackets([pkt], withProtocols: prot)
//								logPublic("sent down packet")
							}
						} catch {
							logPublic("Error in DOWN loop: \(error.localizedDescription)", type: .error)
							try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second
						}
					}
				}
			}
		}
	}
	
	override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
		completionHandler()
		
		// Add code here to start the process of stopping the tunnel.
		let req = "{ jsonrpc: \"2.0\", method: \"stop\", params: [], id: 1 }"
		do {
			let _ = try daemonRpc(req)
		} catch {
			logPublic("daemon_rpc(stop) failed with error = \(error.localizedDescription)", type: .error)
		}
	}
	
	override func sleep(completionHandler: @escaping () -> Void) {
		// Add code here to get ready to sleep.
		completionHandler()
	}
	
	override func wake() {
		// Add code here to wake up.
	}
}

// if the VPN is started from the app, returns the config that the main app passed in & saves it to userDefaults
// if the VPN is started from the settings page, retrieves & returns the last saved config from userDefaults
private func geph5ClientConfig(start_tunnel_opts: [String: NSObject]?) -> String {
	let defaults = UserDefaults.standard
	
	if let options_unwrapped = start_tunnel_opts {
		logPublic("Geph started from GUI")
		let config = options_unwrapped["config"]!.description
		
		// save config to userDefaults
		defaults.set(config, forKey: "args")
		
		return config
	} else {
		logPublic("Geph started from Settings")
		let config = defaults.string(forKey: "args")!
		return config
	}
}

// logs "still alive" every `interval` seconds
private func still_alive(_ interval: Int) {
	Thread.detachNewThread({
		while true {
			logPublic("still alive!")
			Thread.sleep(forTimeInterval: TimeInterval(interval))
		}
	})
}
