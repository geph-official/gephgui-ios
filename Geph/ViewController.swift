//
//  ViewController.swift
//  geph
//
//  Created by Eric Dong on 3/21/22.
//

import NetworkExtension
import StoreKit
import UIKit
import WebKit

class ViewController: UIViewController {

  //    func presentOfferCodeRedeemSheet() {
  //        guard let windowScene = view.window?.windowScene else {
  //            print("Unable to get the current window scene")
  //            return
  //        }
  //
  //        Task {
  //            do {
  //                try await StoreKit.AppStore.presentOfferCodeRedeemSheet(in: windowScene)
  //            } catch {
  //                print("Error presenting offer code redeem sheet: \(error)")
  //                // Handle the error appropriately
  //            }
  //        }
  //    }

  func showSubscriptionExistsAlert() {
    // Create the alert controller
    let alertController = UIAlertController(
      title: "Subscription Exists | 已有订阅",
      message:
        "You already have an subscription associated with this Apple ID. If it is with another Geph account, and you would like to transfer the subscription over to this account, please contact support@geph.io\n\n此 Apple ID 已经订阅了迷雾通 Plus。如果您的 Plus 订阅在另一个迷雾通账户，而您希望将 Plus 订阅转移到这个账户，请邮件联系 support@geph.io",
      preferredStyle: .alert)

    // Create the actions
    let confirmAction = UIAlertAction(title: "Ok", style: .default) { (_) in
      inapp_purchase()
    }

    // Add the actions to the alert controller
    alertController.addAction(confirmAction)

    // Present the alert
    self.present(alertController, animated: true, completion: nil)
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    // fetch subscription product info & user subscription status
    fetchProduct()
    fetchHasSubscription()

    // generate & set daemon-rpc secret path if it's not already set
    let sharedDefaults = UserDefaults(suiteName: "group.geph.io")
    if sharedDefaults?.string(forKey: DAEMON_RPC_SECRET_PATH_KEY) == nil {
      let randomString = generateRandomString(length: 20)
      sharedDefaults?.set(randomString, forKey: DAEMON_RPC_SECRET_PATH_KEY)
    }

    // inject init.js
    if let filepath = Bundle.main.path(forResource: "init", ofType: "js") {
      do {
        let js = try String(contentsOfFile: filepath)
        let script = WKUserScript(
          source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        self.webView.configuration.userContentController.addUserScript(script)

        let source: String =
          "var meta = document.createElement('meta');" + "meta.name = 'viewport';"
          + "meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';"
          + "var head = document.getElementsByTagName('head')[0];" + "head.appendChild(meta);"
        let script2: WKUserScript = WKUserScript(
          source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        self.webView.configuration.userContentController.addUserScript(script2)
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
    webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0.0)
      .isActive = true
    webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 0.0)
      .isActive = true
    if let htmlPath = Bundle.main.url(
      forResource: "index", withExtension: "html", subdirectory: "dist")
    {
      print(htmlPath)
      webView.loadFileURL(htmlPath, allowingReadAccessTo: htmlPath.deletingLastPathComponent())
    }
    eprint("successfully loaded webView")
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
    webView.scrollView.isScrollEnabled = false
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

  func inject_success(_ callback: String, _ message: String) async throws {
    let js = "\(callback)[0](\(message)); delete \(callback)"
    //        eprint("js: ", js)
    try await webView.evaluateJavaScript(js)
  }

  func inject_reject(_ callback: String, _ message: String) async throws {
    let js = "\(callback)[1](\(message)); delete \(callback)"
    //        eprint("js: ", js)
    try await webView.evaluateJavaScript(js)
  }

  func handle_export_debugpack() throws {
    let _ = try handle_debugpack()
    let document_picker = UIDocumentPickerViewController(
      forExporting: [URL(fileURLWithPath: EXPORTED_DEBUGPACK_PATH)], asCopy: false)
    document_picker.modalPresentationStyle = .overFullScreen
    //        let fmanager = FileManager.default
    //        document_picker.directoryURL = fmanager.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
    self.present(document_picker, animated: true)
  }
}

extension ViewController: WKNavigationDelegate {
  func webView(
    _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
    decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
  ) {
    guard let url = navigationAction.request.url else {
      decisionHandler(.allow)
      return
    }
    let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    eprint("COMPONENTS: ", components?.host)
    if components?.scheme == "http" || components?.scheme == "https" {
      if components?.host != "geph.io" {
        // open the link in the external browser.
        UIApplication.shared.open(url)
      } else {
        if let hasSubscription = hasSubscription {
          if hasSubscription {
            showSubscriptionExistsAlert()
          } else {
            inapp_purchase()
          }
        } else {
          inapp_purchase()
        }
      }
      // cancel the decisionHandler because we managed the navigationAction.
      decisionHandler(.cancel)
    } else {
      decisionHandler(.allow)
    }
  }
}

extension ViewController: WKScriptMessageHandler {
  func userContentController(
    _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
  ) {
    Task {
      if let messageBody = message.body as? [String] {
        //                eprint("WebView CALLED \(message.name) WITH \(messageBody)")
        let verb = messageBody[0]
        let args = messageBody[1]  // args is a json-encoded array of strings
        let callback = messageBody[2]
        //                eprint("callback = ", callback)
        do {
          if message.name == "callRpc" {
            switch verb {
            case "start_daemon":
              let res = try start_tunnel(args, try await getManager())
              try await self.inject_success(callback, res)
            case "stop_daemon":

              let manager = try await getManager()
              manager.connection.stopVPNTunnel()

              Task {
                while true {
                  if manager.connection.status == NEVPNStatus.disconnected {
                    do {
                      eprint("callback = ", callback)
                      try await self.inject_success(callback, "")
                    } catch {
                      eprint("OH NO! ", error.localizedDescription)
                    }
                    break
                  } else {
                    try await Task.sleep(nanoseconds: 100_000_000)
                  }
                }
              }

            case "sync":
              let ret = try await callBlockingSyncFunc {
                try handle_sync(args)
              }
              try await inject_success(callback, ret)
            case "daemon_rpc":
              let res = try await handle_daemon_rpc(args)
              try await inject_success(callback, res)
            case "binder_rpc":
              let ret = try await callBlockingSyncFunc {
                try handle_binder_rpc(args)
              }
              eprint("binder_rpc before calling inject_success!!!!!")
              try await inject_success(callback, ret)
              eprint("binder_rpc successfully called inject_success~~~~~")
            case "export_logs":
              try self.handle_export_debugpack()
              try await inject_success(callback, "")
            case "version":
              let version = try handle_version()
              try await inject_success(callback, jsonify(version))
            case _:
              throw "invalid rpc input!"
            }
          }
        } catch {
          NSLog("ERROR!! %@", error.localizedDescription)
          try await self.inject_reject(callback, jsonify(error.localizedDescription))
        }
      } else {
        NSLog("cannot parse rpc argument!!")
      }
    }
  }
}

extension ViewController: UIDocumentPickerDelegate {
  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL])
  {

  }
  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    controller.dismiss(animated: true)
  }
}

func callBlockingSyncFunc(_ function: @escaping () throws -> String) async -> String {
  return await withCheckedContinuation { continuation in
    DispatchQueue.global(qos: .background).async {
      do {
        let result = try function()
        continuation.resume(returning: result)
      } catch {
        // Handle the error. For example, return a default value or error message.
        // Adjust this according to your needs.
        continuation.resume(returning: "Error: \(error)")
      }
    }
  }
}
