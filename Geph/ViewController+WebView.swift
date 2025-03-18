import Foundation
import WebKit

extension ViewController {
    
    func setupWebView() {
        let configs = WKWebViewConfiguration()
        configs.setValue(true, forKey: "_allowUniversalAccessFromFileURLs")
        
        // Setup user content controller for JS->Swift communication
        let userContentController = WKUserContentController()
        let nativeGate = NativeGate(viewController: self)
        
        // Add a script message handler to handle messages from the WebView
        userContentController.add(nativeGate, name: "nativeGate")
        
        // Add bootstrap script to inject the NativeGate object
        let script = WKUserScript(
            source: """
            window.NATIVE_GATE = {
                _callNative: function(method, params) {
                    return new Promise((resolve, reject) => {
                        const id = Math.floor(Math.random() * 1000000);
                        window.nativeGateCallbacks = window.nativeGateCallbacks || {};
                        window.nativeGateCallbacks[id] = {resolve, reject};
                        
                        window.webkit.messageHandlers.nativeGate.postMessage({
                            method: method,
                            params: params,
                            id: id
                        });
                    });
                },
                
                start_daemon: function(args) {
                    return this._callNative('start_daemon', [args]);
                },
                
                restart_daemon: function(args) {
                    return this._callNative('restart_daemon', [args]);
                },
                
                stop_daemon: function() {
                    return this._callNative('stop_daemon', []);
                },
                
                is_running: function() {
                    return this._callNative('is_running', []);
                },
                
                daemon_rpc: function(method, args) {
                    return this._callNative('daemon_rpc', [method, args]);
                },
                
                price_points: function() {
                    return this._callNative('price_points', []);
                },
                
                create_invoice: function(secret, days) {
                    return this._callNative('create_invoice', [secret, days]);
                },
                
                pay_invoice: function(id, method) {
                    return this._callNative('pay_invoice', [id, method]);
                },
                
                sync_app_list: function() {
                    return this._callNative('sync_app_list', []);
                },
                
                export_debug_pack: function(email) {
                    return this._callNative('export_debug_pack', [email]);
                },
                
                get_app_icon_url: function(id) {
                    return this._callNative('get_app_icon_url', [id]);
                },
                
                get_debug_pack: function() {
                    return this._callNative('get_debug_pack', []);
                },
                
                get_native_info: function() {
                    return this._callNative('get_native_info', []);
                }
            };
            
            // Callback function to be called from native code
            window.nativeGateCallback = function(id, error, result) {
                const callback = window.nativeGateCallbacks[id];
                if (callback) {
                    if (error) {
                        callback.reject(error);
                    } else {
                        callback.resolve(result);
                    }
                    delete window.nativeGateCallbacks[id];
                }
            };
            
            // Platform capability properties
            window.NATIVE_GATE.supports_listen_all = true;
            window.NATIVE_GATE.supports_app_whitelist = false;
            window.NATIVE_GATE.supports_prc_whitelist = true;
            window.NATIVE_GATE.supports_proxy_conf = true;
            window.NATIVE_GATE.supports_vpn_conf = true;
            window.NATIVE_GATE.supports_autoupdate = false;
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        
        userContentController.addUserScript(script)
        configs.userContentController = userContentController
        
        // Create webview with configuration
        webView = WKWebView(frame: view.bounds, configuration: configs)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = self
        
        // Add to view hierarchy
        view.addSubview(webView)
        
        // Set constraints
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        // Load the webview content
        if let url = Bundle.main.url(forResource: "dist/index", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            NSLog("Failed to find index.html in bundle")
        }
    }
}