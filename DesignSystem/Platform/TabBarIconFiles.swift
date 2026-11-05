import UIKit
import WebKit

/// The user's own tab icons. iOS has no public way to draw an SVG file, so WebKit draws it once when it is added, into a
/// picture kept in the app's Library; the bar tints that picture by its transparency, as it does a symbol. A setting holds the
/// picture's name, `svg:…`, in place of a symbol's; each file added has a name of its own.
@MainActor
enum TabBarIconFiles {
    private static let prefix = "svg:"

    static func isFile(_ name: String) -> Bool { name.hasPrefix(prefix) }

    /// The picture of an added file; nil for a symbol's name or where the file is not (a setting from another phone).
    static func image(_ name: String) -> UIImage? {
        guard isFile(name), let url = url(of: name) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    /// Draws the file `side` points square and keeps it; its name, nil when it cannot be read as a picture.
    static func add(from source: URL, side: CGFloat) async -> String? {
        let isScoped = source.startAccessingSecurityScopedResource()
        defer { if isScoped { source.stopAccessingSecurityScopedResource() } }
        guard let svg = try? Data(contentsOf: source), let picture = await SVGPicture.draw(svg, side: side), hasInk(picture),
              let png = picture.pngData() else { return nil }
        let name = prefix + UUID().uuidString
        guard let url = url(of: name) else { return nil }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        return (try? png.write(to: url)) == nil ? nil : name
    }

    static func remove(_ name: String) {
        guard isFile(name), let url = url(of: name) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private static func hasInk(_ picture: UIImage) -> Bool {
        let ink = InkBounds.of(picture, scale: picture.scale)
        return ink.width > 0 && ink.height > 0
    }

    private static func url(of name: String) -> URL? {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?
            .appendingPathComponent("TabBarIcons", isDirectory: true)
            .appendingPathComponent(String(name.dropFirst(prefix.count)) + ".png")
    }
}

/// One SVG file drawn by a web view that nobody sees, on a transparent page. As an image, not as markup: a script in the file
/// does not run and it reaches nothing.
@MainActor
private final class SVGPicture: NSObject, WKNavigationDelegate {
    private let web: WKWebView
    private var finished: CheckedContinuation<UIImage?, Never>?

    private init(side: CGFloat) {
        web = WKWebView(frame: CGRect(x: 0, y: 0, width: side, height: side))
        super.init()
        web.isOpaque = false
        web.backgroundColor = .clear
        web.scrollView.backgroundColor = .clear
        web.isUserInteractionEnabled = false
        web.navigationDelegate = self
    }

    static func draw(_ svg: Data, side: CGFloat) async -> UIImage? {
        let picture = SVGPicture(side: side)
        return await withCheckedContinuation { continuation in
            picture.finished = continuation
            let source = "data:image/svg+xml;base64," + svg.base64EncodedString()
            picture.web.loadHTMLString("""
            <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"></head>
            <body style="margin:0;background:transparent"><img src="\(source)" style="display:block;width:100vw;height:100vh;object-fit:contain"></body></html>
            """, baseURL: nil)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // A file that is no picture leaves a broken image, which has no size of its own.
        webView.evaluateJavaScript("document.images[0].naturalWidth") { [self] width, _ in
            guard (width as? Double ?? 0) > 0 else { return finish(nil) }
            webView.takeSnapshot(with: nil) { [self] image, _ in finish(image) }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { finish(nil) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { finish(nil) }

    private func finish(_ image: UIImage?) {
        finished?.resume(returning: image)
        finished = nil
    }
}
