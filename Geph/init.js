function getRandomName() {
	return "__callback" + Math.round(Math.random() * 100000000);
}

// let callingRpc = false

async function callRpc(verb, args_json) {
	// while (callingRpc) {
	//     await new Promise((r) => setTimeout(r, 200));
	// }
	// callingRpc = true
	const callback = getRandomName();
	try {
		const prom = new Promise((resolve, reject) => {
			window[callback] = [resolve, reject];
			window.webkit.messageHandlers.callRpc.postMessage([verb, args_json, callback]);
		});
		console.log("about to send out ", verb, "with args ", args_json);
		let res = await prom;
		console.log("Swift gave us", res);
		return res;
	} catch (e) {
		console.log("CallRpc ERROR!", e);
        throw e;
	}
    finally {
        delete window[callback];
    }
}

window["NATIVE_GATE"] = {
	async start_daemon(daemon_args) {
		await callRpc("start_daemon", JSON.stringify(daemon_args));
	},
	
	async restart_daemon(daemon_args) {
        await callRpc("stop_daemon", "");
		await callRpc("start_daemon", JSON.stringify(daemon_args));
	},
	
	async stop_daemon() {
		await callRpc("stop_daemon", "")
	},
	
	async is_running() {
		try {
			return (await this.daemon_rpc("conn_info", [])).state !== "Disconnected";
		} catch (e) {
			return false;
		}
	},
	
	async daemon_rpc(method, args) {
		const req = { jsonrpc: "2.0", method: method, params: args, id: 1 };
		const resp = await callRpc("daemon_rpc", JSON.stringify(req));
		if (resp.error) {
			throw resp.error.message;
		}
		return resp.result;
	},

	async start_native_payment(secret) {
		try {
			// Call daemon_rpc to get the user_id
			const account_status = await this.daemon_rpc("broker_rpc", ["get_user_info_by_cred", [{"secret": secret}]]);
			const user_id = account_status.user_id.toString();
			console.log(`start_native_payment for user_id = ${user_id}`);
			
			// Call Swift. only Unlimited Plus exists on iOS
			const resp = await callRpc("apple_pay", user_id)
		} catch (e) {
			throw String(e);
		}
	},

	async get_ios_plus_price() {
		try {
			return await callRpc("ios_plus_price", "");
		} catch (e) {
			throw String(e);
		}
	},
	
	async sync_app_list() {
		// no split tunneling on iOS
		return [];
	},
	
	async get_app_icon_url(id) {
		// no split tunneling on iOS
		return [];
	},
	
	async export_debug_pack(email) {
		const debug_pack = await this.get_debug_pack();
		console.log(`${debug_pack}`)
		await this.daemon_rpc("export_debug_pack", [email, debug_pack]);
	},
	
	async get_debug_pack() {
		const daemon_logs = await this.daemon_rpc("recent_logs", []);
		const joined_daemon_logs = daemon_logs.join('\n');
//		
//		console.log(`daemon_logs = ${joined_daemon_logs}`)
//		const gui_logs = await callRpc("debug_logs", "");
//		
//		const logs =
//`===== DAEMON =====
//  
//${joined_daemon_logs}
//
//===== GUI =====
//
//${gui_logs}`;
		const logs = joined_daemon_logs;
		return logs;
	},
	
	// Properties required by the interface
supports_listen_all: false,
supports_app_whitelist: false,
supports_prc_whitelist: false,
supports_proxy_conf: false,
supports_vpn_conf: false,
supports_autoupdate: false,
	
	async get_native_info() {
		const ios_version = await getiOSVersion();
		const info = {
			platform_type: "ios",
			platform_details: ios_version,
			version: "5.7.0",
		};
		console.log("get_native_info", info);
		return info;
	},
};

async function getiOSVersion() {
	try {
		const version = await callRpc("ios_version", "");
		if (version) {
			console.log("getiOSVersion native", version);
			return version;
		}
	} catch (e) {
		console.log("getiOSVersion native error", e);
	}
	var ua = navigator.userAgent;
	console.log("UA =", ua);
	var match = ua.match(/OS (\d+)_(\d+)_?(\d+)?/);
	if (match) {
		var major = parseInt(match[1], 10);
		var minor = parseInt(match[2], 10);
		var patch = parseInt(match[3] || '0', 10);
		console.log("getiOSVersion", { major: major, minor: minor, patch: patch });
		return [major, minor, patch].join('.');
	}
	console.log("getiOSVersion no match", ua);
	return undefined;
}
