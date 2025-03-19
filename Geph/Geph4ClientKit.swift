import Foundation

func handle_sync(_ message: String) throws -> String {
    "todo"
//  let args =
//    try JSONSerialization.jsonObject(with: message.data(using: .utf8)!, options: []) as! [Any]
//  let username = args[0] as! String
//  let password = args[1] as! String
//  let force_flag = args[2] as! Bool
//
//  var args_arr = [
//    "sync", "--credential-cache", CREDENTIAL_CACHE_PATH, "auth-password", "--username", username,
//    "--password", password,
//  ]
//  if force_flag {
//    args_arr.append("--force")
//  }
//  let args_str = String(decoding: try JSONEncoder().encode(args_arr), as: UTF8.self).cString(
//    using: .utf8)!
//  let buflen = 1024 * 128
//  var buffer = [CChar](repeating: 0, count: buflen)
//
//  let retcode = args_str.withUnsafeBufferPointer { argsPtr in
//    buffer.withUnsafeMutableBufferPointer { bufferPtr in
//      geph_sync(argsPtr.baseAddress, bufferPtr.baseAddress, Int32(buflen))
//    }
//  }
//  if retcode < 0 {
//    eprint("sync returned an error! retcode = ", retcode)
//    throw retcode
//  } else {
//    let data = Data(bytes: buffer, count: Int(retcode))
//    let retstr = String(decoding: data, as: UTF8.self)
//    // save uid to defaults
//    let uid = try extractUserID(from: retstr)
//    defaults.set(uid, forKey: "uid")
//
//    return retstr
//  }
}

func extractUserID(from jsonString: String) throws -> Int32 {
//  guard let jsonData = jsonString.data(using: .utf8) else {
//    throw "Invalid data: Unable to convert string to Data"
//  }
//
//  do {
//    guard
//      let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: [])
//        as? [String: Any]
//    else {
//      throw "Type mismatch: Root object is not a JSON dictionary"
//    }
//
//    guard let user = jsonObject["user"] as? [String: Any] else {
//      throw "Missing key: 'user'"
//    }
//
//    guard let userid = user["userid"] as? Int32 else {
//      throw "Type mismatch: 'userid' is not an Int32"
//    }
//
//    return userid
//  } catch {
//    throw "Serialization error: \(error.localizedDescription)"
//  }
    0
}

func handle_binder_rpc(_ message: String) throws -> String {
//  let args = try JSONDecoder().decode([String].self, from: message.data(using: .utf8)!)
//  guard let line = args.first?.cString(using: .utf8) else {
//    throw "invalid input"
//  }
//  let buflen = 1024 * 128
//  var buffer = [CChar](repeating: 0, count: buflen)
//
//  //    let retcode = binder_rpc(line, &buffer, Int32(buflen))
//  eprint(line)
//  let retcode = line.withUnsafeBufferPointer { linePtr in
//    buffer.withUnsafeMutableBufferPointer { bufferPtr in
//      binder_rpc(linePtr.baseAddress, bufferPtr.baseAddress, Int32(buflen))
//    }
//  }
//
//  if retcode < 0 {
//    eprint("binder_rpc returned an error: \(retcode)")
//    throw retcode
//  } else if retcode > buflen {
//    throw "buffer overflow"
//  } else {
//    let data = Data(bytes: buffer, count: Int(retcode))
//    return String(decoding: data, as: UTF8.self)
//  }
    "todo"
}

func handle_daemon_rpc(_ message: String) async throws -> String {
//  let args =
//    try JSONSerialization.jsonObject(with: message.data(using: .utf8)!, options: []) as! [String]
//  let line = args[0]
//
//  let secret_path = get_daemon_rpc_secret()
//  let url_str = "http://127.0.0.1:9809/" + secret_path
//  // eprint("DAEMON_RPC_URL = ", url_str)
//  var request = URLRequest(
//    url: URL(string: url_str)!,
//    cachePolicy: .reloadIgnoringLocalCacheData
//  )
//  request.httpMethod = "POST"
//  request.httpBody = Data(line.utf8)
//  let (data, response, error): (Data?, URLResponse?, Error?) = await withCheckedContinuation {
//    continuation in
//    URLSession.shared.dataTask(
//      with: request,
//      completionHandler: { data, resp, err in
//        continuation.resume(returning: (data, resp, err))
//      }
//    ).resume()
//  }
//  if error != nil {
//    throw error!
//  }
//  //    eprint("got response", data, response);
//  guard (response as? HTTPURLResponse)?.statusCode == 200 else {
//    throw "Error fetching response in daemon rpc!"
//  }
//  let resp = String(decoding: data!, as: UTF8.self)
//  // eprint("DAEMON_RPC req = ", line, "resp = ", resp)
//  return resp
    "todo"
}

func handle_version() throws -> String {
//  let buflen = 1024 * 10
//  var buffer = [CChar](repeating: 0, count: buflen)
//  let retcode = version(&buffer, Int32(buflen))
//  if retcode < 0 {
//    throw retcode
//  } else {
//    let data = Data(bytes: buffer, count: Int(retcode))
//    return String(decoding: data, as: UTF8.self)
//  }
    "todo"
}

func handle_debugpack() throws {
//  if DAEMON_KEY == 0 {
//    throw "You can only export debugpacks when Geph is connected"
//  }
//  let retcode = debugpack(DAEMON_KEY, EXPORTED_DEBUGPACK_PATH)
//  if retcode < 0 {
//    throw retcode
//  }
}

func start_daemon(_ args_json_str: String) throws {
//  let start_opt = try make_start_opt(args_json_str)
//  NSLog("Starting DAEMON!")
//  let daemon_rpc_secret = get_daemon_rpc_secret()
//
//  // Set RUST_MIN_STACK to 512 KB (512 * 1024 = 524288 bytes)
//  setenv("RUST_MIN_STACK", "131072", 1)
//
//  let retcode = start(start_opt, daemon_rpc_secret)
//  if retcode < 0 {
//    NSLog("Start daemon returned an error! Retcode = %@", retcode)
//    throw retcode
//  } else {
//    NSLog("Start daemon succeeded <3<3<3<3")
//    DAEMON_KEY = retcode
//  }
}

// message is a json-encoded array containing one DaemonArgs object
func make_start_opt(_ message: String) throws -> String {
//  let json =
//    try JSONSerialization.jsonObject(with: message.data(using: .utf8)!, options: [])
//    as! [[String: Any]]
//  let connect_info = json[0]
//
//  var args_arr = ["connect"]
//  args_arr.append("--exit-server")
//  args_arr.append(connect_info["exit_hostname"]! as! String)
//
//  //    if connect_info["use_tcp"]! as! Bool {
//  //        args_arr.append("--use-tcp")
//  //    }
//
//  if connect_info["force_bridges"]! as! Bool {
//    args_arr.append("--use-bridges")
//  }
//
//  args_arr.append("--debugpack-path")
//  args_arr.append(DEBUGPACK_PATH)
//
//  args_arr.append("--credential-cache")
//  args_arr.append(CREDENTIAL_CACHE_PATH)
//
//  args_arr.append("auth-password")
//  args_arr.append("--username")
//  args_arr.append(connect_info["username"]! as! String)
//
//  args_arr.append("--password")
//  args_arr.append(connect_info["password"]! as! String)
//
//  return try jsonify(args_arr)
    "todo"
}

//uploads a single packet to geph
func upload_to_geph(_ p: Data) {
    var pkt = [UInt8](p)
    //    let start_time = CACurrentMediaTime();
//    send_vpn(DAEMON_KEY, &pkt, Int32(pkt.count))
    //    let end_time = CACurrentMediaTime();
    //    NSLog("upload took %g ms", 1000.0 * (end_time - start_time))
}

//downloads a single packet from geph
func download_from_geph(buffer: inout [UInt8]) -> Int32 {
//    var retlen = Int32(0)
//    let buflen = buffer.count;
//    buffer.withUnsafeMutableBytes({bufferPointer in
//        retlen = recv_vpn(DAEMON_KEY, bufferPointer.baseAddress, Int32(buflen))
//    })
    
//    return retlen
    0
}
