function getRandomName() {
    return "__callback" + Math.round(Math.random() * 100000000);
}

// let callingRpc = false

async function callRpc(verb, args_json) {
    // while (callingRpc) {
    //     await new Promise((r) => setTimeout(r, 200));
    // }
    // callingRpc = true
    try {
        const prom = new Promise((resolve, reject) => {
            const callback = getRandomName();
            window[callback] = [resolve, reject];
            window.webkit.messageHandlers.callRpc.postMessage([verb, args_json, callback]);
        });
        console.log("about to send out ", verb, "with args ", args_json);
        let res = await prom;
        console.log("Swift gave us", res);
        return res;
    } catch (e) {
        console.log("CallRpc ERROR!", e)
    }
    // finally {
    //     callingRpc = false
    // }
}

window["NATIVE_GATE"] = {
    async start_daemon(daemon_args) {
        await callRpc("start_daemon", JSON.stringify(daemon_args));
    },

    async restart_daemon(daemon_args) {
        await callRpc("restart_daemon", daemon_args);
    },

    async stop_daemon() {
        await this.daemon_rpc("stop", []);
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

    async price_points() {
        let resp = [[30, 5]];
        console.log(`PRICE_POINTS = ${resp}`)
        return resp;
    },

    async create_invoice(secret, days) {
        return {
            id: JSON.stringify([secret, days]),
            methods: ["apple-pay"],
        };
    },

    async pay_invoice(id, method) {
        try {
            console.log(`Going to pay invoice ${id} with method ${method}`);
            // Parse the id to extract secret and days
            const [secret, days] = JSON.parse(id);

            // Call daemon_rpc to get the user_id
            const account_status = await this.daemon_rpc("user_info", [secret]);
            const user_id = account_status.user_id.toString();
            console.log(`for user_id = ${user_id}`);

            // Call Swift
            const resp = await callRpc("pay_invoice", user_id)
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
        // todo: call daemon_rpc
    },

    async get_debug_pack() {
        // todo: call daemon_rpc
        // return await callRpc("get_debug_logs", []);
    },

    // Properties required by the interface
    supports_listen_all: false,
    supports_app_whitelist: false,
    supports_prc_whitelist: false,
    supports_proxy_conf: false,
    supports_vpn_conf: false,
    supports_autoupdate: false,

    async get_native_info() {
        return {
            platform_type: "android",
            platform_details: "Android",
            version: getiOSVersion(),
        };
    },
};

function getiOSVersion() {
    var ua = navigator.userAgent;
    var match = ua.match(/OS (\d+)_(\d+)_?(\d+)?/);
    if (match) {
        var major = parseInt(match[1], 10);
        var minor = parseInt(match[2], 10);
        var patch = parseInt(match[3] || '0', 10);
        return [major, minor, patch].join('.');
    }
    return undefined;
}
