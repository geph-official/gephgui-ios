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
        let defaults = UserDefaults.standard
        var args = ""
        // start geph
        // options should be ["args" : "["--username", ...]"],
        // which is a mapping of the string "args" to an NSString,
        // which is a serialized JSON array of args we pass to geph
        
                Thread.detachNewThread({
                    while(true) {
                        NSLog("still alive!")
                        Thread.sleep(forTimeInterval: TimeInterval(5))
                    }
                })

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
        Thread.detachNewThread({
            do {
                NSLog("ARGS: %@", args)
                NSLog("about to call geph, wish me luck")
                let decoded_args = try JSONDecoder().decode([String].self, from: args.description.data(using: .utf8)!)
                let res = try call_geph_wrapper("start_daemon", decoded_args)
                NSLog("Geph returned?! %@", res)
            } catch {
                NSLog("Geph returned with error: %@", error.localizedDescription)
            }
        })
        
        // logs loop
        Thread.detachNewThread({
            NSLog("STARTED LOGS LOOP")
            
            var buffer = [UInt8](repeating: 0, count: 2000)
            while true {
                let len = logs_from_geph(buffer: &buffer)
                if len > 0 {
                    let msg = String(bytesNoCopy: &buffer, length: len, encoding: .utf8, freeWhenDone: false)!
                    NSLog(msg)
                }
            }
        })
        
//        // call get_bridges in a loop until we have the list of bridges
//        var bridges_val = get_bridges_wrapper()
//        while bridges_val.1 <= 2 {             // NOTE: an empty array of bridges has length 2, not 0
//            NSLog("no bridges yet")
//            Thread.sleep(forTimeInterval: 1)
//
//            bridges_val = get_bridges_wrapper()
//            if bridges_val.1 == -1 {
//                NSLog("error getting bridges! error!")
//            }
//        }
//        NSLog("got bridges! %@", bridges_val.0)

        // start packet tunnel
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "1");
        let addresses: [String] = ["123.123.123.123"];
        let subnetMasks: [String] = ["255.255.255.255"];
        settings.ipv4Settings = NEIPv4Settings(addresses: addresses, subnetMasks: subnetMasks);
        settings.ipv4Settings?.includedRoutes = [NEIPv4Route.default()]; // all routes
//      settings.ipv4Settings?.excludedRoutes = bridges_val.0
        settings.dnsSettings = .init(servers: ["1.1.1.1"])
        settings.mtu = 1280
        
        setTunnelNetworkSettings(settings)
        
        // start vpn!
        completionHandler(nil);

//        // packets up loop
//        Task {
//            NSLog("STARTED UP LOOP")
//            while true {
//                let (pkts, _) = await self.packetFlow.readPackets();
//                for p in pkts {
//                    upload_to_geph(p)
//                }
//            }
//        }
//
//        // packets down loop
//        Thread.detachNewThread({
//            NSLog("STARTED DOWN LOOP")
//            var buffer = [UInt8](repeating: 0, count: 2000);
//            let p =  Array(repeating: NSNumber(2), count: 1)
//            while true {
//                let retlen = download_from_geph(buffer: &buffer)
//                
//                if retlen > 0 {
//                    autoreleasepool {
//                        let toWrite = Data(bytesNoCopy: &buffer, count: Int(retlen), // mallocs 71 bytes
//                                       deallocator: Data.Deallocator.none);
//                        self.packetFlow.writePackets([toWrite], withProtocols: p) // mallocs 48 bytes
//                    }
//                }
//            }
//        })
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



// helpers
//func get_bridges_wrapper() -> ([NEIPv4Route], Int) {
//    let buflen = 2000
//    var buffer = [UInt8](repeating: 0, count: buflen)
//    let retlen = check_bridges(&buffer, Int32(buflen))
//
//    if retlen <= 0 {
//        return ([], 0)
//    } else {
//        let data = Data(buffer.prefix(Int(retlen)))
//        let decoder = JSONDecoder()
//        let ret = try! decoder.decode([String].self, from: data)
//        let finalret = ret.map({x in NEIPv4Route.init(destinationAddress: x, subnetMask: "255.255.255.255")})
//        return (finalret, Int(retlen))
//    }
//}

//uploads a single packet to geph
func upload_to_geph(_ p: Data) {
    var pkt = [UInt8](p)
//    let start_time = CACurrentMediaTime();
    upload_packet(&pkt, Int32(pkt.count))
//    let end_time = CACurrentMediaTime();
//    NSLog("upload took %g ms", 1000.0 * (end_time - start_time))
}

//downloads a single packet from geph
func download_from_geph(buffer: inout [UInt8]) -> Int32 {
    var retlen = Int32(0)
    let buflen = buffer.count;
    retlen = download_packet(&buffer, Int32(buflen))
    
    return retlen
}

//downloads a single packet from geph
//func try_download_from_geph() -> Data {
//    let buflen = 2000
//    var buffer = [UInt8](repeating: 0, count: buflen)
//    let retlen = try_download_packet(&buffer, Int32(buflen))
//
//    if retlen < 0 {
//        let data = Data.init()
//        return data
//    }
//    var data = Data.init();
//    autoreleasepool {
//        data = Data(buffer.prefix(Int(retlen)))
//    }
//    return data
//}

// gets logs from geph
func logs_from_geph(buffer: inout [UInt8]) -> Int {
    let retlen = get_logs(&buffer, Int32(buffer.count))
    if retlen < 0 {
        NSLog("LOGS RETRIEVAL ERROR!!!")
        return 0
    }
    return Int(retlen)
}

// reference: https://developer.apple.com/forums/thread/99399
