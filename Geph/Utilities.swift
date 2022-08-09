//
//  Utilities.swift
//  Geph
//
//  Created by Eric Dong on 8/7/22.
//

import Foundation


func call_geph_wrapper(_ args: String) -> String {
    let result = call_geph(args)
    let swift_result = String(cString: result!)
    // TODO: FREE result
    return swift_result
}

func jsonify(_ args_arr: [String]) throws -> String {
    let encoder = JSONEncoder()
        let args_data = try encoder.encode(args_arr)
        let args_str = String(data: args_data, encoding: .utf8)!
        return args_str
}

struct StderrOutputStream: TextOutputStream {
    mutating func write(_ string: String) { fputs(string, stderr) }
}

var errStream = StderrOutputStream()
func eprint(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    let str = items.map{String(describing: $0)}.joined(separator: " ")
    print(_: str, separator: separator, terminator: terminator, to: &errStream)
}
