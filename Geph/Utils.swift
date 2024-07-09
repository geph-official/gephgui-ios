import Foundation
import NetworkExtension
import StoreKit


let CREDENTIAL_CACHE_PATH = path_to("geph-credentials");
let DEBUGPACK_PATH = path_to("geph-debugpack.db");
let EXPORTED_DEBUGPACK_PATH = path_to("geph-debugpack-exported.db");
let DAEMON_RPC_SECRET_PATH_KEY = "daemonRpcSecretPath";
var DAEMON_KEY: Int32 = 0;

let defaults = UserDefaults.standard;


func path_to(_ filename: String) -> String {
    let fmanager = FileManager.default
    let shared_dir_url = fmanager.containerURL(forSecurityApplicationGroupIdentifier: "group.geph.io")
    return shared_dir_url!.path + "/" + filename
}

// this is so that we can `throw String`
extension String: LocalizedError {
    public var errorDescription: String? { return self }
}

extension Int32: Error {
}

struct StderrOutputStream: TextOutputStream {
    mutating func write(_ string: String) { fputs(string, stderr) }
}

var errStream = StderrOutputStream()

func eprint(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    let str = items.map{String(describing: $0)}.joined(separator: " ")
    print(_: str, separator: separator, terminator: terminator, to: &errStream)
}

func generateRandomString(length: Int, characters: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789") -> String {
    let charactersArray = Array(characters)
    return String((0..<length).map { _ in charactersArray.randomElement()! })
}

func get_daemon_rpc_secret() -> String {
    let sharedDefaults = UserDefaults(suiteName: "group.geph.io")
    guard let secret_path = sharedDefaults?.string(forKey: DAEMON_RPC_SECRET_PATH_KEY) else {
        fatalError("daemon-rpc secret path not set!")
    }
    return secret_path
}

func start_tunnel(_ message: String, _ manager: NETunnelProviderManager) throws -> String {
    eprint("STARTING THE DAEMON!!!")
    //    eprint("The manager looks like this: ", manager)
    let args_map = ["args" : NSString(string: message)]
    //    eprint("the connection looks like", manager.connection)
    assert(manager.isEnabled)
    try manager.connection.startVPNTunnel(options: args_map)
    eprint("the vpn started lol\n", manager.connection.status)
    return "\"\""
}

func handle_sync(_ message: String) throws -> String {
    let args = try JSONSerialization.jsonObject(with: message.data(using: .utf8)!, options: []) as! [Any]
    let username = args[0] as! String
    let password = args[1] as! String
    let force_flag = args[2] as! Bool
    
    var args_arr = ["sync", "--credential-cache", CREDENTIAL_CACHE_PATH, "auth-password", "--username", username, "--password", password]
    if force_flag {
        args_arr.append("--force")
    }
    let args_str = String(decoding: try JSONEncoder().encode(args_arr), as: UTF8.self).cString(using: .utf8)!
    let buflen = 1024 * 128
    var buffer = [CChar](repeating: 0, count: buflen)
    
    let retcode = args_str.withUnsafeBufferPointer { argsPtr in
        buffer.withUnsafeMutableBufferPointer { bufferPtr in
            geph_sync(argsPtr.baseAddress, bufferPtr.baseAddress, Int32(buflen))
        }
    }
    if retcode < 0 {
        eprint("sync returned an error! retcode = ", retcode)
        throw retcode
    } else {
        let data = Data(bytes: buffer, count: Int(retcode))
        let retstr = String(decoding: data, as: UTF8.self)
        // save uid to defaults
        let uid = try extractUserID(from: retstr)
        defaults.set(uid, forKey: "uid")
      
        return retstr
    }
}

func extractUserID(from jsonString: String) throws -> Int32 {
    guard let jsonData = jsonString.data(using: .utf8) else {
        throw "Invalid data: Unable to convert string to Data"
    }
    
    do {
        guard let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] else {
            throw "Type mismatch: Root object is not a JSON dictionary"
        }
        
        guard let user = jsonObject["user"] as? [String: Any] else {
            throw "Missing key: 'user'"
        }
        
        guard let userid = user["userid"] as? Int32 else {
            throw "Type mismatch: 'userid' is not an Int32"
        }
        
        return userid
    } catch {
        throw "Serialization error: \(error.localizedDescription)"
    }
}

func handle_binder_rpc(_ message: String) throws -> String {
    let args = try JSONDecoder().decode([String].self, from: message.data(using: .utf8)!)
    guard let line = args.first?.cString(using: .utf8) else {
        throw "invalid input"
    }
    let buflen = 1024 * 128
    var buffer = [CChar](repeating: 0, count: buflen)

//    let retcode = binder_rpc(line, &buffer, Int32(buflen))
    eprint(line)
    let retcode = line.withUnsafeBufferPointer { linePtr in
        buffer.withUnsafeMutableBufferPointer { bufferPtr in
            binder_rpc(linePtr.baseAddress, bufferPtr.baseAddress, Int32(buflen))
        }
    }

    if retcode < 0 {
        eprint("binder_rpc returned an error: \(retcode)")
        throw retcode
    } else if retcode > buflen {
        throw "buffer overflow"
    } else {
        let data = Data(bytes: buffer, count: Int(retcode))
        return String(decoding: data, as: UTF8.self)
    }
}


func handle_daemon_rpc(_ message: String) async throws -> String {
    let args = try JSONSerialization.jsonObject(with: message.data(using: .utf8)!, options: []) as! [String]
    let line = args[0]
    
    let secret_path = get_daemon_rpc_secret()
    let url_str = "http://127.0.0.1:9809/" + secret_path
    eprint("DAEMON_RPC_URL = ", url_str)
    var request = URLRequest(
        url: URL(string: url_str)!,
        cachePolicy: .reloadIgnoringLocalCacheData
    )
    request.httpMethod = "POST"
    request.httpBody = Data(line.utf8)
    let (data, response, error) : (Data?, URLResponse?, Error?) = await withCheckedContinuation { continuation in
        URLSession.shared.dataTask(with: request, completionHandler: { data, resp, err in
            continuation.resume(returning: (data, resp, err))
        }).resume()
    }
    if (error != nil) {
        throw error!
    }
    //    eprint("got response", data, response);
    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
        throw "Error fetching response in daemon rpc!"
    }
    let resp = String(decoding: data!, as: UTF8.self)
    eprint("DAEMON_RPC req = ", line, "resp = ", resp)
    return resp
}

func handle_version() throws -> String {
    let buflen = 1024 * 10
    var buffer = [CChar](repeating: 0, count: buflen)
    let retcode = version(&buffer, Int32(buflen));
    if retcode < 0 {
        throw retcode
    } else {
        let data = Data(bytes: buffer, count: Int(retcode))
        return String(decoding: data, as: UTF8.self)
    }
}

func handle_debugpack() throws {
    if DAEMON_KEY == 0 {
        throw "You can only export debugpacks when Geph is connected"
    }
    let retcode = debugpack(DAEMON_KEY, EXPORTED_DEBUGPACK_PATH);
    if retcode < 0 {
        throw retcode
    }
}

func start_daemon(_ args_json_str: String) throws {
    let start_opt = try make_start_opt(args_json_str)
    NSLog(start_opt)
    let daemon_rpc_secret = get_daemon_rpc_secret()
    
    let retcode = start(start_opt, daemon_rpc_secret);
    if retcode < 0 {
        NSLog("Start daemon returned an error! Retcode = %@", retcode)
        throw retcode
    } else {
        NSLog("Start daemon succeeded <3<3<3<3")
        DAEMON_KEY = retcode;
    }
}

// message is a json-encoded array containing one DaemonArgs object
func make_start_opt(_ message: String) throws -> String {
    let json = try JSONSerialization.jsonObject(with: message.data(using: .utf8)!, options: []) as! [[String : Any]]
    let connect_info = json[0]
    
    var args_arr = ["connect"]
    args_arr.append("--exit-server")
    args_arr.append(connect_info["exit_hostname"]! as! String)
    
    //    if connect_info["use_tcp"]! as! Bool {
    //        args_arr.append("--use-tcp")
    //    }
    
    if connect_info["force_bridges"]! as! Bool {
        args_arr.append("--use-bridges")
    }
    
    args_arr.append("--debugpack-path")
    args_arr.append(DEBUGPACK_PATH)
    
    args_arr.append("--credential-cache")
    args_arr.append(CREDENTIAL_CACHE_PATH)
    
    args_arr.append("auth-password")
    args_arr.append("--username")
    args_arr.append(connect_info["username"]! as! String)
    
    args_arr.append("--password")
    args_arr.append(connect_info["password"]! as! String)
    
    return try jsonify(args_arr)
}

func jsonify<T>(_ to_encode: T) throws -> String where T: Encodable {
    let encoder = JSONEncoder()
    let args_data = try encoder.encode(to_encode)
    let encoded = String(data: args_data, encoding: .utf8)!
    return encoded
}

let productIdentifier = "1_mo_renewing"
var product: Product?

func fetchProduct() {
    Task {
        eprint("GONNNA FETCH PRODUCT")
        do {
            let products = try await Product.products(for: [productIdentifier])
            eprint("FETCHED PRODUCTS for: ", productIdentifier)
            eprint(products)
            if let fetchedProduct = products.first {
                product = fetchedProduct
                eprint("fetched product!", fetchedProduct)
            }
        } catch {
            eprint("Failed to fetch the product: ", error)
        }
    }
}

var hasSubscription: Bool?
func fetchHasSubscription() {
    Task {
        guard let verificationResult = await Transaction.latest(for: productIdentifier) else {
            // The user hasn't purchased this product.
            hasSubscription = false
            return
        }
        switch verificationResult {
        case .verified(let transaction):
            // Check the expiration date to determine if the subscription is still active.
            if let expiryDate = transaction.expirationDate, Date() < expiryDate {
                // The current date is before the expiration date, so the subscription is active.
                hasSubscription = true
            } else {
                // The subscription has expired or there's no expiration date available.
                hasSubscription = false
            }
            
        case .unverified(_, _):
            // Unverified transactions are treated as if the user does not have an active subscription.
            // You might want to handle this differently based on your business model.
            hasSubscription = false
        }
    }
}

func inapp_purchase() {
    NSLog("inapp_purchase!")
    guard let product = product else {
        NSLog("no product...")
        return
    }
    Task {
        do {
            let uid = defaults.value(forKey: "uid") as! Int32
//            eprint("UID!!!!!!", uid);
            let uuid = encodeInt32ToUUID(uid);
            
            let result = try await product.purchase(options: [
                .appAccountToken(uuid)
            ])
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    // Transaction verified successfully
                    // pop up wait up to 10 min modal
                    eprint("TRANSACTION: ", transaction)
                    await transaction.finish()
                case .unverified(let transaction, let verificationError):
                    // Transaction verification failed
                    print("Transaction verification failed: \(verificationError)")
                    await transaction.finish()
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            print("Failed to purchase: \(error)")
        }
    }
}

func encodeInt32ToUUID(_ value: Int32) -> UUID {
    var bytes = [UInt8](repeating: 0, count: 16)
    // Place the Int32 value into the first 4 bytes of the UUID
    withUnsafeBytes(of: value.bigEndian) { buffer in
        for (index, byte) in buffer.enumerated() {
            bytes[index] = byte
        }
    }
    return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7], bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
}

func decodeUUIDToInt32(_ uuid: UUID) -> Int32 {
    let bytes = withUnsafePointer(to: uuid.uuid) { ptr -> [UInt8] in
        let ptr = ptr.withMemoryRebound(to: UInt8.self, capacity: 16) { $0 }
        return [UInt8](UnsafeBufferPointer(start: ptr, count: 16))
    }
    // Extract the first 4 bytes to reconstruct the Int32 value
    return bytes[0...3].withUnsafeBytes { $0.load(as: Int32.self).bigEndian }
}

