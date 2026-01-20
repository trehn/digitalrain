import Foundation
import Network
import os.log

private let serverLogger = OSLog(subsystem: "com.trehn.mactrix", category: "LocalServer")

/// A minimal HTTP server that serves static files from the bundled matrix web app
class LocalServer {
    
    private var listener: NWListener?
    private let resourceURL: URL
    private let queue = DispatchQueue(label: "com.trehn.mactrix.server", qos: .userInteractive)
    private var connections: [NWConnection] = []
    private(set) var port: UInt16 = 0
    private(set) var isRunning = false
    
    // MIME type mapping for web resources
    private let mimeTypes: [String: String] = [
        "html": "text/html; charset=utf-8",
        "htm": "text/html; charset=utf-8",
        "js": "application/javascript; charset=utf-8",
        "mjs": "application/javascript; charset=utf-8",
        "css": "text/css; charset=utf-8",
        "json": "application/json; charset=utf-8",
        "png": "image/png",
        "jpg": "image/jpeg",
        "jpeg": "image/jpeg",
        "gif": "image/gif",
        "svg": "image/svg+xml",
        "webp": "image/webp",
        "ico": "image/x-icon",
        "woff": "font/woff",
        "woff2": "font/woff2",
        "ttf": "font/ttf",
        "otf": "font/otf",
        "glsl": "text/plain; charset=utf-8",
        "wgsl": "text/plain; charset=utf-8",
        "vert": "text/plain; charset=utf-8",
        "frag": "text/plain; charset=utf-8",
        "txt": "text/plain; charset=utf-8",
        "xml": "application/xml; charset=utf-8",
        "mp3": "audio/mpeg",
        "wav": "audio/wav",
        "ogg": "audio/ogg",
        "mp4": "video/mp4",
        "webm": "video/webm",
    ]
    
    init(resourceURL: URL) {
        self.resourceURL = resourceURL
    }
    
    /// Start the HTTP server on a random available port
    /// Returns the port number on success
    func start() throws -> UInt16 {
        guard !isRunning else { return port }
        
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        
        // Use port 0 to let the system assign an available port
        listener = try NWListener(using: parameters, on: .any)
        
        listener?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                if let port = self?.listener?.port?.rawValue {
                    self?.port = port
                    self?.isRunning = true
                }
            case .failed(let error):
                os_log("LocalServer failed: %{public}@", log: serverLogger, type: .error, error.localizedDescription)
                self?.isRunning = false
            case .cancelled:
                self?.isRunning = false
            default:
                break
            }
        }
        
        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }
        
        listener?.start(queue: queue)
        
        // Wait briefly for the port to be assigned
        var attempts = 0
        while port == 0 && attempts < 50 {
            Thread.sleep(forTimeInterval: 0.01)
            attempts += 1
        }
        
        if port == 0 {
            throw NSError(domain: "LocalServer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to start server"])
        }
        
        return port
    }
    
    /// Stop the HTTP server
    func stop() {
        listener?.cancel()
        listener = nil
        
        for connection in connections {
            connection.cancel()
        }
        connections.removeAll()
        
        isRunning = false
        port = 0
    }
    
    // MARK: - Connection Handling
    
    private func handleConnection(_ connection: NWConnection) {
        connections.append(connection)
        
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            switch state {
            case .ready:
                self?.receiveRequest(connection!)
            case .failed, .cancelled:
                if let conn = connection {
                    self?.connections.removeAll { $0 === conn }
                }
            default:
                break
            }
        }
        
        connection.start(queue: queue)
    }
    
    private func receiveRequest(_ connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self, let data = data, !data.isEmpty else {
                connection.cancel()
                return
            }
            
            if let request = String(data: data, encoding: .utf8) {
                self.handleRequest(request, connection: connection)
            } else {
                self.sendError(400, message: "Bad Request", connection: connection)
            }
        }
    }
    
    private func handleRequest(_ request: String, connection: NWConnection) {
        // Parse the HTTP request line
        let lines = request.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            sendError(400, message: "Bad Request", connection: connection)
            return
        }
        
        let parts = requestLine.components(separatedBy: " ")
        guard parts.count >= 2 else {
            sendError(400, message: "Bad Request", connection: connection)
            return
        }
        
        let method = parts[0]
        var path = parts[1]
        
        // Only handle GET requests
        guard method == "GET" else {
            sendError(405, message: "Method Not Allowed", connection: connection)
            return
        }
        
        // Remove query string for file lookup
        if let queryIndex = path.firstIndex(of: "?") {
            path = String(path[..<queryIndex])
        }
        
        // URL decode the path
        path = path.removingPercentEncoding ?? path
        
        // Default to index.html
        if path == "/" {
            path = "/index.html"
        }
        
        // Security: prevent directory traversal
        let normalizedPath = path.replacingOccurrences(of: "../", with: "")
        
        // Build the file URL
        let fileURL = resourceURL.appendingPathComponent(String(normalizedPath.dropFirst()))
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            sendError(404, message: "Not Found", connection: connection)
            return
        }
        
        // Read and serve the file
        do {
            let fileData = try Data(contentsOf: fileURL)
            let mimeType = mimeType(for: fileURL.pathExtension)
            sendResponse(200, mimeType: mimeType, body: fileData, connection: connection)
        } catch {
            sendError(500, message: "Internal Server Error", connection: connection)
        }
    }
    
    // MARK: - Response Helpers
    
    private func mimeType(for extension: String) -> String {
        return mimeTypes[`extension`.lowercased()] ?? "application/octet-stream"
    }
    
    private func sendResponse(_ status: Int, mimeType: String, body: Data, connection: NWConnection) {
        let statusText = httpStatusText(status)
        var header = "HTTP/1.1 \(status) \(statusText)\r\n"
        header += "Content-Type: \(mimeType)\r\n"
        header += "Content-Length: \(body.count)\r\n"
        header += "Connection: close\r\n"
        header += "Access-Control-Allow-Origin: *\r\n"
        header += "Cache-Control: no-cache\r\n"
        header += "\r\n"
        
        var responseData = header.data(using: .utf8)!
        responseData.append(body)
        
        connection.send(content: responseData, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
    
    private func sendError(_ status: Int, message: String, connection: NWConnection) {
        let body = "<html><body><h1>\(status) \(message)</h1></body></html>"
        let bodyData = body.data(using: .utf8)!
        sendResponse(status, mimeType: "text/html; charset=utf-8", body: bodyData, connection: connection)
    }
    
    private func httpStatusText(_ status: Int) -> String {
        switch status {
        case 200: return "OK"
        case 400: return "Bad Request"
        case 404: return "Not Found"
        case 405: return "Method Not Allowed"
        case 500: return "Internal Server Error"
        default: return "Unknown"
        }
    }
}
