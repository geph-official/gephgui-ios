import NetworkExtension
import QuartzCore

class PacketTunnelProvider: NEPacketTunnelProvider {
	override func startTunnel(
		options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void
	) {
		NSLog("TUNNEL STARTED!")
		
		// start geph5-client
		let config = geph5ClientConfig(start_tunnel_opts: options)
		do {
			try startClient(config)
			NSLog("geph5-client started")
		} catch {
			NSLog("startClient error: %@", error.localizedDescription)
		}
		
		// start packetTunnel
		setPacketTunnelSettings()
		vpnShuffle()
		completionHandler(nil)
	}
	
	override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
		//		NSLog("Received message from app")
		
		do {
			// Parse the incoming message
			if let json = try JSONSerialization.jsonObject(with: messageData, options: [])
				as? [String: String],
			   let rpcRequest = json["daemon_rpc"]
			{
//				NSLog("Processing daemon_rpc request: %@", rpcRequest)
				
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
				NSLog("Invalid message format received")
				completionHandler?(nil)
			}
		} catch {
			NSLog("Error handling app message: %@", error.localizedDescription)
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
//									NSLog("sent up packet")
								}
							}
							
						} catch {
							NSLog("Error in UP loop: %@", error.localizedDescription)
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
//								NSLog("sent down packet")
							}
						} catch {
							NSLog("Error in DOWN loop: %@", error.localizedDescription)
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
			NSLog("daemon_rpc(stop) failed with error = %@", error.localizedDescription)
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
		NSLog("Geph started from GUI")
		let config = options_unwrapped["config"]!.description
		
		// save config to userDefaults
		defaults.set(config, forKey: "args")
		
		return config
	} else {
		NSLog("Geph started from Settings")
		let config = defaults.string(forKey: "args")!
		return config
	}
}

// logs "still alive" every `interval` seconds
private func still_alive(_ interval: Int) {
	Thread.detachNewThread({
		while true {
			NSLog("still alive!")
			Thread.sleep(forTimeInterval: TimeInterval(interval))
		}
	})
}
