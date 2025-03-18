import Foundation
import WebKit
import UIKit

extension ViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        eprint("COMPONENTS: ", components?.host ?? "nil")
        
        if components?.scheme == "http" || components?.scheme == "https" {
            if components?.host != "geph.io" {
                // Open the link in the external browser
                UIApplication.shared.open(url)
            } else {
                // Handle subscription links
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
            // Cancel the decisionHandler because we managed the navigationAction
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Additional setup after page load if needed
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        NSLog("WebView navigation failed: \(error.localizedDescription)")
    }
}