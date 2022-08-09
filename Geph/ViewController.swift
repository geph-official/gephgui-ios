//
//  ViewController.swift
//  geph
//
//  Created by Eric Dong on 3/21/22.
//

import UIKit
import WebKit
import NetworkExtension


// TODOs:
// 1. Handle news page
// 2. Handle exclude apps
// 3. Free c-string arrays created by Rust

// 1. Make observer to sync with settings page
// 2. Handle registering/deleting vpn from preferences
public let service : VPNConfigurationService = .shared

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // inject js to set ios field in window
        let js = """
        window["ios"] = {};
        """
        let script = WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false);
        self.webView.configuration.userContentController.addUserScript(script)
//        print("injected js!")

        // requires iOS 14 & above
        guard #available(iOS 14, *) else {
            abort()
        }
        
        // register message handlers
        self.webView.configuration.userContentController.addScriptMessageHandler(
            self, contentWorld: .page, name: "set_conversion_factor")
        self.webView.configuration.userContentController.addScriptMessageHandler(
            self, contentWorld: .page, name: "export_logs")
        self.webView.configuration.userContentController.addScriptMessageHandler(
            self, contentWorld: .page, name: "start_sync_status")
        self.webView.configuration.userContentController.addScriptMessageHandler(
            self, contentWorld: .page, name: "check_sync_status")
        self.webView.configuration.userContentController.addScriptMessageHandler(
            self, contentWorld: .page, name: "start_binder_proxy")
        self.webView.configuration.userContentController.addScriptMessageHandler(
            self, contentWorld: .page, name: "stop_binder_proxy")
        self.webView.configuration.userContentController.addScriptMessageHandler(
            self, contentWorld: .page, name: "start_daemon")
        self.webView.configuration.userContentController.addScriptMessageHandler(
            self, contentWorld: .page, name: "stop_daemon")
        
        // set nagivation delegate
        self.webView.navigationDelegate = self
        
        // add webview & load geph
        view.addSubview(webView)
        if let htmlPath = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "build"){
            print(htmlPath)
            webView.loadFileURL( htmlPath, allowingReadAccessTo: htmlPath.deletingLastPathComponent());
        }
    }

    // deinit and remove webview stuff to avoid memory leaks (unsure if this is necessary)
    deinit {
        eprint("deallocating")
        let ucc = webView.configuration.userContentController
        ucc.removeAllUserScripts()
        ucc.removeAllScriptMessageHandlers()
    }
    
    private lazy var webView: WKWebView = {
        let webView = WKWebView(frame: view.frame)
        webView.translatesAutoresizingMaskIntoConstraints = true
        return webView
    }()
    
    private func getManager() async throws -> NETunnelProviderManager {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        if managers.isEmpty {
            let manager = NETunnelProviderManager()
            manager.localizedDescription = "geph-daemon"
            let proto = NETunnelProviderProtocol()
            // WARNING: This must match the bundle identifier of the app extension containing packet tunnel provider.
            proto.providerBundleIdentifier = "geph.io.daemon"
            proto.serverAddress = "geph"
            manager.protocolConfiguration = proto
            manager.isEnabled = true
            try await manager.loadFromPreferences()
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

// reference: https://gist.github.com/kevenbauke/d449718a5f268ee843f286db88f137cc

extension ViewController: WKScriptMessageHandlerWithReply {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage, replyHandler: @escaping (Any?, String?) -> Void) {
        
        if message.name == "start_sync_status", let messageBody = message.body as? String {
            eprint(message.name)
            eprint(messageBody)
            
            let res = handle_start_sync_status(messageBody)
            
            eprint("res: ", res)
            replyHandler( res, nil )
        }
        
        else if message.name == "check_sync_status", let messageBody = message.body as? String {
            eprint(message.name)
            eprint(messageBody)
            
            let res = handle_check_sync_status(messageBody)
            eprint("res: ", res)
            eprint(sync_global_obj)
            
            switch res
            {
            case SyncStatus.Pending : replyHandler( "", nil )
            case SyncStatus.Error(let e) : replyHandler( "", e )
            case SyncStatus.Done(let resp) : replyHandler(resp, nil)
            }
        }
        
        else if message.name == "start_binder_proxy" {
            eprint(message.name)
            handle_start_binder_proxy()
            eprint("yobig")
            replyHandler( "", nil )
        }
        
        else if message.name == "stop_binder_proxy", let messageBody = message.body as? String {
            eprint(message.name)
            eprint(messageBody)
            replyHandler("Boolayah!", nil)
        }
        
        else if message.name == "start_daemon", let messageBody = message.body as? String {
            eprint(message.name)
            eprint(messageBody)
            Task {
                let manager = try await getManager()
                let res = start_daemon(messageBody, manager)
                if res == "" {
                    replyHandler("", nil)
                } else {
                    replyHandler("", res)
                }
            }
        }
        
        else if message.name == "stop_daemon", let messageBody = message.body as? String {
            eprint(message.name)
            eprint(messageBody)
            Task {
                let manager = try await getManager()
                stop_daemon(manager)
                replyHandler("", nil)
            }
        }
        
        else if message.name == "export_logs", let messageBody = message.body as? String {
            eprint(message.name)
            eprint(messageBody)
            let logs_url = URL(string: "http://localhost:9809/logs")!
            UIApplication.shared.open(logs_url)
            replyHandler( "", nil )
        }
        
        else if message.name == "set_conversion_factor", let messageBody = message.body as? String {
            eprint("setting conversion factor (not really)")
            eprint("input = ", messageBody);
            replyHandler( "", nil )
        }
    }
}

func handle_start_binder_proxy() {
    do {
        let args_arr = ["geph4-client", "binder-proxy", "--listen", "127.0.0.1:23456"]
    let args = try jsonify(args_arr)
    Thread.detachNewThread({
        let _ = call_geph_wrapper(args)
    })
    } catch {
        eprint(error.localizedDescription)
    }
}


// References:
// https://stackoverflow.com/questions/65270083/how-does-the-ios-14-api-wkscriptmessagehandlerwithreply-work-for-communicating-w
// https://diamantidis.github.io/2020/02/02/two-way-communication-between-ios-wkwebview-and-web-page
// https://kean.blog/post/vpn-configuration-manager
// https://developer.apple.com/forums/thread/99399
