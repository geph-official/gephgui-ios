import Foundation

func defaultConfig() -> [String: Any] {
	return [
		"exit_constraint": "auto",
		"bridge_mode": "Auto",
		"cache": NSNull(),
		"broker": [
			"race": [
				// 1) First fronted
				[
					"fronted": [
						"front": "https://www.cdn77.com/",
						"host": "1826209743.rsc.cdn77.org",
					]
				],
				// 2) Second fronted
				[
					"fronted": [
						"front": "https://vuejs.org/",
						"host": "svitania-naidallszei-2.netlify.app",
					]
				],
				// No aws lambda for iOS b/c aws Rust dependency is too hard to compile
			]
		],
		"broker_keys": [
			"master": "88c1d2d4197bed815b01a22cadfc6c35aa246dddb553682037a118aebfaa3954",
			"mizaru_free": "0558216cbab7a9c46f298f4c26e171add9af87d0694988b8a8fe52ee932aa754",
			"mizaru_plus": "cf6f58868c6d9459b3a63bc2bd86165631b3e916bad7f62b578cd9614e0bcb3b",
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
