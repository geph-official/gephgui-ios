import NetworkExtension
import QuartzCore


class PacketTunnelProvider: NEPacketTunnelProvider {
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        NSLog("TUNNEL STARTED!")
		// get config
		let config = geph5ClientConfig(start_tunnel_opts: options);
		
		// start geph5-client
        do {
            NSLog("CONFIG: %@", config)
            try startClient(config)
        } catch {
            NSLog("startClient error: %@", error.localizedDescription)
        }

        // start packet tunnel
		setPacketTunnelSettings();
        
        // start vpn!
        completionHandler(nil);
        
		// shuffle pkts in & out of Geph
		vpnShuffle();
    }
	
	private func setPacketTunnelSettings() {
		let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "1");
		let addresses: [String] = ["123.123.123.123"];
		let subnetMasks: [String] = ["255.255.255.255"];
		settings.ipv4Settings = NEIPv4Settings(addresses: addresses, subnetMasks: subnetMasks);
		settings.ipv4Settings?.includedRoutes = [NEIPv4Route.default()]; // all routes
		settings.dnsSettings = .init(servers: ["1.1.1.1"]);
		settings.mtu = 1450;
		
		setTunnelNetworkSettings(settings);
	}
	
	private func vpnShuffle() {
		Task {
			while true {
				let (pkts, _) = await self.packetFlow.readPackets();
				for p in pkts {
//                    NSLog("%d", p.count)
					try sendPacket(p)
				}
			}
		}
	
		Thread.detachNewThread {
			let prot = Array(repeating: NSNumber(2), count: 1)
			while true {
				do {
					let pkt = try receivePacket();
					let _ = autoreleasepool {
						self.packetFlow.writePackets([pkt], withProtocols: prot)
					}
				} catch {
					NSLog("receivePacket() failed with error: %@", error.localizedDescription)
				}
				
			}
		}
//		Thread.detachNewThread({
//			NSLog("STARTED DOWN LOOP")
//			var buffer = [UInt8](repeating: 0, count: 14500);
//			let p =  Array(repeating: NSNumber(2), count: 1)
//			while true {
//				let retlen = download_from_geph(buffer: &buffer)
//				if retlen > 0 {
//					autoreleasepool {
//						let toWrite = Data(bytesNoCopy: &buffer, count: Int(retlen), // mallocs 71 bytes
//										   deallocator: Data.Deallocator.none);
////                        let hexString = toWrite.map { String(format: "%02X", $0) }.joined(separator: " ")
////                        NSLog("%@", hexString)
//						self.packetFlow.writePackets([toWrite], withProtocols: p) // mallocs 48 bytes
//					}
//				}
//			}
//		})
	}
    
//    
//    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
//        // Add code here to start the process of stopping the tunnel.
//        completionHandler()
//    }
//    
//    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
//        // Add code here to handle the message.
//        if let handler = completionHandler {
//            handler(messageData)
//        }
//    }
//    
//    override func sleep(completionHandler: @escaping () -> Void) {
//        // Add code here to get ready to sleep.
//        completionHandler()
//    }
//    
//    override func wake() {
//        // Add code here to wake up.
//    }
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
		while(true) {
			NSLog("still alive!")
			Thread.sleep(forTimeInterval: TimeInterval(interval))
		}
	})
}
