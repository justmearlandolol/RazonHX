import AppKit
import WebKit

final class HTMLWallpaper: NSView, WKNavigationDelegate {
    private static let policy = """
    [{"trigger":{"url-filter":".*"},"action":{"type":"block"}},
     {"trigger":{"url-filter":"^data:"},"action":{"type":"ignore-previous-rules"}}]
    """
    private static let header = """
    <!doctype html><meta charset="utf-8"><meta http-equiv="Content-Security-Policy"
    content="default-src 'none'; img-src data:; style-src 'unsafe-inline'; font-src data:; form-action 'none'; base-uri 'none'">
    <style>html,body{margin:0;width:100%;height:100%;overflow:hidden;background:#101017}</style>
    """
    private var webView: WKWebView?
    private var initialNavigation: WKNavigation?
    private var allowInitial = true

    init(url: URL) throws {
        let html = try String(contentsOf: url, encoding: .utf8)
        super.init(frame: .zero)
        WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "RazonHX-Local-Wallpaper-v1",
            encodedContentRuleList: Self.policy) { [weak self] rules, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                guard let rules = rules else { self.failure(); return }
                let config = WKWebViewConfiguration()
                config.websiteDataStore = .nonPersistent()
                config.preferences.javaScriptEnabled = false
                config.userContentController.add(rules)
                let view = WKWebView(frame: self.bounds, configuration: config)
                view.autoresizingMask = [.width, .height]
                view.navigationDelegate = self
                self.addSubview(view)
                self.webView = view
                self.initialNavigation = view.loadHTMLString(Self.header + html, baseURL: nil)
            }
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let initial = allowInitial && action.targetFrame?.isMainFrame == true
            && action.request.url?.absoluteString == "about:blank"
        if initial { allowInitial = false }
        decisionHandler(initial ? .allow : .cancel)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if initialNavigation === navigation { failure() }
    }

    private func failure() {
        webView?.removeFromSuperview()
        webView = nil
        let message = NSTextField(labelWithString: "Could not open the local HTML wallpaper.")
        message.textColor = .white
        message.alignment = .center
        message.frame = NSRect(x: 0, y: bounds.midY - 10, width: bounds.width, height: 20)
        message.autoresizingMask = [.width, .minYMargin, .maxYMargin]
        addSubview(message)
    }

    deinit { webView?.stopLoading() }
}
