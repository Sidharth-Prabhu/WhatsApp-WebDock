import SwiftUI
import WebKit
import UserNotifications

class WebViewManager: NSObject, WKScriptMessageHandler, WKNavigationDelegate, WKDownloadDelegate, WKUIDelegate {
    static let shared = WebViewManager()
    
    private var webViews: [UUID: WKWebView] = [:]
    private var activeDownloads = Set<WKDownload>()
    
    // Handle injected web notification interceptor messages and blob downloads
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "notificationHandler" {
            guard let dict = message.body as? [String: Any],
                  let title = dict["title"] as? String,
                  let body = dict["body"] as? String else {
                return
            }
            
            // Build and trigger a native macOS notification
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil // deliver immediately
            )
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error displaying notification: \(error)")
                }
            }
        } else if message.name == "blobDownloadHandler" {
            guard let dict = message.body as? [String: Any],
                  let filename = dict["filename"] as? String,
                  let dataUrl = dict["dataUrl"] as? String else {
                return
            }
            
            // Decode the data URL
            guard let commaIndex = dataUrl.firstIndex(of: ","),
                  let data = Data(base64Encoded: String(dataUrl.suffix(from: dataUrl.index(after: commaIndex)))) else {
                return
            }
            
            // Ask user where to save the file
            let savePanel = NSSavePanel()
            savePanel.nameFieldStringValue = filename
            savePanel.isExtensionHidden = false
            savePanel.canCreateDirectories = true
            
            DispatchQueue.main.async {
                let response = savePanel.runModal()
                if response == .OK, let url = savePanel.url {
                    do {
                        try data.write(to: url)
                    } catch {
                        print("Failed to write downloaded file: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    func webView(for accountId: UUID) -> WKWebView {
        if let webView = webViews[accountId] {
            return webView
        }
        
        let config = WKWebViewConfiguration()
        if #available(macOS 14.0, *) {
            config.websiteDataStore = WKWebsiteDataStore(forIdentifier: accountId)
        } else {
            config.websiteDataStore = WKWebsiteDataStore.default()
        }
        config.processPool = WKProcessPool()
        
        // Inject JS to override standard HTML5 Notification API & intercept downloads.
        let source = """
        (function() {
            class MockNotification {
                static get permission() {
                    return 'granted';
                }
                static requestPermission(callback) {
                    if (callback) callback('granted');
                    return Promise.resolve('granted');
                }
                constructor(title, options) {
                    this.title = title;
                    this.options = options || {};
                    try {
                        window.webkit.messageHandlers.notificationHandler.postMessage({
                            title: this.title,
                            body: this.options.body || ""
                        });
                    } catch (e) {
                        console.error("Failed to post notification message to macOS app", e);
                    }
                }
                close() {}
                addEventListener() {}
                removeEventListener() {}
                dispatchEvent() { return true; }
            }
            window.Notification = MockNotification;
            
            // Intercept clicks on links for downloads
            document.addEventListener('click', function(e) {
                let target = e.target;
                while (target && target.tagName !== 'A') {
                    target = target.parentNode;
                }
                if (target && target.tagName === 'A' && target.href) {
                    const isBlob = target.href.startsWith('blob:');
                    const hasDownload = target.hasAttribute('download');
                    
                    if (isBlob || hasDownload) {
                        e.preventDefault();
                        e.stopPropagation();
                        
                        const href = target.href;
                        const downloadName = target.getAttribute('download') || 'download';
                        
                        fetch(href)
                            .then(response => response.blob())
                            .then(blob => {
                                const reader = new FileReader();
                                reader.onloadend = function() {
                                    window.webkit.messageHandlers.blobDownloadHandler.postMessage({
                                        filename: downloadName,
                                        dataUrl: reader.result
                                    });
                                };
                                reader.readAsDataURL(blob);
                            })
                            .catch(err => {
                                console.error("Error fetching download resource:", err);
                            });
                    }
                }
            }, true);

            // Inject CSS and targeted JS observer to hide "Get WhatsApp for Mac / Windows" options safely without breaking chat popups or drag & drop targets
            const style = document.createElement('style');
            style.textContent = `
                a[href*="whatsapp.com/download"],
                a[href*="whatsapp.com/desktop"] {
                    display: none !important;
                }
            `;
            (document.head || document.documentElement).appendChild(style);

            function hideDesktopUpsell() {
                const walker = document.createTreeWalker(document.body || document.documentElement, NodeFilter.SHOW_TEXT, null, false);
                let node;
                const nodesToHide = [];
                while (node = walker.nextNode()) {
                    const text = node.nodeValue ? node.nodeValue.trim().toLowerCase() : '';
                    if (text.includes('get whatsapp for mac') || text.includes('get whatsapp for windows') || text === 'get the app') {
                        let el = node.parentElement;
                        while (el && el !== document.body) {
                            const id = el.id || '';
                            const role = el.getAttribute('role') || '';
                            if (id === 'app' || id === 'main' || id === 'pane-side' || role === 'main') {
                                break;
                            }
                            const contentText = (el.textContent || '').trim();
                            if (contentText.length < 300 && (el.tagName === 'A' || el.tagName === 'BUTTON' || role === 'button' || role === 'link' || el.tagName === 'LI' || el.tagName === 'DIV')) {
                                nodesToHide.push(el);
                                break;
                            }
                            el = el.parentElement;
                        }
                    }
                }
                nodesToHide.forEach(el => {
                    el.style.display = 'none';
                });
            }

            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', hideDesktopUpsell);
            } else {
                hideDesktopUpsell();
            }

            const observer = new MutationObserver(function() {
                hideDesktopUpsell();
            });
            observer.observe(document.documentElement, { childList: true, subtree: true });
        })();
        """
        let script = WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        config.userContentController.addUserScript(script)
        config.userContentController.add(self, name: "notificationHandler")
        config.userContentController.add(self, name: "blobDownloadHandler")
        
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs
        
        let preferences = WKPreferences()
        preferences.isElementFullscreenEnabled = true
        config.preferences = preferences
        
        config.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.registerForDraggedTypes([.fileURL, .URL, .string, .tiff, .png])
        
        // Diagnostic logging
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let rawUA = webView.value(forKey: "userAgent") as? String ?? "Unknown"
        print("[Diagnostic] macOS Version: \(osVersion)")
        print("[Diagnostic] Deployment Target: macOS 26.1")
        print("[Diagnostic] customUserAgent is explicitly set before modification: \(webView.customUserAgent != nil)")
        print("[Diagnostic] Raw WKWebView User-Agent: \(rawUA)")
        
        // WhatsApp Web requires standard Safari Version and Safari tokens to recognize WebKit on macOS.
        // Plain WKWebView on macOS omits "Version/X.X Safari/XXX.X.X", causing WhatsApp Web to display an "Update Safari" error.
        let safariUA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Safari/605.1.15"
        webView.customUserAgent = safariUA
        print("[Diagnostic] Active User-Agent set to: \(safariUA)")
        
        webView.navigationDelegate = self
        webView.uiDelegate = self
        
        let url = URL(string: "https://web.whatsapp.com")!
        let request = URLRequest(url: url)
        webView.load(request)
        
        webViews[accountId] = webView
        return webView
    }
    
    func removeWebView(for accountId: UUID) {
        if let webView = webViews[accountId] {
            webView.configuration.userContentController.removeScriptMessageHandler(forName: "notificationHandler")
            webView.configuration.userContentController.removeScriptMessageHandler(forName: "blobDownloadHandler")
        }
        webViews.removeValue(forKey: accountId)
    }
    
    func reloadWebView(for accountId: UUID) {
        if let webView = webViews[accountId] {
            webView.reload()
        }
    }
    
    // MARK: - WKNavigationDelegate
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.shouldPerformDownload {
            decisionHandler(.download)
            return
        }
        
        if let url = navigationAction.request.url {
            let host = url.host ?? ""
            if navigationAction.navigationType == .linkActivated {
                if !host.contains("whatsapp.com") && url.scheme != "blob" {
                    NSWorkspace.shared.open(url)
                    decisionHandler(.cancel)
                    return
                }
            }
        }
        
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if navigationResponse.canShowMIMEType {
            decisionHandler(.allow)
        } else {
            decisionHandler(.download)
        }
    }
    
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
        activeDownloads.insert(download)
    }
    
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = self
        activeDownloads.insert(download)
    }
    
    // MARK: - WKUIDelegate
    
    @available(macOS 12.0, *)
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.grant)
    }
    
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            let host = url.host ?? ""
            if !host.contains("whatsapp.com") && url.scheme != "blob" {
                NSWorkspace.shared.open(url)
            }
        }
        return nil
    }
    
    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = parameters.allowsDirectories
        openPanel.allowsMultipleSelection = parameters.allowsMultipleSelection
        
        openPanel.begin { response in
            if response == .OK {
                completionHandler(openPanel.urls)
            } else {
                completionHandler(nil)
            }
        }
    }
    
    // MARK: - WKDownloadDelegate
    
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = suggestedFilename
        savePanel.isExtensionHidden = false
        savePanel.canCreateDirectories = true
        
        DispatchQueue.main.async {
            let response = savePanel.runModal()
            if response == .OK {
                completionHandler(savePanel.url)
            } else {
                completionHandler(nil)
            }
        }
    }
    
    func downloadDidFinish(_ download: WKDownload) {
        activeDownloads.remove(download)
    }
    
    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        activeDownloads.remove(download)
        print("Download failed: \(error.localizedDescription)")
    }
}

struct WhatsAppWebView: NSViewRepresentable {
    let accountId: UUID
    
    func makeNSView(context: Context) -> WKWebView {
        return WebViewManager.shared.webView(for: accountId)
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        // No-op: Managed by WebViewManager
    }
}
