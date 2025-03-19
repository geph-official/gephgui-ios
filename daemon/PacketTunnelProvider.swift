//
//  PacketTunnelProvider.swift
//  daemon
//
//  Created by Eric Dong on 3/22/22.
//

import NetworkExtension
import QuartzCore


class PacketTunnelProvider: NEPacketTunnelProvider {
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        NSLog("TUNNEL STARTED!")
//        Darwin.sleep(5)
        NSLog("DEBUGPACK_PATH = %@", DEBUGPACK_PATH)
        let defaults = UserDefaults.standard
        var args = ""
        // start geph
        // options should be ["args" : "["--username", ...]"],
        // which is a mapping of the string "args" to an NSString,
        // which is a serialized JSON array of args we pass to geph
        
//        Thread.detachNewThread({
//            while(true) {
//                NSLog("still alive!")
//                Thread.sleep(forTimeInterval: TimeInterval(5))
//            }
//        })
        
        if let options_unwrapped = options {
            NSLog("called from gephgui")
            if let rgs = options_unwrapped["args"] {
                args = rgs.description
                defaults.set(rgs.description, forKey: "args")
            }
        } else {
            NSLog("called from settings")
            let rgs = defaults.string(forKey: "args")!
            args = rgs
        }
        
        NSLog("just before starting the geph thread")
        do {
            NSLog("ARGS: %@", args)
            NSLog("about to call geph, wish me luck")
            try start_daemon(args)
        } catch {
            NSLog("Geph returned with error: %@", error.localizedDescription)
        }
        
        // logs loop
//        Thread.detachNewThread({
//            NSLog("STARTED LOGS LOOP")
//            var buffer = [UInt8](repeating: 0, count: 2000)
//            while true {
//
//                let retlen = buffer.withUnsafeMutableBufferPointer { bufferPointer in get_log_line(bufferPointer.baseAddress, 2000)};
//                if retlen < 0 {
//                    NSLog("LOGS RETRIEVAL ERROR!!!")
//                } else {
//                    let msg = String(bytesNoCopy: &buffer, length: Int(retlen), encoding: .utf8, freeWhenDone: false)!
//                    NSLog(msg)
//                }
//            }
//        })
//

        // start packet tunnel
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "1");
        let addresses: [String] = ["123.123.123.123"];
        let subnetMasks: [String] = ["255.255.255.255"];
        settings.ipv4Settings = NEIPv4Settings(addresses: addresses, subnetMasks: subnetMasks);
        settings.ipv4Settings?.includedRoutes = [NEIPv4Route.default()]; // all routes
        //      settings.ipv4Settings?.excludedRoutes = bridges_val.0
        settings.dnsSettings = .init(servers: ["1.1.1.1"])
        settings.mtu = 1450
        
        setTunnelNetworkSettings(settings)
        
        // start vpn!
        completionHandler(nil);
        
        Task {
            NSLog("STARTED UP LOOP")
            while true {
                let (pkts, _) = await self.packetFlow.readPackets();
                for p in pkts {
//                    NSLog("%d", p.count)
                    upload_to_geph(p)
                }
            }
        }
        
        Thread.detachNewThread({
            NSLog("STARTED DOWN LOOP")
            var buffer = [UInt8](repeating: 0, count: 14500);
            let p =  Array(repeating: NSNumber(2), count: 1)
            while true {
                let retlen = download_from_geph(buffer: &buffer)
                if retlen > 0 {
                    autoreleasepool {
                        let toWrite = Data(bytesNoCopy: &buffer, count: Int(retlen), // mallocs 71 bytes
                                           deallocator: Data.Deallocator.none);
//                        let hexString = toWrite.map { String(format: "%02X", $0) }.joined(separator: " ")
//                        NSLog("%@", hexString)
                        self.packetFlow.writePackets([toWrite], withProtocols: p) // mallocs 48 bytes
                    }
                }
            }
        })
    }
    
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        // Add code here to start the process of stopping the tunnel.
        completionHandler()
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // Add code here to handle the message.
        if let handler = completionHandler {
            handler(messageData)
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
