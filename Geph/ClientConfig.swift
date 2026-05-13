import Foundation

func defaultConfig() -> [String: Any] {
    let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    let cacheDir = cachesURL.appendingPathComponent("geph.io.app-cache", isDirectory: true)
    try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    
    return [
        "exit_constraint": "auto",
        "allow_direct": false,
        "cache": cacheDir.appendingPathComponent("cache.db").path,
        "broker": [
            "priority_race": [
                "0": [
                    "fronted": [
                        "front": "https://kubernetes.io",
                        "host": "svitania-naidallszei-2.netlify.app"
                    ]
                ],
                    "300": [
                        "fronted": [
                            "front": "https://kubernetes.io/",
                            "host": "svitania-naidallszei-2.netlify.app",
                            "override_dns": ["75.2.60.5:443"]
                        ]
                    ],
                    "1500": [
                        "aws_lambda": [
                            "function_name": "geph-lambda-bouncer",
                            "region": "us-east-1",
                            "obfs_key": "855MJGAMB58MCPJBB97NADJ36D64WM2T:C4TN2M1H68VNMRVCCH57GDV2C5VN6V3RB8QMWP235D0P4RT2ACV7GVTRCHX3EC37",
                        ]
                    ],
            ]
		],
		"broker_keys": [
			"master": "88c1d2d4197bed815b01a22cadfc6c35aa246dddb553682037a118aebfaa3954",
			"mizaru_free": "0558216cbab7a9c46f298f4c26e171add9af87d0694988b8a8fe52ee932aa754",
			"mizaru_plus": "cf6f58868c6d9459b3a63bc2bd86165631b3e916bad7f62b578cd9614e0bcb3b",
			"mizaru_bw": "3082010a0282010100d0ae53a794ea37bf2e100cb3a872177ec6c11e8375fdcbf92960ce0293465674eb1426a1841b7622a58979a5ff3f8aa2301a621545e9b90bb39d1a6bfda19d6ca1aae74a3192ddfd2b9558eb652c3c2c22f42bdde272852fb67d93cae5846213512c474bf799844aee019bf718f6fa64223be06364459fc8dec66796b141d450d730c4fffe1cac7df8f05591560afa44bcf274f6c0e2303b39c21ab09d19b459ee594512b8341f3d407c026e2509f42c6d89f82f6a3a36fd5c05ad423cd99ad39089403eb9122ea60ef6648afff65438e8e26ce41fa55b9b18741965c77a627bae947bd38fc345e9adab42d6c458f6e194e4232cfd3f04924d5a5e932fe769610203010001"
		],
		"vpn": false,
		"vpn_fd": NSNull(),
		"spoof_dns": false,
		"passthrough_china": false,
		"dry_run": true,
		"credentials": [
			"secret": ""
		],
		"sess_metadata": NSNull(),
		"task_limit": NSNull(),
	]
}

func runningConfig(args: [String: Any], cacheDir: String? = nil) -> [String: Any] {
	// Start with the template config
	var cfg = defaultConfig()
	
	// Handle exit constraint
	if let exit = args["exit"] as? [String: Any],
	   let country = exit["country"] as? String,
	   let city = exit["city"] as? String
	{
		cfg["exit_constraint"] = [
			"country_city": [country, city]
		]
	}
	
	// Set session metadata
	if let metadata = args["metadata"] {
		cfg["sess_metadata"] = metadata
	}
	
	// Set other fields
	cfg["dry_run"] = false

	if let allowDirect = args["allow_direct"] as? Bool {
		cfg["allow_direct"] = allowDirect
	}
	
	if let prcWhitelist = args["prc_whitelist"] as? Bool {
		cfg["passthrough_china"] = prcWhitelist
		if prcWhitelist == true {
			cfg["spoof_dns"] = true
		}
	}
	
	if let secret = args["secret"] as? String {
		// Set cache directory
		cfg["cache"] = path_to("cache_\(secret)")
		
		// Set credentials
		cfg["credentials"] = ["secret": secret]
	}
	
	return cfg
}

/// Create an "inert" version of the config that does not start any processes.
func inertConfig(_ config: [String: Any]) -> [String: Any] {
	// Create a mutable copy of the config
	var inertConfig = config
	
	// Modify the config to make it inert
	inertConfig["dry_run"] = true
	inertConfig["control_listen"] = NSNull()
	
	return inertConfig
}

// Example of how to convert the config to JSON data
func configToJsonData(_ config: [String: Any]) -> Data? {
	do {
		return try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted])
	} catch {
		print("Error converting config to JSON: \(error)")
		return nil
	}
}

// Example of how to convert the config to JSON string
func configToJsonString(_ config: [String: Any]) -> String? {
	if let jsonData = configToJsonData(config) {
		return String(data: jsonData, encoding: .utf8)
	}
	return nil
}
