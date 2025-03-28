import NetworkExtension
import UIKit
import WebKit

class ViewController: UIViewController {

  // MARK: - Properties

  lazy var webView: WKWebView = {
    let configuration = WKWebViewConfiguration()
    configuration.setValue(true, forKey: "_allowUniversalAccessFromFileURLs")
    let webView = WKWebView(frame: view.bounds, configuration: configuration)
    webView.translatesAutoresizingMaskIntoConstraints = false
    webView.scrollView.isScrollEnabled = false

//    // allow inspecting from safari
//    webView.isInspectable = true
      
    return webView
  }()

  // Save these properties since they're used in multiple places
  var hasSubscription: Bool?
  private var product: Any?  // Replace with actual type

  // MARK: - Lifecycle Methods

  override func viewDidLoad() {
    super.viewDidLoad()

    // start an inert client to do daemon_rpc
	  do {
		  try startClient(configToJsonString(inertConfig(defaultConfig()))!)
	  } catch {
		  eprint("starting geph5-client dry run in main app failed with ERROR = ", error.localizedDescription)
	  }
    setupWebView()
    loadInitialContent()
    setupUserDefaults()
    fetchSubscriptionData()
  }

  deinit {
    print("deallocating")
    let userContentController = webView.configuration.userContentController
    userContentController.removeAllUserScripts()
    userContentController.removeAllScriptMessageHandlers()
  }

  // MARK: - Setup Methods

  private func setupUserDefaults() {
    let sharedDefaults = UserDefaults(suiteName: "group.geph.io")
    if sharedDefaults?.string(forKey: DAEMON_RPC_SECRET_PATH_KEY) == nil {
      let randomString = generateRandomString(length: 20)
      sharedDefaults?.set(randomString, forKey: DAEMON_RPC_SECRET_PATH_KEY)
    }
  }

  private func fetchSubscriptionData() {
    fetchProduct()
    fetchHasSubscription()
  }

  func showSubscriptionExistsAlert() {
    let alertController = UIAlertController(
      title: "Subscription Exists | 已有订阅",
      message:
        "You already have an subscription associated with this Apple ID. If it is with another Geph account, and you would like to transfer the subscription over to this account, please contact support@geph.io\n\n此 Apple ID 已经订阅了迷雾通 Plus。如果您的 Plus 订阅在另一个迷雾通账户，而您希望将 Plus 订阅转移到这个账户，请邮件联系 support@geph.io",
      preferredStyle: .alert)

    let confirmAction = UIAlertAction(title: "Ok", style: .default) { [weak self] _ in
      inAppPurchase(42)
    }

    alertController.addAction(confirmAction)
    present(alertController, animated: true)
  }

  // MARK: - Debug Utilities

  func handleExportDebugpack() throws {
    let _ = try handleDebugpack()
    let documentPicker = UIDocumentPickerViewController(
      forExporting: [URL(fileURLWithPath: EXPORTED_DEBUGPACK_PATH)], asCopy: false)
    documentPicker.modalPresentationStyle = .overFullScreen
    present(documentPicker, animated: true)
  }

  private func handleDebugpack() throws -> Any {
    // Implementation would go here
    return true  // Placeholder
  }

  private func generateRandomString(length: Int) -> String {
    // Implementation would go here
    return "randomString"  // Placeholder
  }
}

// MARK: - UIDocumentPickerDelegate

extension ViewController: UIDocumentPickerDelegate {
  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL])
  {
    // Implementation would go here
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    controller.dismiss(animated: true)
  }
}
