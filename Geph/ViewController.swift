import NetworkExtension
import UIKit
import WebKit

class ViewController: UIViewController {
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


extension ViewController: UIDocumentPickerDelegate {
  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL])
  {

  }
  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    controller.dismiss(animated: true)
  }
}

