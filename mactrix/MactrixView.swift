import ScreenSaver
import WebKit
import os.log

private let logger = OSLog(subsystem: "com.trehn.mactrix", category: "MactrixView")

// MARK: - WKWebView Private API for disabling window occlusion detection
extension WKWebView {
    @objc func mactrix_setWindowOcclusionDetectionEnabled(_ enabled: Bool) {
        let selector = NSSelectorFromString("_setWindowOcclusionDetectionEnabled:")
        if responds(to: selector) {
            perform(selector, with: NSNumber(value: enabled))
        }
    }
}

/// Main screensaver view that displays the Matrix digital rain effect
@objc(MactrixView)
class MactrixView: ScreenSaverView {
    
    private var webView: WKWebView?
    private var server: LocalServer?
    private var configSheetController: ConfigSheetController?
    private var screenID: String?
    private var hasStarted = false
    private var retryCount = 0
    private let maxRetries = 20  // 2 seconds max wait
    
    // MARK: - Initialization
    
    override init?(frame: NSRect, isPreview: Bool) {
        os_log("init(frame:isPreview:) called, frame: %{public}@, isPreview: %{public}d", log: logger, type: .info, String(describing: frame), isPreview)
        super.init(frame: frame, isPreview: isPreview)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        os_log("init(coder:) called", log: logger, type: .info)
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        os_log("commonInit called", log: logger, type: .info)
        
        // Set animation interval (though we rely on WebGL for animation)
        animationTimeInterval = 1.0 / 60.0
        
        // Ensure we have a layer for proper rendering
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
    }
    
    deinit {
        os_log("deinit called", log: logger, type: .info)
        stopServer()
        webView?.stopLoading()
        webView?.removeFromSuperview()
    }
    
    // MARK: - Screen ID
    
    private func getScreenID() -> String {
        if let screenID = screenID {
            return screenID
        }
        
        if let screen = window?.screen,
           let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
            screenID = String(screenNumber)
            return screenID!
        }
        
        return "default"
    }
    
    // MARK: - Web View Setup
    
    private func setupWebView() {
        guard webView == nil else {
            os_log("setupWebView: webView already exists", log: logger, type: .info)
            return
        }
        
        os_log("setupWebView: creating WKWebView", log: logger, type: .info)
        
        let config = WKWebViewConfiguration()
        let prefs = WKPreferences()
        
        // Security: disable JavaScript opening windows
        prefs.javaScriptCanOpenWindowsAutomatically = false
        config.preferences = prefs
        
        // Allow local file access
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        
        // Enable WebGL
        config.preferences.setValue(true, forKey: "webGLEnabled")
        
        // Set media preferences (no user interaction needed for media)
        config.mediaTypesRequiringUserActionForPlayback = []
        
        // Use the current bounds (should be valid by now)
        let webView = WKWebView(frame: bounds, configuration: config)
        webView.autoresizingMask = [.width, .height]
        webView.wantsLayer = true
        
        // Make background black (matching webviewscreensaver approach)
        webView.layer?.backgroundColor = CGColor(gray: 0.0, alpha: 1.0)
        
        // Enable transparent background via private API (used by webviewscreensaver)
        webView.setValue(false, forKey: "drawsBackground")
        
        // Set navigation delegate to handle errors
        webView.navigationDelegate = self
        
        // Set UI delegate for JavaScript alerts/console
        webView.uiDelegate = self
        
        // Disable window occlusion detection (critical for screensaver on Sonoma+)
        // This prevents the webview from pausing when it thinks the window is hidden
        if #available(macOS 14.0, *) {
            webView.mactrix_setWindowOcclusionDetectionEnabled(false)
            os_log("setupWebView: disabled window occlusion detection", log: logger, type: .info)
        }
        
        self.webView = webView
        addSubview(webView)
        
        os_log("setupWebView: WKWebView created and added to view", log: logger, type: .info)
    }
    
    // MARK: - Server Management
    
    private func startServer() -> URL? {
        guard server == nil else {
            os_log("startServer: server already exists", log: logger, type: .info)
            if let port = server?.port, port > 0 {
                return buildURL(port: port)
            }
            return nil
        }
        
        // Find the bundled matrix folder
        let bundle = Bundle(for: MactrixView.self)
        os_log("startServer: bundle path: %{public}@", log: logger, type: .info, bundle.bundlePath)
        
        guard let matrixURL = bundle.url(forResource: "matrix", withExtension: nil) else {
            os_log("startServer: Could not find matrix resources in bundle", log: logger, type: .error)
            // List bundle resources for debugging
            if let resourcePath = bundle.resourcePath {
                do {
                    let contents = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
                    os_log("startServer: Bundle resources: %{public}@", log: logger, type: .info, contents.joined(separator: ", "))
                } catch {
                    os_log("startServer: Failed to list bundle resources: %{public}@", log: logger, type: .error, error.localizedDescription)
                }
            }
            return nil
        }
        
        os_log("startServer: Found matrix resources at %{public}@", log: logger, type: .info, matrixURL.path)
        
        server = LocalServer(resourceURL: matrixURL)
        
        do {
            let port = try server!.start()
            os_log("startServer: Server started on port %{public}d", log: logger, type: .info, port)
            return buildURL(port: port)
        } catch {
            os_log("startServer: Failed to start server: %{public}@", log: logger, type: .error, error.localizedDescription)
            return nil
        }
    }
    
    private func stopServer() {
        os_log("stopServer called", log: logger, type: .info)
        server?.stop()
        server = nil
    }
    
    private func buildURL(port: UInt16) -> URL {
        let screenID = getScreenID()
        
        // Reload settings from disk (config sheet and screensaver run in different processes)
        SettingsManager.shared.reload()
        
        let queryString = SettingsManager.shared.buildQueryString(forScreen: screenID)
        
        var urlString = "http://127.0.0.1:\(port)/index.html"
        if !queryString.isEmpty {
            urlString += "?\(queryString)"
        }
        
        return URL(string: urlString)!
    }
    
    // MARK: - ScreenSaverView Lifecycle
    
    override func startAnimation() {
        os_log("startAnimation called, bounds: %{public}@", log: logger, type: .info, String(describing: bounds))
        super.startAnimation()
        
        // Setup webview now that we have valid bounds
        setupWebView()
        
        // Ensure webview frame matches our bounds
        webView?.frame = bounds
        
        // Start the server (but don't load URL yet - wait for window to be on screen)
        _ = startServerOnly()
        
        // Load content (will use screen ID if available, or load later in viewDidMoveToWindow)
        loadContentIfReady()
    }
    
    private func startServerOnly() -> Bool {
        guard server == nil else {
            return server?.port ?? 0 > 0
        }
        
        // Find the bundled matrix folder
        let bundle = Bundle(for: MactrixView.self)
        guard let matrixURL = bundle.url(forResource: "matrix", withExtension: nil) else {
            os_log("startServerOnly: Could not find matrix resources in bundle", log: logger, type: .error)
            return false
        }
        
        server = LocalServer(resourceURL: matrixURL)
        
        do {
            let port = try server!.start()
            os_log("startServerOnly: Server started on port %{public}d", log: logger, type: .info, port)
            return true
        } catch {
            os_log("startServerOnly: Failed to start server: %{public}@", log: logger, type: .error, error.localizedDescription)
            return false
        }
    }
    
    private func loadContentIfReady() {
        guard !hasStarted else { return }
        guard let port = server?.port, port > 0 else { return }
        
        // Don't load with "default" screen ID when per-monitor settings are enabled
        // Wait until we have a real screen ID
        let currentScreenID = getScreenID()
        if currentScreenID == "default" && SettingsManager.shared.usePerMonitorSettings {
            // Schedule a delayed check in case viewDidMoveToWindow doesn't fire
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.retryLoadContent()
            }
            return
        }
        
        // Build URL with current screen ID
        let url = buildURL(port: port)
        webView?.load(URLRequest(url: url))
        hasStarted = true
    }
    
    private func retryLoadContent() {
        guard !hasStarted else { return }
        
        retryCount += 1
        
        // Clear cached screen ID and try again
        screenID = nil
        let newScreenID = getScreenID()
        
        if newScreenID == "default" {
            if retryCount >= maxRetries {
                // Give up and use frame matching or global settings
                forceLoadWithDefaultScreen()
                return
            }
            // Still no screen, try again later
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.retryLoadContent()
            }
            return
        }
        
        loadContentIfReady()
    }
    
    private func forceLoadWithDefaultScreen() {
        guard !hasStarted else { return }
        guard let port = server?.port, port > 0 else { return }
        
        // Try to find our screen by matching frame with NSScreen.screens
        if let matchedScreenID = findScreenIDByFrame() {
            screenID = matchedScreenID
        } else {
            // Use "default" which will fall back to global settings
            screenID = "default"
        }
        
        let url = buildURL(port: port)
        webView?.load(URLRequest(url: url))
        hasStarted = true
    }
    
    private func findScreenIDByFrame() -> String? {
        // Try to match our window's frame with available screens
        guard let windowFrame = window?.frame else { return nil }
        
        // First try: match by size and X position (Y can differ due to coordinate systems)
        for screen in NSScreen.screens {
            let screenFrame = screen.frame
            if let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
                // Match by size (width and height should be identical for fullscreen)
                let sizeMatches = abs(windowFrame.width - screenFrame.width) < 1.0 &&
                                  abs(windowFrame.height - screenFrame.height) < 1.0
                // Match by X position
                let xMatches = abs(windowFrame.origin.x - screenFrame.origin.x) < 1.0
                
                if sizeMatches && xMatches {
                    return String(screenNumber)
                }
            }
        }
        
        // Fallback: try standard intersection (for cases where coordinates match)
        for screen in NSScreen.screens {
            let intersection = windowFrame.intersection(screen.frame)
            if !intersection.isNull {
                let overlapArea = intersection.width * intersection.height
                let windowArea = windowFrame.width * windowFrame.height
                if overlapArea > windowArea * 0.5 {
                    if let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
                        return String(screenNumber)
                    }
                }
            }
        }
        return nil
    }
    
    override func stopAnimation() {
        os_log("stopAnimation called", log: logger, type: .info)
        super.stopAnimation()
        
        // Stop the web view
        webView?.stopLoading()
        hasStarted = false
        
        // Note: We don't stop the server here because System Preferences
        // may call startAnimation/stopAnimation multiple times when switching
        // between preview and full screen. The server is stopped in deinit.
    }
    
    override func animateOneFrame() {
        // The WebGL content handles its own animation
        // We don't need to do anything here
    }
    
    override func draw(_ rect: NSRect) {
        // Draw black background
        NSColor.black.setFill()
        rect.fill()
        
        super.draw(rect)
    }
    
    override var hasConfigureSheet: Bool {
        return true
    }
    
    override var configureSheet: NSWindow? {
        os_log("configureSheet requested", log: logger, type: .info)
        
        if configSheetController == nil {
            os_log("configureSheet: creating ConfigSheetController", log: logger, type: .info)
            configSheetController = ConfigSheetController()
            configSheetController?.delegate = self
        }
        os_log("configureSheet: returning window: %{public}@", log: logger, type: .info, String(describing: configSheetController?.window))
        return configSheetController?.window
    }
    
    /// Reload the web content with fresh settings
    private func reloadContent() {
        os_log("reloadContent: reloading with fresh settings", log: logger, type: .info)
        SettingsManager.shared.reload()
        
        if let port = server?.port, port > 0 {
            let url = buildURL(port: port)
            webView?.load(URLRequest(url: url))
        }
    }
    
    // MARK: - Layout
    
    override func resize(withOldSuperviewSize oldSize: NSSize) {
        super.resize(withOldSuperviewSize: oldSize)
        webView?.frame = bounds
    }
    
    override func layout() {
        super.layout()
        webView?.frame = bounds
    }
    
    // MARK: - Preview Mode Handling
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        let oldScreenID = screenID
        
        // Update screen ID when window changes
        screenID = nil
        let newScreenID = getScreenID()
        
        os_log("viewDidMoveToWindow, window: %{public}d, oldScreenID: %{public}@, newScreenID: %{public}@", log: logger, type: .info, window != nil, oldScreenID ?? "nil", newScreenID)
        
        // If screen ID changed from "default" to a real ID, reload with correct settings
        if oldScreenID == nil || oldScreenID == "default", newScreenID != "default" {
            os_log("viewDidMoveToWindow: screen ID now available, reloading content", log: logger, type: .info)
            hasStarted = false  // Allow reload
            SettingsManager.shared.reload()
            loadContentIfReady()
        }
    }
}

// MARK: - WKNavigationDelegate

extension MactrixView: WKNavigationDelegate, WKUIDelegate {
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        os_log("Navigation failed: %{public}@", log: logger, type: .error, error.localizedDescription)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        os_log("Provisional navigation failed: %{public}@", log: logger, type: .error, error.localizedDescription)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        os_log("Page loaded successfully", log: logger, type: .info)
        
        // Log the current URL for debugging
        if let url = webView.url {
            os_log("Loaded URL: %{public}@", log: logger, type: .info, url.absoluteString)
        }
        
        // Check if WebGL is available
        webView.evaluateJavaScript("typeof WebGLRenderingContext !== 'undefined'") { result, error in
            if let hasWebGL = result as? Bool {
                os_log("WebGL available: %{public}d", log: logger, type: .info, hasWebGL)
            }
            if let error = error {
                os_log("WebGL check error: %{public}@", log: logger, type: .error, error.localizedDescription)
            }
        }
    }
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        os_log("Navigation committed", log: logger, type: .info)
    }
    
    // WKUIDelegate - handle JavaScript alerts for debugging
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        os_log("JavaScript alert: %{public}@", log: logger, type: .info, message)
        completionHandler()
    }
    
    // Track web content process termination
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        os_log("WebContent process terminated unexpectedly!", log: logger, type: .error)
    }
}

// MARK: - ConfigSheetControllerDelegate

extension MactrixView: ConfigSheetControllerDelegate {
    func configSheetDidSave(_ controller: ConfigSheetController) {
        os_log("configSheetDidSave: reloading content", log: logger, type: .info)
        if isPreview {
            reloadContent()
        }
    }
}
