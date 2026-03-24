import Foundation
import Network

/// Minimal localhost HTTP server for WKWebView content delivery.
/// Provides proper Referer headers so YouTube iframes work.
@Observable
final class LocalHTTPServer {

    static let shared = LocalHTTPServer()

    private(set) var port: UInt16 = 0
    private var listener: NWListener?
    private let contentLock = NSLock()
    private var _currentHTML: String = ""
    private var _baseDirectoryURL: URL?

    private var currentHTML: String {
        contentLock.withLock { _currentHTML }
    }
    private var baseDirectoryURL: URL? {
        contentLock.withLock { _baseDirectoryURL }
    }

    var previewURL: URL? {
        guard port > 0 else { return nil }
        return URL(string: "http://localhost:\(port)/preview")
    }

    private init() {}

    func start() {
        guard listener == nil else { return }
        do {
            let params = NWParameters.tcp
            let listener = try NWListener(using: params, on: .any)
            listener.stateUpdateHandler = { [weak self] state in
                if case .ready = state, let port = listener.port {
                    self?.port = port.rawValue
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }
            listener.start(queue: .global(qos: .userInitiated))
            self.listener = listener
        } catch {
            print("LocalHTTPServer start failed: \(error)")
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        port = 0
    }

    func updateContent(html: String, baseDirectory: URL?) {
        contentLock.withLock {
            _currentHTML = html
            _baseDirectoryURL = baseDirectory
        }
    }

    // MARK: - Connection handling

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, _ in
            guard let self, let data, let request = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }
            self.route(request: request, connection: connection)
        }
    }

    private func route(request: String, connection: NWConnection) {
        let lines = request.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            connection.cancel()
            return
        }

        let parts = requestLine.components(separatedBy: " ")
        guard parts.count >= 2 else {
            connection.cancel()
            return
        }

        let path = parts[1]

        if path == "/preview" || path == "/preview/" {
            serveHTML(connection: connection)
        } else if path.hasPrefix("/file/") {
            let filePath = String(path.dropFirst(5)).removingPercentEncoding ?? ""
            serveFile(path: filePath, connection: connection)
        } else {
            serve404(connection: connection)
        }
    }

    private func serveHTML(connection: NWConnection) {
        let html = rewriteFileURLs(in: currentHTML)
        let body = html.data(using: .utf8) ?? Data()
        let header = """
        HTTP/1.1 200 OK\r\n\
        Content-Type: text/html; charset=utf-8\r\n\
        Content-Length: \(body.count)\r\n\
        Access-Control-Allow-Origin: *\r\n\
        Connection: close\r\n\
        \r\n
        """
        send(header: header, body: body, connection: connection)
    }

    private func serveFile(path: String, connection: NWConnection) {
        guard let base = baseDirectoryURL else {
            serve404(connection: connection)
            return
        }

        // Resolve path: absolute paths as-is, relative paths against base
        let fileURL: URL
        if path.hasPrefix("/") {
            fileURL = URL(fileURLWithPath: path).standardizedFileURL
        } else {
            fileURL = base.appendingPathComponent(path).standardizedFileURL
        }

        // Verify resolved path stays within base directory (prevents path traversal)
        guard fileURL.path.hasPrefix(base.standardizedFileURL.path) else {
            serve404(connection: connection)
            return
        }

        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL) else {
            serve404(connection: connection)
            return
        }

        let mime = mimeType(for: fileURL.pathExtension)
        let header = """
        HTTP/1.1 200 OK\r\n\
        Content-Type: \(mime)\r\n\
        Content-Length: \(data.count)\r\n\
        Connection: close\r\n\
        \r\n
        """
        send(header: header, body: data, connection: connection)
    }

    private func serve404(connection: NWConnection) {
        let body = "Not Found".data(using: .utf8)!
        let header = """
        HTTP/1.1 404 Not Found\r\n\
        Content-Length: \(body.count)\r\n\
        Connection: close\r\n\
        \r\n
        """
        send(header: header, body: body, connection: connection)
    }

    private func send(header: String, body: Data, connection: NWConnection) {
        var packet = header.data(using: .utf8) ?? Data()
        packet.append(body)
        connection.send(content: packet, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    /// Rewrite file:// URLs to localhost server URLs at serve time.
    /// This ensures rewriting always works, even on first load when
    /// the port wasn't available during HTML template wrapping.
    private func rewriteFileURLs(in html: String) -> String {
        guard port > 0 else { return html }
        let pattern = #"(src\s*=\s*")(file://[^"]+)(")"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return html }
        let mutable = NSMutableString(string: html)
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: mutable.length))
        for match in matches.reversed() {
            let fileURLRange = match.range(at: 2)
            let fileURLString = (html as NSString).substring(with: fileURLRange)
            if let fileURL = URL(string: fileURLString) {
                let serverPath = "http://localhost:\(port)/file\(fileURL.path)"
                mutable.replaceCharacters(in: fileURLRange, with: serverPath)
            }
        }
        return mutable as String
    }

    private func mimeType(for ext: String) -> String {
        switch ext.lowercased() {
        case "png": "image/png"
        case "jpg", "jpeg": "image/jpeg"
        case "gif": "image/gif"
        case "svg": "image/svg+xml"
        case "webp": "image/webp"
        case "pdf": "application/pdf"
        case "css": "text/css"
        case "js": "application/javascript"
        default: "application/octet-stream"
        }
    }
}
