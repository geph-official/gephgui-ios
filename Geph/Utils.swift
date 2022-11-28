//
//  connect_binder_proxy.swift
//  geph
//
//  Created by Eric Dong on 3/26/22.
//

import Foundation
import NetworkExtension

// this is so that we can `throw String`
extension String: LocalizedError {
    public var errorDescription: String? { return self }
}

func call_geph_wrapper(_ fun: String, _ args: [String]) throws -> String {
    let args_data = String(decoding: try JSONEncoder().encode(args), as: UTF8.self)
    let buflen = 1024 * 128
    var buffer = [UInt8](repeating: 0, count: buflen)
    let retcode = call_geph(fun, args_data, &buffer, Int32(buflen))
    
    let data = Data(buffer.prefix(Int(retcode)))
    let data_str = String(decoding: data, as: UTF8.self)
    eprint("thing that is supposed to be JSON:", data_str)
    if retcode < 0 {
        throw data_str
    } else {
        return data_str
    }
}

func jsonify<T>(_ to_encode: T) throws -> String where T: Encodable {
    let encoder = JSONEncoder()
        let args_data = try encoder.encode(to_encode)
        let encoded = String(data: args_data, encoding: .utf8)!
        return encoded
}

struct StderrOutputStream: TextOutputStream {
    mutating func write(_ string: String) { fputs(string, stderr) }
}

var errStream = StderrOutputStream()
func eprint(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    let str = items.map{String(describing: $0)}.joined(separator: " ")
    print(_: str, separator: separator, terminator: terminator, to: &errStream)
}

func handle_start_daemon(_ message: String, _ manager: NETunnelProviderManager) throws -> String {
    eprint("STARTING THE DAEMON!!!")
//    eprint("The manager looks like this: ", manager)
    let args = try parse_connect_msg(message)
    eprint(args)
    let args_map = ["args" : NSArray(array: args)]
    
//    eprint("the connection looks like", manager.connection)
    assert(manager.isEnabled)
    try manager.connection.startVPNTunnel(options: args_map)
    eprint("the vpn started lol\n", manager.connection.status)
    return ""
}

// message is a json-encoded array containing one DaemonArgs object
func parse_connect_msg(_ message: String) throws -> [String] {
    let json = try JSONSerialization.jsonObject(with: message.data(using: .utf8)!, options: []) as! [[String : Any]]
    let connect_info = json[0]
    var args_arr = ["--username"]
    let username = connect_info["username"]! as! String
    args_arr.append(username)
    
    args_arr.append("--password")
    let password = connect_info["password"]! as! String
    args_arr.append(password)
    
    args_arr.append("--exit-server")
    let exit_name = connect_info["exit_hostname"]! as! String
    args_arr.append(exit_name)

//    let use_tcp = connect_info["use_tcp"]! as! Bool
//    if use_tcp {
//        args_arr.append("--use-tcp")
//    }
    
    let use_bridges = connect_info["force_bridges"]! as! Bool
    if use_bridges {
        args_arr.append("--use-bridges")
    }
    return args_arr
}

func handle_sync(_ message: String) throws -> String {
    let args = try JSONSerialization.jsonObject(with: message.data(using: .utf8)!, options: []) as! [Any]
    let username = args[0] as! String
    let password = args[1] as! String
    let force_flag = args[2] as! Bool
    var args_arr = ["--username", username, "--password", password]
    if force_flag {
        args_arr.append("--force")
    }
    let ret = try call_geph_wrapper("sync", args_arr)
    return ret
}

func handle_binder_rpc(_ message: String) throws -> String {
    let args = try JSONDecoder().decode([String].self, from: message.data(using: .utf8)!)
    return try call_geph_wrapper("binder_rpc", args)
}