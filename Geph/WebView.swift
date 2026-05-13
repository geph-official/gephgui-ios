import Foundation
import UIKit
import WebKit

// MARK: - WebView Setup & Configuration
extension ViewController: UIWebViewDelegate {
    
    /// Sets up the WebView with configuration, constraints, and initial scripts
    func setupWebView() {
        // Configure webview
        webView.navigationDelegate = self
		webView.uiDelegate = self
		webView.configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        
        // Add message handlers
        webView.configuration.userContentController.add(
            self, contentWorld: .page, name: "callRpc")
        
        // Add to view hierarchy with constraints
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        setupLoadingPlaceholder()
        
        // Inject scripts
        injectUserScripts()
    }

    private func setupLoadingPlaceholder() {
        let placeholder = UIView()
        placeholder.translatesAutoresizingMaskIntoConstraints = false
        placeholder.backgroundColor = .systemBackground
        placeholder.isUserInteractionEnabled = false

        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit

        imageView.image = UIImage(named: "GephLogo")

        placeholder.addSubview(imageView)
        view.addSubview(placeholder)
        loadingPlaceholderView = placeholder

        NSLayoutConstraint.activate([
            placeholder.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            placeholder.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            placeholder.topAnchor.constraint(equalTo: view.topAnchor),
            placeholder.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            imageView.centerXAnchor.constraint(equalTo: placeholder.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: placeholder.centerYAnchor),
            imageView.widthAnchor.constraint(lessThanOrEqualTo: placeholder.widthAnchor, multiplier: 0.22),
            imageView.widthAnchor.constraint(lessThanOrEqualToConstant: 96),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor)
        ])
    }

    private func hideLoadingPlaceholder() {
        guard let placeholder = loadingPlaceholderView else {
            return
        }

        UIView.animate(
            withDuration: 0.2,
            delay: 0,
            options: [.curveEaseOut, .beginFromCurrentState],
            animations: {
                placeholder.alpha = 0
            },
            completion: { [weak self] _ in
                placeholder.removeFromSuperview()
                self?.loadingPlaceholderView = nil
            }
        )
    }
    
    /// Injects required JavaScript into the WebView
    func injectUserScripts() {
        // Inject init.js
        if let filepath = Bundle.main.path(forResource: "init", ofType: "js") {
            do {
                let js = try String(contentsOfFile: filepath)
                let script = WKUserScript(
                    source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false)
                webView.configuration.userContentController.addUserScript(script)
                
                // Add viewport meta script
                injectViewportMetaScript()
                print("injected js!")
            } catch {
                print("init.js contents could not be loaded")
                abort()
            }
        } else {
            print("could not find init.js")
            abort()
        }
    }
    
    /// Injects viewport meta tag script for proper mobile display
    private func injectViewportMetaScript() {
        let source = """
        var meta = document.createElement('meta');
        meta.name = 'viewport';
        meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
        var head = document.getElementsByTagName('head')[0];
        head.appendChild(meta);
        """
        
        let script = WKUserScript(
            source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        webView.configuration.userContentController.addUserScript(script)
    }
    
    /// Loads the initial HTML content into the WebView
    func loadInitialContent() {
        if let htmlPath = Bundle.main.url(
            forResource: "index", withExtension: "html", subdirectory: "dist")
        {
            print(htmlPath)
            webView.loadFileURL(htmlPath, allowingReadAccessTo: htmlPath.deletingLastPathComponent())
        }
        print("successfully loaded webView")
    }
}

// MARK: - WKNavigationDelegate Implementation
extension ViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        hideLoadingPlaceholder()
    }

    func webView(
        _ webView: WKWebView, 
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        eprint("COMPONENTS: ", components?.host ?? "")
        
        if components?.scheme == "http" || components?.scheme == "https" {
                // Open the link in the external browser
                UIApplication.shared.open(url)
            // Cancel the navigation since we handled it
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }
    
//    private func handleGephSubscriptionNavigation() {
//        if let hasSubscription = hasSubscription {
//            if hasSubscription {
//                showSubscriptionExistsAlert()
//            } else {
//                inAppPurchase(42)
//            }
//        } else {
//            inAppPurchase(42)
//        }
//    }
}

extension ViewController: WKUIDelegate {
	func webView(_ webView: WKWebView,
				 createWebViewWith configuration: WKWebViewConfiguration,
				 for navigationAction: WKNavigationAction,
				 windowFeatures: WKWindowFeatures) -> WKWebView? {
		if let url = navigationAction.request.url {
			UIApplication.shared.open(url)
		}
		return nil
	}
}
