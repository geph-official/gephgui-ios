const getRandomName = () => "__callback" + Math.round(Math.random() * 100);

let callingRpc = false
//let is_plus = true

async function callRpc(verb, args) {
    while (callingRpc) {
        await new Promise((r) => setTimeout(r, 200));
    }
    callingRpc = true
    try {
        const prom = new Promise((resolve, reject) => {
            const some_random_name = getRandomName();
            window[some_random_name] = [resolve, reject];
            window.webkit.messageHandlers.callRpc.postMessage([verb, JSON.stringify(args), some_random_name]);
        });
        console.log("about to send out ", verb, "with args ", args);
        let res = await prom;
        console.log("Swift gave us", res);
        return res;
    } catch(e) {
        console.log("CallRpc ERROR!", e)
    }
    finally {
        callingRpc = false
    }
}

window["NATIVE_GATE"] = {
    async start_daemon(params) {
//        if (is_plus) {
            await callRpc("start_daemon", [params]);
            while (true) {
                try {
                    await this.is_connected();
                    break;
                } catch (e) {
                    await new Promise((r) => setTimeout(r, 200));
                }
            }
//        } else throw "iOS testflight only available to Plus users / iOS 测试版目前只对付费用户开放";
    },
    async stop_daemon() {
        //      await this.daemon_rpc("kill", []);
        await callRpc("stop_daemon", []);
    },
    async is_connected() {
        return await this.daemon_rpc("is_connected", []);
    },
    async is_running() {
        try {
            await this.daemon_rpc("is_connected", []);
            return true;
        } catch (e) {
            return false;
        }
    },
    async sync_user_info(username, password) {
        let sync_info = await callRpc("sync", [username, password, false]);
        if (sync_info.user.subscription) {
//            is_plus = true
            return {
                level: sync_info.user.subscription.level.toLowerCase(),
                expires: sync_info.user.subscription
                    ? new Date(sync_info.user.subscription.expires_unix * 1000.0)
                    : null,
            };
        }
        else {
            return { level: "free", expires: null }
//            is_plus = false
//            throw "iOS testflight only available to Plus users / iOS 测试版目前只对付费用户开放";
        }
    },

    async daemon_rpc(method, args) {
        const req = { jsonrpc: "2.0", method: method, params: args, id: 1 };
        const resp = await callRpc("daemon_rpc", [JSON.stringify(req)]);
        if (resp.error) {
            throw resp.error.message;
        }
        return resp.result;
    },

    async binder_rpc(method, args) {
        const req = { jsonrpc: "2.0", method: method, params: args, id: 1 };
        const resp = await callRpc("binder_rpc", [JSON.stringify(req)]);
        if (resp.error) {
            throw resp.error.message;
        }
        return resp.result;
    },
    async sync_exits(username, password) {
        let sync_info = await callRpc("sync", [username, password, false]);
        return sync_info.exits;
    },

    async purge_caches(username, password) {
        await callRpc("sync", [username, password, true]);
    },

    supports_app_whitelist: false,

    sync_app_list: async () => {
        return [];
    },

    get_app_icon_url: async (id) => {
        return "";
    },

    async export_debug_pack() {
        await callRpc("export_logs", []);
    },

    supports_listen_all: false,
    supports_prc_whitelist: false,
    supports_proxy_conf: false,
    supports_vpn_conf: false,
    supports_autoupdate: false,

    async get_native_info() {
        return {
            platform_type: "ios",
            platform_details: "iOS",
            version: await callRpc("version", []),
        };
    },
};




