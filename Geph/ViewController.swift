//
//  ViewController.swift
//  geph
//
//  Created by Eric Dong on 3/21/22.
//

import UIKit
import WebKit
import NetworkExtension

public let service : VPNConfigurationService = .shared

class ViewController: UIViewController {
//    override func loadView() {
////        view = webView
//        let rect = CGRect.init(x: 0.0, y: 0.0, width: 200.0, height: 200.0)
//        view = UIView.init(frame: rect)
//        view.backgroundColor = .systemGreen
//        view.contentMode = .scaleAspectFit
//        view.contentMode = .center
//    }
    override func viewDidLoad() {
        // requires iOS 15 & above
            guard #available(iOS 15, *) else {
                abort()
            }

        super.viewDidLoad()
        
        // inject init.js
        if let filepath = Bundle.main.path(forResource: "init", ofType: "js") {
            do {
                let js = try String(contentsOfFile: filepath)
                let script = WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false)
                self.webView.configuration.userContentController.addUserScript(script)
                eprint("injected js!")
            } catch {
                eprint("init.js contents could not be loaded")
                abort()
            }
        } else {
            eprint("could not find init.js")
            abort()
        }
        
        // register message handlers
        self.webView.configuration.userContentController.add(
            self, contentWorld: .page, name: "callRpc")
        // set nagivation delegate
        self.webView.navigationDelegate = self
        
        // add webview & load geph
        view.addSubview(webView)
        webView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0.0).isActive = true
        webView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0.0).isActive = true
        webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0.0).isActive = true
        webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 0.0).isActive = true
        if let htmlPath = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "dist"){
            print(htmlPath)
            webView.loadFileURL( htmlPath, allowingReadAccessTo: htmlPath.deletingLastPathComponent());
        }
        eprint("successfully loaded webView")
        
//        // add refresher for every time the app is opened
//       let center = NotificationCenter.default
//        center.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil) { Notification in
//            eprint("refreshing")
//            self.webView.reload()
//        }
    }
    
    // deinit and remove webview stuff to avoid memory leaks
    deinit {
        eprint("deallocating")
        let ucc = webView.configuration.userContentController
        ucc.removeAllUserScripts()
        ucc.removeAllScriptMessageHandlers()
    }
    
    private lazy var webView: WKWebView = {
//        let webView = WKWebView(frame: CGRect(x: 0.0, y: 0.0, width: 100, height: 100))
        let configs = WKWebViewConfiguration()
        configs.setValue(true, forKey: "_allowUniversalAccessFromFileURLs")
        let webView = WKWebView(frame: view.bounds, configuration: configs)
        webView.translatesAutoresizingMaskIntoConstraints = false
        return webView
    }()
    
    func getManager() async throws -> NETunnelProviderManager {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        if managers.isEmpty {
            let manager = NETunnelProviderManager()
            manager.localizedDescription = "geph-daemon"
            let proto = NETunnelProviderProtocol()
            // WARNING: This must match the bundle identifier of the app extension containing packet tunnel provider.
            proto.providerBundleIdentifier = "geph.io.daemon"
            proto.serverAddress = "geph"
            manager.protocolConfiguration = proto
            try await manager.loadFromPreferences()
            manager.isEnabled = true
            try await manager.saveToPreferences()
            try await manager.loadFromPreferences()
            return manager
        } else {
            let man = managers[0]
            man.isEnabled = true
            try await man.saveToPreferences()
            return man
        }
    }
    
    func inject_success(_ callback: String, _ message: String) throws {
        let js = "\(callback)[0](\(message))"
//        eprint("js: ", js)
        webView.evaluateJavaScript(js)
    }
    
    func inject_reject(_ callback: String, _ message: String) throws {
        let js = "\(callback)[1](\(message))"
//        eprint("js: ", js)
        webView.evaluateJavaScript(js)
    }
}

extension ViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
                    decisionHandler(.allow)
                    return
                }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        
        if components?.scheme == "http" || components?.scheme == "https" {
            // open the link in the external browser.
            UIApplication.shared.open(url)
            // cancel the decisionHandler because we managed the navigationAction.
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }
}

@available(iOS 15.0, *)
extension ViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        Task {
            if let messageBody = message.body as? [String] {
//                eprint("WebView CALLED \(message.name) \nWITH \(messageBody)")
                let verb = messageBody[0]
                let args = messageBody[1] // args is a json-encoded array of strings
                let callback = messageBody[2]
                
                do {
                    if message.name == "callRpc" {
                        switch verb {
                        case "start_daemon":
                            let res = try handle_start_daemon(args, try await getManager())
                            try self.inject_success(callback, res)
                        case "stop_daemon":
                            let manager = try await getManager()
                            manager.connection.stopVPNTunnel()
                            let center = NotificationCenter.default
                            center.addObserver(forName: .NEVPNStatusDidChange, object: nil, queue: nil){
                                Notification in
                                if manager.connection.status == NEVPNStatus.disconnected {
                                    do {
                                        try self.inject_success(callback, "")
                                    } catch {
                                        eprint("OH NO! %@", error.localizedDescription)
                                    }
                                }
                            }
                        case "sync":
                            let ret = try handle_sync(args)
                            try inject_success(callback, ret)
                        case "daemon_rpc":
                            let res = try await handle_daemon_rpc(args)
                            try inject_success(callback, res)
                        case "binder_rpc":
                            let ret = try handle_binder_rpc(args)
                            try inject_success(callback, ret)
                        case "export_logs":
                            let logs_url = URL(string: "http://localhost:9809/logs")!
                            await UIApplication.shared.open(logs_url)
                            try inject_success(callback, "")
                        case "version":
                            try inject_success(callback, UIDevice.current.systemVersion)
                        case _:
                            throw "invalid rpc input!"
                        }
                    }
                } catch {
                    NSLog("ERROR!! %@", error.localizedDescription)
                    try self.inject_reject(callback, jsonify(error.localizedDescription))
                }
            } else {
                NSLog("cannot parse rpc argument!!")
            }
        }
    }
}
