import Foundation

/**
 * Helper to create Geph5 client configuration
 */
struct Geph5Config {
    
    /**
     * Create a default configuration template
     */
    static func defaultConfig() -> [String: Any] {
        return [
            "daemon_mode": true,
            "log_level": "info",
            "sosistab": [
                "protocol": "auto"
            ],
            "exit": nil,
            "listen": [
                "socks5": "127.0.0.1:9909",
                "http": "127.0.0.1:9910",
                "dns_udp": "127.0.0.1:9953"
            ],
            "auth": [
                "type": "free"
            ]
        ]
    }
    
    /**
     * Create a configuration for the Geph5 client from daemon args
     */
    static func fromDaemonArgs(_ daemonArgs: [String: Any]) -> [String: Any] {
        var config = defaultConfig()
        
        // Configure auth
        if let username = daemonArgs["username"] as? String,
           let password = daemonArgs["password"] as? String {
            
            config["auth"] = [
                "type": "account",
                "username": username,
                "password": password
            ]
        }
        
        // Configure exit
        if let exitHostname = daemonArgs["exit_hostname"] as? String {
            config["exit"] = [
                "hostname": exitHostname,
                "use_bridges": daemonArgs["force_bridges"] as? Bool ?? false
            ]
        }
        
        // Additional parameters for VPN mode
        config["vpn"] = [
            "enabled": true,
            "excluded_apps": daemonArgs["app_whitelist"] as? [String] ?? []
        ]
        
        // Configure network settings
        if let listenAll = daemonArgs["listen_all"] as? Bool, listenAll {
            config["listen"] = [
                "socks5": "0.0.0.0:9909",
                "http": "0.0.0.0:9910",
                "dns_udp": "0.0.0.0:9953"
            ]
        }
        
        // Configure protocol if specified
        if let forceProtocol = daemonArgs["force_protocol"] as? String {
            var sosistabConfig = config["sosistab"] as? [String: Any] ?? [:]
            sosistabConfig["protocol"] = forceProtocol
            config["sosistab"] = sosistabConfig
        }
        
        return config
    }
    
    /**
     * Convert config dictionary to JSON string
     */
    static func toJsonString(_ config: [String: Any]) throws -> String {
        let jsonData = try JSONSerialization.data(withJSONObject: config)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw NSError(domain: "geph.io.daemon", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to convert config to JSON string"])
        }
        return jsonString
    }
}