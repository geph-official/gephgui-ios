import Foundation
import WebKit
import NetworkExtension

/**
 * NativeGate class that implements the Javascript interface required by the new WebView API
 */
class NativeGate: NSObject, WKScriptMessageHandler {
    weak var viewController: ViewController?
    
    init(viewController: ViewController) {
        self.viewController = viewController
        super.init()
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        // This method will be called when messages are sent from JavaScript
        guard let messageBody = message.body as? [String: Any] else {
            NSLog("Invalid message format from WebView")
            return
        }
        
        Task {
            do {
                let method = messageBody["method"] as! String
                let params = messageBody["params"] as? [Any] ?? []
                let id = messageBody["id"] as! Int
                
                let result = try await handleRpcMethod(method: method, params: params)
                try await injectResponse(id: id, result: result)
            } catch {
                try await injectError(id: messageBody["id"] as! Int, error: error.localizedDescription)
            }
        }
    }
    
    private func handleRpcMethod(method: String, params: [Any]) async throws -> Any {
        NSLog("Handling RPC method: \(method)")
        
        switch method {
        case "start_daemon":
            guard let argsDict = params.first as? [String: Any] else {
                throw "Invalid daemon arguments"
            }
            
            // Convert to DaemonArgs format expected by the new API
            let daemonArgs = try convertToDaemonArgs(argsDict)
            
            // Start the daemon with the new API
            return try await startDaemon(daemonArgs)
            
        case "stop_daemon":
            return try await stopDaemon()
            
        case "is_running":
            return DAEMON_KEY != 0
            
        case "daemon_rpc":
            guard params.count >= 2,
                  let rpcMethod = params[0] as? String,
                  let rpcArgs = params[1] as? [Any] else {
                throw "Invalid daemon_rpc parameters"
            }
            
            return try await callDaemonRpc(method: rpcMethod, args: rpcArgs)
            
        case "price_points":
            // Implement when needed
            return [[30, 5], [60, 10], [365, 50]]
            
        case "create_invoice":
            // Implement when needed  
            throw "Not implemented"
            
        case "pay_invoice":
            // Implement when needed
            throw "Not implemented"
            
        case "sync_app_list":
            // iOS doesn't support app whitelisting
            return []
            
        case "export_debug_pack":
            try handle_export_debugpack()
            return true
            
        case "get_app_icon_url":
            // Not applicable for iOS
            throw "Not applicable on iOS"
            
        case "get_debug_pack":
            return try getDebugLogs()
            
        case "get_native_info":
            return [
                "platform_type": "ios",
                "platform_details": UIDevice.current.systemVersion,
                "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
            ]
            
        default:
            throw "Unsupported method: \(method)"
        }
    }
    
    private func convertToDaemonArgs(_ dict: [String: Any]) throws -> String {
        // Convert the new format to what our daemon expects
        var daemonConfig: [String: Any] = [:]
        
        // Extract and map values from the new format to the old format
        if let username = dict["username"] as? String {
            daemonConfig["username"] = username
        }
        
        if let password = dict["password"] as? String {
            daemonConfig["password"] = password
        }
        
        if let exitHostname = dict["exit_hostname"] as? String {
            daemonConfig["exit_hostname"] = exitHostname
        }
        
        if let forceBridges = dict["force_bridges"] as? Bool {
            daemonConfig["force_bridges"] = forceBridges
        }
        
        // Other parameters as needed
        // ...
        
        // Convert to JSON and return
        let jsonData = try JSONSerialization.data(withJSONObject: [daemonConfig])
        return String(data: jsonData, encoding: .utf8)!
    }
    
    private func startDaemon(_ configJson: String) async throws -> Bool {
        let manager = try await viewController?.getManager() ?? 
            throw "Could not get VPN manager"
        
        try start_tunnel(configJson, manager)
        return true
    }
    
    private func stopDaemon() async throws -> Bool {
        let manager = try await viewController?.getManager() ?? 
            throw "Could not get VPN manager"
        
        manager.connection.stopVPNTunnel()
        
        // Wait for it to disconnect
        while manager.connection.status != .disconnected {
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        return true
    }
    
    private func callDaemonRpc(method: String, args: [Any]) async throws -> Any {
        let jsonData = try JSONSerialization.data(withJSONObject: args)
        let argsString = String(data: jsonData, encoding: .utf8)!
        
        let jsonRequest = "{\"method\":\"\(method)\",\"params\":\(argsString)}"
        
        let response = try await daemon_rpc(jsonRequest)
        
        // Parse the JSON response
        if let data = response.data(using: .utf8),
           let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
           let result = jsonResponse["result"] {
            return result
        } else {
            throw "Invalid response from daemon"
        }
    }
    
    private func handle_export_debugpack() throws {
        guard let viewController = viewController else {
            throw "ViewController is nil"
        }
        
        try handle_debugpack()
        let document_picker = UIDocumentPickerViewController(forExporting: [URL(fileURLWithPath: EXPORTED_DEBUGPACK_PATH)], asCopy: false)
        document_picker.modalPresentationStyle = .overFullScreen
        viewController.present(document_picker, animated: true)
    }
    
    private func getDebugLogs() throws -> String {
        // Implement logic to get debug logs
        return "Geph iOS debug logs"
    }
    
    // Helper methods to communicate with the WebView
    private func injectResponse(id: Int, result: Any) async throws {
        let resultJson = try JSONSerialization.data(withJSONObject: result)
        let resultString = String(data: resultJson, encoding: .utf8)!
        let js = "window.nativeGateCallback(\(id), null, \(resultString))"
        
        try await viewController?.webView.evaluateJavaScript(js)
    }
    
    private func injectError(id: Int, error: String) async throws {
        let escapedError = error.replacingOccurrences(of: "\"", with: "\\\"")
        let js = "window.nativeGateCallback(\(id), \"\(escapedError)\", null)"
        
        try await viewController?.webView.evaluateJavaScript(js)
    }
}