//
//  connect_binder_proxy.swift
//  geph
//
//  Created by Eric Dong on 3/26/22.
//

import Foundation
import NetworkExtension


func start_daemon(_ message: String, _ manager: NETunnelProviderManager) -> String {
    eprint("Yoyoyoyo STARTING THE DAEMON!!!")
    eprint("The manager looks like this: ", manager)
    
    let args = parse_message(message)
    eprint(args)
    let args_obj = args as NSString
    let args_map = ["args" : args_obj]
    
    
    do {
        eprint("the connection looks like", manager.connection)
        assert(manager.isEnabled)
        try manager.connection.startVPNTunnel(options: args_map)
        
        Thread.detachNewThread({
            while manager.connection.status != NEVPNStatus.connected {
                eprint("connecting...")
                eprint(manager.connection.status)
                Thread.sleep(forTimeInterval: TimeInterval(5))
                do {
                    try manager.connection.startVPNTunnel(options: args_map)
                } catch {
                    eprint("OH NO i DIEEEED!", error.localizedDescription)
                }
            }
        })
        
        eprint("the vpn started lol")
        eprint(manager.connection.status)
        return ""
    } catch {
        eprint("OH NO i DIEEEED!", error.localizedDescription)
        return error.localizedDescription
    }
}


func stop_daemon(_ manager : NETunnelProviderManager) {
    manager.connection.stopVPNTunnel()
}


func parse_message(_ message: String) -> String {
    do {
        if let connect_info = try JSONSerialization.jsonObject(with: message.data(using: .utf8)!, options: []) as? [[String : Any]] {
            let connect_info = connect_info[0]
            var args_arr = ["geph4-client", "connect", "--username"]
            let username = connect_info["username"]! as! String
            args_arr.append(username)
            
            args_arr.append("--password")
            let password = connect_info["password"]! as! String
            args_arr.append(password)
            
            args_arr.append("--exit-server")
            let exit_name = connect_info["exit_name"]! as! String
            args_arr.append(exit_name)
        
            let use_tcp = connect_info["use_tcp"]! as! Bool
            if use_tcp {
                args_arr.append("--use-tcp")
            }
            
            let use_bridges = connect_info["force_bridges"]! as! Bool
            if use_bridges {
                args_arr.append("--use-bridges")
            }
            
            let exclude_prc = connect_info["exclude_prc"]! as! Bool
            if exclude_prc {
                args_arr.append("--exclude-prc")
            }

            let listen_all = connect_info["listen_all"]! as! Bool
            if listen_all {
                args_arr.append("--socks5-listen")
                args_arr.append("0.0.0.0:9909")
                args_arr.append("--http-listen")
                args_arr.append("0.0.0.0:9910")
            }

//            args_arr.append("--stats-listen")
//            args_arr.append("0.0.0.0:9809")

//            args_arr.append("--sticky-bridges")
            
            let ret = try jsonify(args_arr)
            return ret
        }
    } catch {
        return error.localizedDescription
    }
    return "could not parse input"
}
