//
//  sync.swift
//  geph
//
//  Created by Eric Dong on 3/26/22.
//

import Foundation


enum SyncStatus : Codable {
    case Pending
    case Error(String)
    case Done(String)
}

let lock = NSLock();
var sync_global_obj = SyncStatus.Pending;


func handle_start_sync_status(_ message: String) -> Int {
//  eprint(sync_global_obj)
    Thread.detachNewThread({ () -> () in
        lock.lock()
        defer {lock.unlock()}
        sync_global_obj = sync_status(message)
    //  eprint(sync_global_obj)
    })
    return 1 // dummy value
}


func handle_check_sync_status(_ message: String) -> SyncStatus {
    lock.lock()
    let ret = sync_global_obj
    lock.unlock()
    return ret
}


func sync_status(_ message: String) -> SyncStatus {
    do {
        if let sync_info = try JSONSerialization.jsonObject(with: message.data(using: .utf8)!, options: []) as? [Any] {
            var args_arr = ["geph4-client", "sync", "--username"]
            if let uname = sync_info[0] as? String {
                args_arr.append(uname)
            }
            
            args_arr.append("--password")
            if let pswd = sync_info[1] as? String {
                args_arr.append(pswd)
            }
            if let force = sync_info[2] as? Bool {
                if force {
                    args_arr.append("--force")
                }
            }
            
            let encoder = JSONEncoder()
            do {
                let args_str = try jsonify(args_arr)
                return SyncStatus.Done(call_geph_wrapper(args_str))
            }
            catch {
                return SyncStatus.Error(error.localizedDescription)
            }
        }
    }
    catch {
        return SyncStatus.Error(error.localizedDescription)
    }
    return SyncStatus.Pending
}
