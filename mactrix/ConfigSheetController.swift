import AppKit
import ScreenSaver
import os.log

private let configLogger = OSLog(subsystem: "com.trehn.mactrix", category: "ConfigSheet")

/// Delegate protocol for config sheet dismissal
protocol ConfigSheetControllerDelegate: AnyObject {
    func configSheetDidSave(_ controller: ConfigSheetController)
}

/// Controller for the screensaver configuration sheet
class ConfigSheetController: NSObject {
    
    let window: NSWindow
    private let settings = SettingsManager.shared
    private var currentScreenID: String?
    weak var delegate: ConfigSheetControllerDelegate?
    
    // In-memory cache for settings while config sheet is open
    // Key format: "settingName" for global, "settingName_screenID" for per-screen
    private var settingsCache: [String: Any] = [:]
    private var cachedUsePerMonitorSettings: Bool = false
    
    // MARK: - UI Elements
    
    // Monitor settings
    private var perMonitorCheckbox: NSButton!
    private var monitorPopup: NSPopUpButton!
    private var copyToAllButton: NSButton!
    
    // Tab view
    private var tabView: NSTabView!
    
    // Presets tab
    private var versionPopup: NSPopUpButton!
    private var fontPopup: NSPopUpButton!
    
    // Animation tab
    private var animationSpeedSlider: NSSlider!
    private var animationSpeedLabel: NSTextField!
    private var fallSpeedSlider: NSSlider!
    private var fallSpeedLabel: NSTextField!
    private var cycleSpeedSlider: NSSlider!
    private var cycleSpeedLabel: NSTextField!
    private var cycleFrameSkipSlider: NSSlider!
    private var cycleFrameSkipLabel: NSTextField!
    private var forwardSpeedSlider: NSSlider!
    private var forwardSpeedLabel: NSTextField!
    private var raindropLengthSlider: NSSlider!
    private var raindropLengthLabel: NSTextField!
    private var fpsSlider: NSSlider!
    private var fpsLabel: NSTextField!
    private var brightnessDecaySlider: NSSlider!
    private var brightnessDecayLabel: NSTextField!
    
    // Appearance tab
    private var numColumnsSlider: NSSlider!
    private var numColumnsLabel: NSTextField!
    private var resolutionSlider: NSSlider!
    private var resolutionLabel: NSTextField!
    private var densitySlider: NSSlider!
    private var densityLabel: NSTextField!
    private var glyphHeightToWidthSlider: NSSlider!
    private var glyphHeightToWidthLabel: NSTextField!
    private var glyphVerticalSpacingSlider: NSSlider!
    private var glyphVerticalSpacingLabel: NSTextField!
    private var glyphEdgeCropSlider: NSSlider!
    private var glyphEdgeCropLabel: NSTextField!
    private var glyphFlipCheckbox: NSButton!
    private var glyphRotationSlider: NSSlider!
    private var glyphRotationLabel: NSTextField!
    private var slantSlider: NSSlider!
    private var slantLabel: NSTextField!
    private var volumetricCheckbox: NSButton!
    private var isometricCheckbox: NSButton!
    private var isPolarCheckbox: NSButton!
    private var baseTexturePopup: NSPopUpButton!
    private var glintTexturePopup: NSPopUpButton!
    
    // Colors tab
    private var backgroundColorWell: NSColorWell!
    private var cursorColorWell: NSColorWell!
    private var glintColorWell: NSColorWell!
    private var cursorIntensitySlider: NSSlider!
    private var cursorIntensityLabel: NSTextField!
    private var glintIntensitySlider: NSSlider!
    private var glintIntensityLabel: NSTextField!
    private var isolateCursorCheckbox: NSButton!
    private var isolateGlintCheckbox: NSButton!
    private var baseBrightnessSlider: NSSlider!
    private var baseBrightnessLabel: NSTextField!
    private var baseContrastSlider: NSSlider!
    private var baseContrastLabel: NSTextField!
    private var glintBrightnessSlider: NSSlider!
    private var glintBrightnessLabel: NSTextField!
    private var glintContrastSlider: NSSlider!
    private var glintContrastLabel: NSTextField!
    private var brightnessOverrideSlider: NSSlider!
    private var brightnessOverrideLabel: NSTextField!
    private var brightnessThresholdSlider: NSSlider!
    private var brightnessThresholdLabel: NSTextField!
    
    // Effects tab
    private var effectPopup: NSPopUpButton!
    private var bloomStrengthSlider: NSSlider!
    private var bloomStrengthLabel: NSTextField!
    private var bloomSizeSlider: NSSlider!
    private var bloomSizeLabel: NSTextField!
    private var highPassThresholdSlider: NSSlider!
    private var highPassThresholdLabel: NSTextField!
    private var ditherMagnitudeSlider: NSSlider!
    private var ditherMagnitudeLabel: NSTextField!
    private var hasThunderCheckbox: NSButton!
    private var rippleTypePopup: NSPopUpButton!
    private var rippleScaleSlider: NSSlider!
    private var rippleScaleLabel: NSTextField!
    private var rippleThicknessSlider: NSSlider!
    private var rippleThicknessLabel: NSTextField!
    private var rippleSpeedSlider: NSSlider!
    private var rippleSpeedLabel: NSTextField!
    
    // Advanced tab
    private var rendererPopup: NSPopUpButton!
    private var useHalfFloatCheckbox: NSButton!
    private var skipIntroCheckbox: NSButton!
    private var loopsCheckbox: NSButton!
    
    // URL preview
    private var urlPreviewField: NSTextField!
    private var currentURLString: String = "https://rezmason.github.io/matrix/"
    
    // MARK: - Initialization
    
    override init() {
        // Create the window
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 720),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.title = "Mactrix Settings"
        
        super.init()
        
        setupUI()
        initializeCache()
        loadSettings()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        let contentView = NSView(frame: window.contentView!.bounds)
        window.contentView = contentView
        
        let padding: CGFloat = 20
        var y = contentView.bounds.height - padding
        
        // Monitor settings section
        y = setupMonitorSection(in: contentView, y: y)
        
        // Separator
        y -= 15
        let separator = NSBox(frame: NSRect(x: padding, y: y, width: contentView.bounds.width - padding * 2, height: 1))
        separator.boxType = .separator
        contentView.addSubview(separator)
        y -= 15
        
        // Tab view (leave space for URL preview and buttons at bottom)
        let bottomAreaHeight: CGFloat = 200
        tabView = NSTabView(frame: NSRect(x: padding, y: bottomAreaHeight, width: contentView.bounds.width - padding * 2, height: y - bottomAreaHeight))
        contentView.addSubview(tabView)
        
        // Create tabs
        setupPresetsTab()
        setupAnimationTab()
        setupAppearanceTab()
        setupColorsTab()
        setupEffectsTab()
        setupAdvancedTab()
        
        // URL preview label
        let urlLabel = NSTextField(labelWithString: "Preview URL (real screensaver uses local copy):")
        urlLabel.frame = NSRect(x: padding, y: 168, width: 300, height: 17)
        contentView.addSubview(urlLabel)
        
        // URL preview scroll view with text view (readonly, selectable, multiline)
        let scrollView = NSScrollView(frame: NSRect(x: padding, y: 50, width: contentView.bounds.width - padding * 2, height: 115))
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder
        
        urlPreviewField = NSTextField(frame: NSRect(x: 0, y: 0, width: scrollView.contentSize.width, height: scrollView.contentSize.height))
        urlPreviewField.isEditable = false
        urlPreviewField.isSelectable = true
        urlPreviewField.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        urlPreviewField.backgroundColor = NSColor.textBackgroundColor
        urlPreviewField.isBezeled = false
        urlPreviewField.drawsBackground = true
        urlPreviewField.cell?.wraps = true
        urlPreviewField.cell?.isScrollable = false
        urlPreviewField.maximumNumberOfLines = 0
        scrollView.documentView = urlPreviewField
        contentView.addSubview(scrollView)
        
        // Buttons at bottom
        var buttonX: CGFloat = padding
        
        // Reset to Defaults button
        let resetButton = NSButton(frame: NSRect(x: buttonX, y: 12, width: 120, height: 32))
        resetButton.title = "Reset to Defaults"
        resetButton.bezelStyle = .rounded
        resetButton.target = self
        resetButton.action = #selector(resetToDefaultsClicked)
        contentView.addSubview(resetButton)
        buttonX += 130
        
        // Sync Monitors button (moved from monitor section)
        copyToAllButton = NSButton(frame: NSRect(x: buttonX, y: 12, width: 110, height: 32))
        copyToAllButton.title = "Sync Monitors"
        copyToAllButton.bezelStyle = .rounded
        copyToAllButton.target = self
        copyToAllButton.action = #selector(copyToAllClicked)
        contentView.addSubview(copyToAllButton)
        buttonX += 140
        
        // Copy URL button
        let copyURLButton = NSButton(frame: NSRect(x: buttonX, y: 12, width: 80, height: 32))
        copyURLButton.title = "Copy URL"
        copyURLButton.bezelStyle = .rounded
        copyURLButton.target = self
        copyURLButton.action = #selector(copyURLClicked)
        contentView.addSubview(copyURLButton)
        
        // Cancel button
        let cancelButton = NSButton(frame: NSRect(x: contentView.bounds.width - 190, y: 12, width: 80, height: 32))
        cancelButton.title = "Cancel"
        cancelButton.bezelStyle = .rounded
        cancelButton.target = self
        cancelButton.action = #selector(cancelClicked)
        contentView.addSubview(cancelButton)
        
        // OK button
        let okButton = NSButton(frame: NSRect(x: contentView.bounds.width - 100, y: 12, width: 80, height: 32))
        okButton.title = "OK"
        okButton.bezelStyle = .rounded
        okButton.keyEquivalent = "\r"
        okButton.target = self
        okButton.action = #selector(okClicked)
        contentView.addSubview(okButton)
    }
    
    private func setupMonitorSection(in view: NSView, y: CGFloat) -> CGFloat {
        let currentY = y - 25
        let padding: CGFloat = 20
        
        // Per-monitor checkbox
        perMonitorCheckbox = NSButton(checkboxWithTitle: "Customize each monitor individually", target: self, action: #selector(perMonitorChanged))
        perMonitorCheckbox.frame = NSRect(x: padding, y: currentY, width: 280, height: 20)
        view.addSubview(perMonitorCheckbox)
        
        // Monitor selector
        let monitorLabel = NSTextField(labelWithString: "Monitor:")
        monitorLabel.frame = NSRect(x: 320, y: currentY, width: 60, height: 20)
        view.addSubview(monitorLabel)
        
        monitorPopup = NSPopUpButton(frame: NSRect(x: 380, y: currentY - 2, width: 160, height: 25))
        monitorPopup.target = self
        monitorPopup.action = #selector(monitorChanged)
        view.addSubview(monitorPopup)
        
        updateMonitorUI()
        
        return currentY
    }
    
    private func updateMonitorUI() {
        let enabled = perMonitorCheckbox.state == .on
        monitorPopup.isEnabled = enabled
        copyToAllButton?.isEnabled = enabled
        
        // Update monitor popup
        monitorPopup.removeAllItems()
        for (index, screen) in NSScreen.screens.enumerated() {
            let name = screen.localizedName
            monitorPopup.addItem(withTitle: "\(index + 1): \(name)")
            if let screenID = settings.screenID(for: screen) {
                monitorPopup.lastItem?.representedObject = screenID
            }
        }
        
        // Select current screen if any, or select first monitor
        if let currentID = currentScreenID {
            for i in 0..<monitorPopup.numberOfItems {
                if let itemID = monitorPopup.item(at: i)?.representedObject as? String, itemID == currentID {
                    monitorPopup.selectItem(at: i)
                    break
                }
            }
        } else if enabled && monitorPopup.numberOfItems > 0 {
            // Auto-select first monitor when per-monitor is enabled
            monitorPopup.selectItem(at: 0)
            if let screenID = monitorPopup.item(at: 0)?.representedObject as? String {
                currentScreenID = screenID
            }
        }
    }
    
    // MARK: - Tab Setup
    
    private func setupPresetsTab() {
        let tabItem = NSTabViewItem(identifier: "presets")
        tabItem.label = "Presets"
        
        let view = NSView(frame: tabView.contentRect)
        tabItem.view = view
        
        var y = view.bounds.height - 30
        
        // Version
        y = addPopupRow(to: view, y: y, label: "Version:", items: SettingsManager.availableVersions) { popup in
            self.versionPopup = popup
        }
        
        // Font
        y = addPopupRow(to: view, y: y, label: "Font:", items: SettingsManager.availableFonts) { popup in
            self.fontPopup = popup
        }
        
        tabView.addTabViewItem(tabItem)
    }
    
    private func scrollToTop(_ scrollView: NSScrollView) {
        if let documentView = scrollView.documentView {
            let topPoint = NSPoint(x: 0, y: documentView.bounds.height - scrollView.contentSize.height)
            documentView.scroll(topPoint)
        }
    }
    
    private func setupAnimationTab() {
        let tabItem = NSTabViewItem(identifier: "animation")
        tabItem.label = "Animation"
        
        let scrollView = NSScrollView(frame: tabView.contentRect)
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        
        let view = NSView(frame: NSRect(x: 0, y: 0, width: tabView.contentRect.width - 20, height: 320))
        scrollView.documentView = view
        tabItem.view = scrollView
        scrollToTop(scrollView)
        
        var y = view.bounds.height - 30
        
        y = addSliderRow(to: view, y: y, label: "Animation Speed:", min: 0.1, max: 3.0, value: 1.0) { slider, label in
            self.animationSpeedSlider = slider
            self.animationSpeedLabel = label
        }
        
        y = addSliderRow(to: view, y: y, label: "Fall Speed:", min: 0.01, max: 2.0, value: 0.3) { slider, label in
            self.fallSpeedSlider = slider
            self.fallSpeedLabel = label
        }
        
        y = addSliderRow(to: view, y: y, label: "Cycle Speed:", min: 0.005, max: 0.5, value: 0.03) { slider, label in
            self.cycleSpeedSlider = slider
            self.cycleSpeedLabel = label
        }
        
        y = addSliderRow(to: view, y: y, label: "Cycle Frame Skip:", min: 1, max: 30, value: 1, isInteger: true) { slider, label in
            self.cycleFrameSkipSlider = slider
            self.cycleFrameSkipLabel = label
        }
        
        y = addSliderRow(to: view, y: y, label: "Forward Speed:", min: 0.0, max: 1.0, value: 0.25) { slider, label in
            self.forwardSpeedSlider = slider
            self.forwardSpeedLabel = label
        }
        
        y = addSliderRow(to: view, y: y, label: "Raindrop Length:", min: 0.1, max: 2.0, value: 0.75) { slider, label in
            self.raindropLengthSlider = slider
            self.raindropLengthLabel = label
        }
        
        y = addSliderRow(to: view, y: y, label: "FPS:", min: 15, max: 60, value: 60, isInteger: true) { slider, label in
            self.fpsSlider = slider
            self.fpsLabel = label
        }
        
        y = addSliderRow(to: view, y: y, label: "Brightness Decay:", min: 0.01, max: 2.0, value: 1.0) { slider, label in
            self.brightnessDecaySlider = slider
            self.brightnessDecayLabel = label
        }
        
        tabView.addTabViewItem(tabItem)
    }
    
    private func setupAppearanceTab() {
        let tabItem = NSTabViewItem(identifier: "appearance")
        tabItem.label = "Appearance"
        
        let scrollView = NSScrollView(frame: tabView.contentRect)
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        
        let view = NSView(frame: NSRect(x: 0, y: 0, width: tabView.contentRect.width - 20, height: 560))
        scrollView.documentView = view
        tabItem.view = scrollView
        scrollToTop(scrollView)
        
        var y = view.bounds.height - 30
        
        y = addSliderRow(to: view, y: y, label: "Columns:", min: 10, max: 200, value: 80, isInteger: true) { slider, label in
            self.numColumnsSlider = slider
            self.numColumnsLabel = label
        }
        
        y = addSliderRow(to: view, y: y, label: "Resolution:", min: 0.25, max: 1.5, value: 0.75) { slider, label in
            self.resolutionSlider = slider
            self.resolutionLabel = label
        }
        
        y = addSliderRow(to: view, y: y, label: "Density:", min: 0.1, max: 3.0, value: 1.0) { slider, label in
            self.densitySlider = slider
            self.densityLabel = label
        }
        
        y = addSliderRow(to: view, y: y, label: "Glyph Height/Width:", min: 0.5, max: 2.0, value: 1.0) { slider, label in
            self.glyphHeightToWidthSlider = slider
            self.glyphHeightToWidthLabel = label
        }
        
        y = addSliderRow(to: view, y: y, label: "Vertical Spacing:", min: 0.5, max: 2.0, value: 1.0) { slider, label in
            self.glyphVerticalSpacingSlider = slider
            self.glyphVerticalSpacingLabel = label
        }
        
        y = addSliderRow(to: view, y: y, label: "Edge Crop:", min: 0.0, max: 0.3, value: 0.0) { slider, label in
            self.glyphEdgeCropSlider = slider
            self.glyphEdgeCropLabel = label
        }
        
        y = addCheckboxRow(to: view, y: y, label: "Flip Glyphs") { checkbox in
            self.glyphFlipCheckbox = checkbox
        }
        
        y = addSliderRow(to: view, y: y, label: "Glyph Rotation:", min: 0, max: 270, value: 0, isInteger: true, step: 90) { slider, label in
            self.glyphRotationSlider = slider
            self.glyphRotationLabel = label
        }
        
        y = addSliderRow(to: view, y: y, label: "Slant (degrees):", min: -45, max: 45, value: 0) { slider, label in
            self.slantSlider = slider
            self.slantLabel = label
        }
        
        y = addCheckboxRow(to: view, y: y, label: "Volumetric (3D)") { checkbox in
            self.volumetricCheckbox = checkbox
        }
        
        y = addCheckboxRow(to: view, y: y, label: "Isometric") { checkbox in
            self.isometricCheckbox = checkbox
        }
        
        y = addCheckboxRow(to: view, y: y, label: "Polar") { checkbox in
            self.isPolarCheckbox = checkbox
        }
        
        y = addPopupRow(to: view, y: y, label: "Base Texture:", items: SettingsManager.availableTextures) { popup in
            self.baseTexturePopup = popup
        }
        
        y = addPopupRow(to: view, y: y, label: "Glint Texture:", items: SettingsManager.availableTextures) { popup in
            self.glintTexturePopup = popup
        }
        
        tabView.addTabViewItem(tabItem)
    }
    
    private func setupColorsTab() {
        let tabItem = NSTabViewItem(identifier: "colors")
        tabItem.label = "Colors"
        
        let scrollView = NSScrollView(frame: tabView.contentRect)
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        
        let view = NSView(frame: NSRect(x: 0, y: 0, width: tabView.contentRect.width - 20, height: 480))
        scrollView.documentView = view
        tabItem.view = scrollView
        scrollToTop(scrollView)
        
        var y = view.bounds.height - 30
        
        y = addColorRow(to: view, y: y, label: "Background Color:") { colorWell in
            self.backgroundColorWell = colorWell
        }
        
        y = addColorRow(to: view, y: y, label: "Cursor Color:") { colorWell in
            self.cursorColorWell = colorWell
        }
        
        y = addColorRow(to: view, y: y, label: "Glint Color:") { colorWell in
            self.glintColorWell = colorWell
        }
        
        y = addSliderRow(to: view, y: y, label: "Cursor Intensity:", min: 0.0, max: 5.0, value: 2.0) { slider, label in
            self.cursorIntensitySlider = slider
            self.cursorIntensityLabel = label
        }
        
        y = addSliderRow(to: view, y: y, label: "Glint Intensity:", min: 0.0, max: 5.0, value: 1.0) { slider, label in
            self.glintIntensitySlider = slider
            self.glintIntensityLabel = label
        }
        
        y = addCheckboxRow(to: view, y: y, label: "Isolate Cursor") { checkbox in
            self.isolateCursorCheckbox = checkbox
        }
        
        y = addCheckboxRow(to: view, y: y, label: "Isolate Glint") { checkbox in
            self.isolateGlintCheckbox = checkbox
        }
        
        y = addSliderRow(to: view, y: y, label: "Base Brightness:", min: -2.0, max: 1.0, value: -0.5) { slider, label in
            self.baseBrightnessSlider = slider
            self.baseBrightnessLabel = label
        }
        
        y = addSliderRow(to: view, y: y, label: "Base Contrast:", min: 0.5, max: 3.0, value: 1.1) { slider, label in
            self.baseContrastSlider = slider
            self.baseContrastLabel = label
        }
        
        y = addSliderRow(to: view, y: y, label: "Glint Brightness:", min: -2.0, max: 1.0, value: -1.5) { slider, label in
            self.glintBrightnessSlider = slider
            self.glintBrightnessLabel = label
        }
        
        y = addSliderRow(to: view, y: y, label: "Glint Contrast:", min: 0.5, max: 5.0, value: 2.5) { slider, label in
            self.glintContrastSlider = slider
            self.glintContrastLabel = label
        }
        
        y = addSliderRow(to: view, y: y, label: "Brightness Override:", min: 0.0, max: 1.0, value: 0.0) { slider, label in
            self.brightnessOverrideSlider = slider
            self.brightnessOverrideLabel = label
        }
        
        y = addSliderRow(to: view, y: y, label: "Brightness Threshold:", min: 0.0, max: 1.0, value: 0.0) { slider, label in
            self.brightnessThresholdSlider = slider
            self.brightnessThresholdLabel = label
        }
        
        tabView.addTabViewItem(tabItem)
    }
    
    private func setupEffectsTab() {
        let tabItem = NSTabViewItem(identifier: "effects")
        tabItem.label = "Effects"
        
        let scrollView = NSScrollView(frame: tabView.contentRect)
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        
        let view = NSView(frame: NSRect(x: 0, y: 0, width: tabView.contentRect.width - 20, height: 400))
        scrollView.documentView = view
        tabItem.view = scrollView
        scrollToTop(scrollView)
        
        var y = view.bounds.height - 30
        
        y = addPopupRow(to: view, y: y, label: "Effect:", items: SettingsManager.availableEffects) { popup in
            self.effectPopup = popup
        }
        
        y = addSliderRow(to: view, y: y, label: "Bloom Strength:", min: 0.0, max: 1.0, value: 0.7) { slider, label in
            self.bloomStrengthSlider = slider
            self.bloomStrengthLabel = label
        }
        
        y = addSliderRow(to: view, y: y, label: "Bloom Size:", min: 0.0, max: 1.0, value: 0.4) { slider, label in
            self.bloomSizeSlider = slider
            self.bloomSizeLabel = label
        }
        
        y = addSliderRow(to: view, y: y, label: "High Pass Threshold:", min: 0.0, max: 1.0, value: 0.1) { slider, label in
            self.highPassThresholdSlider = slider
            self.highPassThresholdLabel = label
        }
        
        y = addSliderRow(to: view, y: y, label: "Dither Magnitude:", min: 0.0, max: 0.2, value: 0.05) { slider, label in
            self.ditherMagnitudeSlider = slider
            self.ditherMagnitudeLabel = label
        }
        
        y = addCheckboxRow(to: view, y: y, label: "Thunder Effect") { checkbox in
            self.hasThunderCheckbox = checkbox
        }
        
        y = addPopupRow(to: view, y: y, label: "Ripple Type:", items: SettingsManager.availableRippleTypes) { popup in
            self.rippleTypePopup = popup
        }
        
        y = addSliderRow(to: view, y: y, label: "Ripple Scale:", min: 5, max: 100, value: 30) { slider, label in
            self.rippleScaleSlider = slider
            self.rippleScaleLabel = label
        }
        
        y = addSliderRow(to: view, y: y, label: "Ripple Thickness:", min: 0.05, max: 0.5, value: 0.2) { slider, label in
            self.rippleThicknessSlider = slider
            self.rippleThicknessLabel = label
        }
        
        y = addSliderRow(to: view, y: y, label: "Ripple Speed:", min: 0.05, max: 0.5, value: 0.2) { slider, label in
            self.rippleSpeedSlider = slider
            self.rippleSpeedLabel = label
        }
        
        tabView.addTabViewItem(tabItem)
    }
    
    private func setupAdvancedTab() {
        let tabItem = NSTabViewItem(identifier: "advanced")
        tabItem.label = "Advanced"
        
        let view = NSView(frame: tabView.contentRect)
        tabItem.view = view
        
        var y = view.bounds.height - 30
        
        y = addPopupRow(to: view, y: y, label: "Renderer:", items: SettingsManager.availableRenderers) { popup in
            self.rendererPopup = popup
        }
        
        y = addCheckboxRow(to: view, y: y, label: "Use Half Float (lower precision, better performance)") { checkbox in
            self.useHalfFloatCheckbox = checkbox
        }
        
        y = addCheckboxRow(to: view, y: y, label: "Skip Intro") { checkbox in
            self.skipIntroCheckbox = checkbox
        }
        
        y = addCheckboxRow(to: view, y: y, label: "Loop Animation") { checkbox in
            self.loopsCheckbox = checkbox
        }
        
        tabView.addTabViewItem(tabItem)
    }
    
    // MARK: - UI Helpers
    
    private func addSliderRow(to view: NSView, y: CGFloat, label: String, min: Double, max: Double, value: Double, isInteger: Bool = false, step: Double? = nil, configure: (NSSlider, NSTextField) -> Void) -> CGFloat {
        let labelField = NSTextField(labelWithString: label)
        labelField.frame = NSRect(x: 20, y: y, width: 150, height: 20)
        labelField.alignment = .right
        view.addSubview(labelField)
        
        let slider = NSSlider(frame: NSRect(x: 180, y: y, width: 260, height: 20))
        slider.minValue = min
        slider.maxValue = max
        slider.doubleValue = value
        slider.target = self
        slider.action = #selector(sliderChanged(_:))
        if isInteger {
            slider.numberOfTickMarks = Int(max - min) + 1
            slider.allowsTickMarkValuesOnly = step == nil
        }
        view.addSubview(slider)
        
        let valueLabel = NSTextField(labelWithString: isInteger ? "\(Int(value))" : String(format: "%.2f", value))
        valueLabel.frame = NSRect(x: 450, y: y, width: 70, height: 20)
        view.addSubview(valueLabel)
        
        configure(slider, valueLabel)
        
        return y - 32
    }
    
    private func addCheckboxRow(to view: NSView, y: CGFloat, label: String, configure: (NSButton) -> Void) -> CGFloat {
        let checkbox = NSButton(checkboxWithTitle: label, target: self, action: #selector(controlChanged))
        checkbox.frame = NSRect(x: 180, y: y, width: 300, height: 20)
        view.addSubview(checkbox)
        
        configure(checkbox)
        
        return y - 32
    }
    
    private func addPopupRow(to view: NSView, y: CGFloat, label: String, items: [String], configure: (NSPopUpButton) -> Void) -> CGFloat {
        let labelField = NSTextField(labelWithString: label)
        labelField.frame = NSRect(x: 20, y: y, width: 150, height: 20)
        labelField.alignment = .right
        view.addSubview(labelField)
        
        let popup = NSPopUpButton(frame: NSRect(x: 180, y: y - 2, width: 260, height: 25))
        popup.addItems(withTitles: items)
        popup.target = self
        popup.action = #selector(controlChanged)
        view.addSubview(popup)
        
        configure(popup)
        
        return y - 36
    }
    
    private func addColorRow(to view: NSView, y: CGFloat, label: String, configure: (NSColorWell) -> Void) -> CGFloat {
        let labelField = NSTextField(labelWithString: label)
        labelField.frame = NSRect(x: 20, y: y, width: 150, height: 20)
        labelField.alignment = .right
        view.addSubview(labelField)
        
        let colorWell = NSColorWell(frame: NSRect(x: 180, y: y - 2, width: 50, height: 26))
        colorWell.color = NSColor.white
        colorWell.target = self
        colorWell.action = #selector(controlChanged)
        view.addSubview(colorWell)
        
        configure(colorWell)
        
        return y - 36
    }
    
    // MARK: - Actions
    
    @objc private func perMonitorChanged() {
        // Save current UI to cache before changing mode
        saveToCache()
        
        cachedUsePerMonitorSettings = perMonitorCheckbox.state == .on
        updateMonitorUI()
        
        // When enabling per-monitor, set currentScreenID to first monitor
        if cachedUsePerMonitorSettings && currentScreenID == nil {
            if let firstItem = monitorPopup.item(at: 0),
               let screenID = firstItem.representedObject as? String {
                currentScreenID = screenID
            }
        }
        
        loadSettings()
    }
    
    @objc private func monitorChanged() {
        // Save current monitor's settings to cache before switching
        if currentScreenID != nil {
            saveToCache()
        }
        
        if let selectedItem = monitorPopup.selectedItem,
           let screenID = selectedItem.representedObject as? String {
            currentScreenID = screenID
            loadSettings()
        }
    }
    
    @objc private func copyToAllClicked() {
        let alert = NSAlert()
        alert.messageText = "Sync Monitors"
        alert.informativeText = "This will copy the current monitor's settings to all other monitors, replacing their individual configurations."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Sync All")
        alert.addButton(withTitle: "Cancel")
        
        alert.beginSheetModal(for: window) { response in
            if response == .alertFirstButtonReturn {
                self.syncCurrentSettingsToAllMonitors()
            }
        }
    }
    
    private func syncCurrentSettingsToAllMonitors() {
        // First save current UI to cache
        saveToCache()
        
        // Get all screen IDs
        let allScreenIDs = NSScreen.screens.compactMap { settings.screenID(for: $0) }
        
        // Get the current screen's settings from cache (or global if not per-monitor)
        let sourceScreen = cachedUsePerMonitorSettings ? currentScreenID : nil
        
        // Copy each cached setting to all other screens
        let settingKeys = [
            "version", "font", "animationSpeed", "fallSpeed", "cycleSpeed", "cycleFrameSkip",
            "forwardSpeed", "raindropLength", "fps", "brightnessDecay", "numColumns", "resolution",
            "density", "glyphHeightToWidth", "glyphVerticalSpacing", "glyphEdgeCrop", "glyphFlip",
            "glyphRotation", "slant", "volumetric", "isometric", "isPolar", "baseTexture", "glintTexture",
            "backgroundColor", "cursorColor", "glintColor", "cursorIntensity", "glintIntensity",
            "isolateCursor", "isolateGlint", "baseBrightness", "baseContrast", "glintBrightness",
            "glintContrast", "brightnessOverride", "brightnessThreshold", "effect", "bloomStrength",
            "bloomSize", "highPassThreshold", "ditherMagnitude", "hasThunder", "rippleTypeName",
            "rippleScale", "rippleThickness", "rippleSpeed", "renderer", "useHalfFloat", "skipIntro", "loops"
        ]
        
        for targetScreenID in allScreenIDs {
            if targetScreenID != currentScreenID {
                for key in settingKeys {
                    let sourceKey = cacheKey(key, forScreen: sourceScreen)
                    let targetKey = "\(key)_\(targetScreenID)"
                    
                    if let value = settingsCache[sourceKey] {
                        settingsCache[targetKey] = value
                    }
                }
            }
        }
    }
    
    @objc private func copyURLClicked() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        // Get the URL without newlines
        pasteboard.setString(currentURLString, forType: .string)
    }
    
    @objc private func resetToDefaultsClicked() {
        let alert = NSAlert()
        alert.messageText = "Reset to Defaults"
        alert.informativeText = "This will reset all settings to their default values. Any customizations you've made will be lost."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        
        alert.beginSheetModal(for: window) { response in
            if response == .alertFirstButtonReturn {
                self.performResetToDefaults()
            }
        }
    }
    
    private func performResetToDefaults() {
        // Reset all values to defaults in the UI
        versionPopup.selectItem(withTitle: "classic")
        fontPopup.selectItem(withTitle: "matrixcode")
        
        animationSpeedSlider.doubleValue = 1.0
        animationSpeedLabel.stringValue = "1.00"
        fallSpeedSlider.doubleValue = 0.3
        fallSpeedLabel.stringValue = "0.30"
        cycleSpeedSlider.doubleValue = 0.03
        cycleSpeedLabel.stringValue = "0.030"
        cycleFrameSkipSlider.integerValue = 1
        cycleFrameSkipLabel.stringValue = "1"
        forwardSpeedSlider.doubleValue = 0.25
        forwardSpeedLabel.stringValue = "0.25"
        raindropLengthSlider.doubleValue = 0.75
        raindropLengthLabel.stringValue = "0.75"
        fpsSlider.integerValue = 60
        fpsLabel.stringValue = "60"
        brightnessDecaySlider.doubleValue = 1.0
        brightnessDecayLabel.stringValue = "1.00"
        
        numColumnsSlider.integerValue = 80
        numColumnsLabel.stringValue = "80"
        resolutionSlider.doubleValue = 0.75
        resolutionLabel.stringValue = "0.75"
        densitySlider.doubleValue = 1.0
        densityLabel.stringValue = "1.00"
        glyphHeightToWidthSlider.doubleValue = 1.0
        glyphHeightToWidthLabel.stringValue = "1.00"
        glyphVerticalSpacingSlider.doubleValue = 1.0
        glyphVerticalSpacingLabel.stringValue = "1.00"
        glyphEdgeCropSlider.doubleValue = 0.0
        glyphEdgeCropLabel.stringValue = "0.00"
        glyphFlipCheckbox.state = .off
        glyphRotationSlider.integerValue = 0
        glyphRotationLabel.stringValue = "0"
        slantSlider.doubleValue = 0.0
        slantLabel.stringValue = "0.0"
        volumetricCheckbox.state = .off
        isometricCheckbox.state = .off
        isPolarCheckbox.state = .off
        baseTexturePopup.selectItem(withTitle: "none")
        glintTexturePopup.selectItem(withTitle: "none")
        
        backgroundColorWell.color = .black
        cursorColorWell.color = NSColor(hue: 0.242, saturation: 1.0, brightness: 0.73, alpha: 1.0)
        glintColorWell.color = .white
        cursorIntensitySlider.doubleValue = 2.0
        cursorIntensityLabel.stringValue = "2.00"
        glintIntensitySlider.doubleValue = 1.0
        glintIntensityLabel.stringValue = "1.00"
        isolateCursorCheckbox.state = .on
        isolateGlintCheckbox.state = .off
        baseBrightnessSlider.doubleValue = -0.5
        baseBrightnessLabel.stringValue = "-0.50"
        baseContrastSlider.doubleValue = 1.1
        baseContrastLabel.stringValue = "1.10"
        glintBrightnessSlider.doubleValue = -1.5
        glintBrightnessLabel.stringValue = "-1.50"
        glintContrastSlider.doubleValue = 2.5
        glintContrastLabel.stringValue = "2.50"
        brightnessOverrideSlider.doubleValue = 0.0
        brightnessOverrideLabel.stringValue = "0.00"
        brightnessThresholdSlider.doubleValue = 0.0
        brightnessThresholdLabel.stringValue = "0.00"
        
        effectPopup.selectItem(withTitle: "palette")
        bloomStrengthSlider.doubleValue = 0.7
        bloomStrengthLabel.stringValue = "0.70"
        bloomSizeSlider.doubleValue = 0.4
        bloomSizeLabel.stringValue = "0.40"
        highPassThresholdSlider.doubleValue = 0.1
        highPassThresholdLabel.stringValue = "0.10"
        ditherMagnitudeSlider.doubleValue = 0.05
        ditherMagnitudeLabel.stringValue = "0.050"
        hasThunderCheckbox.state = .off
        rippleTypePopup.selectItem(withTitle: "none")
        rippleScaleSlider.doubleValue = 30.0
        rippleScaleLabel.stringValue = "30.0"
        rippleThicknessSlider.doubleValue = 0.2
        rippleThicknessLabel.stringValue = "0.20"
        rippleSpeedSlider.doubleValue = 0.2
        rippleSpeedLabel.stringValue = "0.20"
        
        rendererPopup.selectItem(withTitle: "regl")
        useHalfFloatCheckbox.state = .off
        skipIntroCheckbox.state = .on
        loopsCheckbox.state = .off
        
        updateURLPreview()
    }
    
    @objc private func sliderChanged(_ sender: NSSlider) {
        // Update the corresponding label
        if sender === animationSpeedSlider { animationSpeedLabel.stringValue = String(format: "%.2f", sender.doubleValue) }
        else if sender === fallSpeedSlider { fallSpeedLabel.stringValue = String(format: "%.2f", sender.doubleValue) }
        else if sender === cycleSpeedSlider { cycleSpeedLabel.stringValue = String(format: "%.3f", sender.doubleValue) }
        else if sender === cycleFrameSkipSlider { cycleFrameSkipLabel.stringValue = "\(Int(sender.doubleValue))" }
        else if sender === forwardSpeedSlider { forwardSpeedLabel.stringValue = String(format: "%.2f", sender.doubleValue) }
        else if sender === raindropLengthSlider { raindropLengthLabel.stringValue = String(format: "%.2f", sender.doubleValue) }
        else if sender === fpsSlider { fpsLabel.stringValue = "\(Int(sender.doubleValue))" }
        else if sender === brightnessDecaySlider { brightnessDecayLabel.stringValue = String(format: "%.2f", sender.doubleValue) }
        else if sender === numColumnsSlider { numColumnsLabel.stringValue = "\(Int(sender.doubleValue))" }
        else if sender === resolutionSlider { resolutionLabel.stringValue = String(format: "%.2f", sender.doubleValue) }
        else if sender === densitySlider { densityLabel.stringValue = String(format: "%.2f", sender.doubleValue) }
        else if sender === glyphHeightToWidthSlider { glyphHeightToWidthLabel.stringValue = String(format: "%.2f", sender.doubleValue) }
        else if sender === glyphVerticalSpacingSlider { glyphVerticalSpacingLabel.stringValue = String(format: "%.2f", sender.doubleValue) }
        else if sender === glyphEdgeCropSlider { glyphEdgeCropLabel.stringValue = String(format: "%.2f", sender.doubleValue) }
        else if sender === glyphRotationSlider { glyphRotationLabel.stringValue = "\(Int(sender.doubleValue))" }
        else if sender === slantSlider { slantLabel.stringValue = String(format: "%.1f", sender.doubleValue) }
        else if sender === cursorIntensitySlider { cursorIntensityLabel.stringValue = String(format: "%.2f", sender.doubleValue) }
        else if sender === glintIntensitySlider { glintIntensityLabel.stringValue = String(format: "%.2f", sender.doubleValue) }
        else if sender === baseBrightnessSlider { baseBrightnessLabel.stringValue = String(format: "%.2f", sender.doubleValue) }
        else if sender === baseContrastSlider { baseContrastLabel.stringValue = String(format: "%.2f", sender.doubleValue) }
        else if sender === glintBrightnessSlider { glintBrightnessLabel.stringValue = String(format: "%.2f", sender.doubleValue) }
        else if sender === glintContrastSlider { glintContrastLabel.stringValue = String(format: "%.2f", sender.doubleValue) }
        else if sender === brightnessOverrideSlider { brightnessOverrideLabel.stringValue = String(format: "%.2f", sender.doubleValue) }
        else if sender === brightnessThresholdSlider { brightnessThresholdLabel.stringValue = String(format: "%.2f", sender.doubleValue) }
        else if sender === bloomStrengthSlider { bloomStrengthLabel.stringValue = String(format: "%.2f", sender.doubleValue) }
        else if sender === bloomSizeSlider { bloomSizeLabel.stringValue = String(format: "%.2f", sender.doubleValue) }
        else if sender === highPassThresholdSlider { highPassThresholdLabel.stringValue = String(format: "%.2f", sender.doubleValue) }
        else if sender === ditherMagnitudeSlider { ditherMagnitudeLabel.stringValue = String(format: "%.3f", sender.doubleValue) }
        else if sender === rippleScaleSlider { rippleScaleLabel.stringValue = String(format: "%.1f", sender.doubleValue) }
        else if sender === rippleThicknessSlider { rippleThicknessLabel.stringValue = String(format: "%.2f", sender.doubleValue) }
        else if sender === rippleSpeedSlider { rippleSpeedLabel.stringValue = String(format: "%.2f", sender.doubleValue) }
        
        updateURLPreview()
    }
    
    @objc private func controlChanged() {
        updateURLPreview()
    }
    
    @objc private func cancelClicked() {
        os_log("cancelClicked - discarding changes", log: configLogger, type: .info)
        // Discard the cache - changes are lost
        settingsCache.removeAll()
        window.sheetParent?.endSheet(window, returnCode: .cancel)
    }
    
    @objc private func okClicked() {
        os_log("okClicked - saving settings to cache then to disk", log: configLogger, type: .info)
        // Save current UI state to cache first
        saveToCache()
        // Then persist all cached values to disk
        persistCacheToDisk()
        os_log("okClicked - settings saved, notifying delegate", log: configLogger, type: .info)
        delegate?.configSheetDidSave(self)
        window.sheetParent?.endSheet(window, returnCode: .OK)
    }
    
    // MARK: - Cache Key Helpers
    
    private func cacheKey(_ base: String, forScreen screenID: String?) -> String {
        if let screenID = screenID, cachedUsePerMonitorSettings {
            return "\(base)_\(screenID)"
        }
        return base
    }
    
    private func getCachedString(_ key: String, screen: String?, default defaultValue: String) -> String {
        let k = cacheKey(key, forScreen: screen)
        if let value = settingsCache[k] as? String {
            return value
        }
        // Fall back to disk if not in cache
        return settings.string(for: SettingsManager.Key(rawValue: key)!, screen: screen)
    }
    
    private func getCachedDouble(_ key: String, screen: String?, default defaultValue: Double) -> Double {
        let k = cacheKey(key, forScreen: screen)
        if let value = settingsCache[k] as? Double {
            return value
        }
        return settings.double(for: SettingsManager.Key(rawValue: key)!, screen: screen)
    }
    
    private func getCachedInt(_ key: String, screen: String?, default defaultValue: Int) -> Int {
        let k = cacheKey(key, forScreen: screen)
        if let value = settingsCache[k] as? Int {
            return value
        }
        return settings.integer(for: SettingsManager.Key(rawValue: key)!, screen: screen)
    }
    
    private func getCachedBool(_ key: String, screen: String?, default defaultValue: Bool) -> Bool {
        let k = cacheKey(key, forScreen: screen)
        if let value = settingsCache[k] as? Bool {
            return value
        }
        return settings.bool(for: SettingsManager.Key(rawValue: key)!, screen: screen)
    }
    
    private func getCachedColor(_ key: String, screen: String?, default defaultValue: NSColor) -> NSColor {
        let k = cacheKey(key, forScreen: screen)
        if let value = settingsCache[k] as? NSColor {
            return value
        }
        return settings.color(for: SettingsManager.Key(rawValue: key)!, screen: screen)
    }
    
    private func setCached(_ value: Any, forKey key: String, screen: String?) {
        let k = cacheKey(key, forScreen: screen)
        settingsCache[k] = value
    }
    
    // MARK: - Settings Load/Save
    
    /// Initialize the cache from disk settings
    private func initializeCache() {
        settingsCache.removeAll()
        cachedUsePerMonitorSettings = settings.usePerMonitorSettings
        os_log("initializeCache: usePerMonitor=%{public}d", log: configLogger, type: .info, cachedUsePerMonitorSettings)
    }
    
    /// Load settings from cache (or disk if not cached) into UI for the current screen
    private func loadSettings() {
        let screen = cachedUsePerMonitorSettings ? currentScreenID : nil
        
        perMonitorCheckbox.state = cachedUsePerMonitorSettings ? .on : .off
        updateMonitorUI()
        
        // Presets
        versionPopup.selectItem(withTitle: getCachedString("version", screen: screen, default: "classic"))
        fontPopup.selectItem(withTitle: getCachedString("font", screen: screen, default: "matrixcode"))
        
        // Animation
        animationSpeedSlider.doubleValue = getCachedDouble("animationSpeed", screen: screen, default: 1.0)
        animationSpeedLabel.stringValue = String(format: "%.2f", animationSpeedSlider.doubleValue)
        fallSpeedSlider.doubleValue = getCachedDouble("fallSpeed", screen: screen, default: 0.3)
        fallSpeedLabel.stringValue = String(format: "%.2f", fallSpeedSlider.doubleValue)
        cycleSpeedSlider.doubleValue = getCachedDouble("cycleSpeed", screen: screen, default: 0.03)
        cycleSpeedLabel.stringValue = String(format: "%.3f", cycleSpeedSlider.doubleValue)
        cycleFrameSkipSlider.integerValue = getCachedInt("cycleFrameSkip", screen: screen, default: 1)
        cycleFrameSkipLabel.stringValue = "\(cycleFrameSkipSlider.integerValue)"
        forwardSpeedSlider.doubleValue = getCachedDouble("forwardSpeed", screen: screen, default: 0.25)
        forwardSpeedLabel.stringValue = String(format: "%.2f", forwardSpeedSlider.doubleValue)
        raindropLengthSlider.doubleValue = getCachedDouble("raindropLength", screen: screen, default: 0.75)
        raindropLengthLabel.stringValue = String(format: "%.2f", raindropLengthSlider.doubleValue)
        fpsSlider.integerValue = getCachedInt("fps", screen: screen, default: 60)
        fpsLabel.stringValue = "\(fpsSlider.integerValue)"
        brightnessDecaySlider.doubleValue = getCachedDouble("brightnessDecay", screen: screen, default: 1.0)
        brightnessDecayLabel.stringValue = String(format: "%.2f", brightnessDecaySlider.doubleValue)
        
        // Appearance
        numColumnsSlider.integerValue = getCachedInt("numColumns", screen: screen, default: 80)
        numColumnsLabel.stringValue = "\(numColumnsSlider.integerValue)"
        resolutionSlider.doubleValue = getCachedDouble("resolution", screen: screen, default: 0.75)
        resolutionLabel.stringValue = String(format: "%.2f", resolutionSlider.doubleValue)
        densitySlider.doubleValue = getCachedDouble("density", screen: screen, default: 1.0)
        densityLabel.stringValue = String(format: "%.2f", densitySlider.doubleValue)
        glyphHeightToWidthSlider.doubleValue = getCachedDouble("glyphHeightToWidth", screen: screen, default: 1.0)
        glyphHeightToWidthLabel.stringValue = String(format: "%.2f", glyphHeightToWidthSlider.doubleValue)
        glyphVerticalSpacingSlider.doubleValue = getCachedDouble("glyphVerticalSpacing", screen: screen, default: 1.0)
        glyphVerticalSpacingLabel.stringValue = String(format: "%.2f", glyphVerticalSpacingSlider.doubleValue)
        glyphEdgeCropSlider.doubleValue = getCachedDouble("glyphEdgeCrop", screen: screen, default: 0.0)
        glyphEdgeCropLabel.stringValue = String(format: "%.2f", glyphEdgeCropSlider.doubleValue)
        glyphFlipCheckbox.state = getCachedBool("glyphFlip", screen: screen, default: false) ? .on : .off
        glyphRotationSlider.integerValue = getCachedInt("glyphRotation", screen: screen, default: 0)
        glyphRotationLabel.stringValue = "\(glyphRotationSlider.integerValue)"
        slantSlider.doubleValue = getCachedDouble("slant", screen: screen, default: 0.0)
        slantLabel.stringValue = String(format: "%.1f", slantSlider.doubleValue)
        volumetricCheckbox.state = getCachedBool("volumetric", screen: screen, default: false) ? .on : .off
        isometricCheckbox.state = getCachedBool("isometric", screen: screen, default: false) ? .on : .off
        isPolarCheckbox.state = getCachedBool("isPolar", screen: screen, default: false) ? .on : .off
        baseTexturePopup.selectItem(withTitle: getCachedString("baseTexture", screen: screen, default: "none"))
        glintTexturePopup.selectItem(withTitle: getCachedString("glintTexture", screen: screen, default: "none"))
        
        // Colors
        backgroundColorWell.color = getCachedColor("backgroundColor", screen: screen, default: .black)
        cursorColorWell.color = getCachedColor("cursorColor", screen: screen, default: .cyan)
        glintColorWell.color = getCachedColor("glintColor", screen: screen, default: .white)
        cursorIntensitySlider.doubleValue = getCachedDouble("cursorIntensity", screen: screen, default: 2.0)
        cursorIntensityLabel.stringValue = String(format: "%.2f", cursorIntensitySlider.doubleValue)
        glintIntensitySlider.doubleValue = getCachedDouble("glintIntensity", screen: screen, default: 1.0)
        glintIntensityLabel.stringValue = String(format: "%.2f", glintIntensitySlider.doubleValue)
        isolateCursorCheckbox.state = getCachedBool("isolateCursor", screen: screen, default: true) ? .on : .off
        isolateGlintCheckbox.state = getCachedBool("isolateGlint", screen: screen, default: false) ? .on : .off
        baseBrightnessSlider.doubleValue = getCachedDouble("baseBrightness", screen: screen, default: -0.5)
        baseBrightnessLabel.stringValue = String(format: "%.2f", baseBrightnessSlider.doubleValue)
        baseContrastSlider.doubleValue = getCachedDouble("baseContrast", screen: screen, default: 1.1)
        baseContrastLabel.stringValue = String(format: "%.2f", baseContrastSlider.doubleValue)
        glintBrightnessSlider.doubleValue = getCachedDouble("glintBrightness", screen: screen, default: -1.5)
        glintBrightnessLabel.stringValue = String(format: "%.2f", glintBrightnessSlider.doubleValue)
        glintContrastSlider.doubleValue = getCachedDouble("glintContrast", screen: screen, default: 2.5)
        glintContrastLabel.stringValue = String(format: "%.2f", glintContrastSlider.doubleValue)
        brightnessOverrideSlider.doubleValue = getCachedDouble("brightnessOverride", screen: screen, default: 0.0)
        brightnessOverrideLabel.stringValue = String(format: "%.2f", brightnessOverrideSlider.doubleValue)
        brightnessThresholdSlider.doubleValue = getCachedDouble("brightnessThreshold", screen: screen, default: 0.0)
        brightnessThresholdLabel.stringValue = String(format: "%.2f", brightnessThresholdSlider.doubleValue)
        
        // Effects
        effectPopup.selectItem(withTitle: getCachedString("effect", screen: screen, default: "palette"))
        bloomStrengthSlider.doubleValue = getCachedDouble("bloomStrength", screen: screen, default: 0.7)
        bloomStrengthLabel.stringValue = String(format: "%.2f", bloomStrengthSlider.doubleValue)
        bloomSizeSlider.doubleValue = getCachedDouble("bloomSize", screen: screen, default: 0.4)
        bloomSizeLabel.stringValue = String(format: "%.2f", bloomSizeSlider.doubleValue)
        highPassThresholdSlider.doubleValue = getCachedDouble("highPassThreshold", screen: screen, default: 0.1)
        highPassThresholdLabel.stringValue = String(format: "%.2f", highPassThresholdSlider.doubleValue)
        ditherMagnitudeSlider.doubleValue = getCachedDouble("ditherMagnitude", screen: screen, default: 0.05)
        ditherMagnitudeLabel.stringValue = String(format: "%.3f", ditherMagnitudeSlider.doubleValue)
        hasThunderCheckbox.state = getCachedBool("hasThunder", screen: screen, default: false) ? .on : .off
        rippleTypePopup.selectItem(withTitle: getCachedString("rippleTypeName", screen: screen, default: "none"))
        rippleScaleSlider.doubleValue = getCachedDouble("rippleScale", screen: screen, default: 30.0)
        rippleScaleLabel.stringValue = String(format: "%.1f", rippleScaleSlider.doubleValue)
        rippleThicknessSlider.doubleValue = getCachedDouble("rippleThickness", screen: screen, default: 0.2)
        rippleThicknessLabel.stringValue = String(format: "%.2f", rippleThicknessSlider.doubleValue)
        rippleSpeedSlider.doubleValue = getCachedDouble("rippleSpeed", screen: screen, default: 0.2)
        rippleSpeedLabel.stringValue = String(format: "%.2f", rippleSpeedSlider.doubleValue)
        
        // Advanced
        rendererPopup.selectItem(withTitle: getCachedString("renderer", screen: screen, default: "regl"))
        useHalfFloatCheckbox.state = getCachedBool("useHalfFloat", screen: screen, default: false) ? .on : .off
        skipIntroCheckbox.state = getCachedBool("skipIntro", screen: screen, default: true) ? .on : .off
        loopsCheckbox.state = getCachedBool("loops", screen: screen, default: false) ? .on : .off
        
        updateURLPreview()
    }
    
    /// Save current UI values to the in-memory cache (not to disk)
    private func saveToCache() {
        let screen = cachedUsePerMonitorSettings ? currentScreenID : nil
        
        os_log("saveToCache: screen=%{public}@, usePerMonitor=%{public}d, version=%{public}@", log: configLogger, type: .info, screen ?? "nil", cachedUsePerMonitorSettings, versionPopup.titleOfSelectedItem ?? "nil")
        
        // Presets
        setCached(versionPopup.titleOfSelectedItem ?? "classic", forKey: "version", screen: screen)
        setCached(fontPopup.titleOfSelectedItem ?? "matrixcode", forKey: "font", screen: screen)
        
        // Animation
        setCached(animationSpeedSlider.doubleValue, forKey: "animationSpeed", screen: screen)
        setCached(fallSpeedSlider.doubleValue, forKey: "fallSpeed", screen: screen)
        setCached(cycleSpeedSlider.doubleValue, forKey: "cycleSpeed", screen: screen)
        setCached(cycleFrameSkipSlider.integerValue, forKey: "cycleFrameSkip", screen: screen)
        setCached(forwardSpeedSlider.doubleValue, forKey: "forwardSpeed", screen: screen)
        setCached(raindropLengthSlider.doubleValue, forKey: "raindropLength", screen: screen)
        setCached(fpsSlider.integerValue, forKey: "fps", screen: screen)
        setCached(brightnessDecaySlider.doubleValue, forKey: "brightnessDecay", screen: screen)
        
        // Appearance
        setCached(numColumnsSlider.integerValue, forKey: "numColumns", screen: screen)
        setCached(resolutionSlider.doubleValue, forKey: "resolution", screen: screen)
        setCached(densitySlider.doubleValue, forKey: "density", screen: screen)
        setCached(glyphHeightToWidthSlider.doubleValue, forKey: "glyphHeightToWidth", screen: screen)
        setCached(glyphVerticalSpacingSlider.doubleValue, forKey: "glyphVerticalSpacing", screen: screen)
        setCached(glyphEdgeCropSlider.doubleValue, forKey: "glyphEdgeCrop", screen: screen)
        setCached(glyphFlipCheckbox.state == .on, forKey: "glyphFlip", screen: screen)
        setCached(glyphRotationSlider.integerValue, forKey: "glyphRotation", screen: screen)
        setCached(slantSlider.doubleValue, forKey: "slant", screen: screen)
        setCached(volumetricCheckbox.state == .on, forKey: "volumetric", screen: screen)
        setCached(isometricCheckbox.state == .on, forKey: "isometric", screen: screen)
        setCached(isPolarCheckbox.state == .on, forKey: "isPolar", screen: screen)
        setCached(baseTexturePopup.titleOfSelectedItem ?? "none", forKey: "baseTexture", screen: screen)
        setCached(glintTexturePopup.titleOfSelectedItem ?? "none", forKey: "glintTexture", screen: screen)
        
        // Colors
        setCached(backgroundColorWell.color, forKey: "backgroundColor", screen: screen)
        setCached(cursorColorWell.color, forKey: "cursorColor", screen: screen)
        setCached(glintColorWell.color, forKey: "glintColor", screen: screen)
        setCached(cursorIntensitySlider.doubleValue, forKey: "cursorIntensity", screen: screen)
        setCached(glintIntensitySlider.doubleValue, forKey: "glintIntensity", screen: screen)
        setCached(isolateCursorCheckbox.state == .on, forKey: "isolateCursor", screen: screen)
        setCached(isolateGlintCheckbox.state == .on, forKey: "isolateGlint", screen: screen)
        setCached(baseBrightnessSlider.doubleValue, forKey: "baseBrightness", screen: screen)
        setCached(baseContrastSlider.doubleValue, forKey: "baseContrast", screen: screen)
        setCached(glintBrightnessSlider.doubleValue, forKey: "glintBrightness", screen: screen)
        setCached(glintContrastSlider.doubleValue, forKey: "glintContrast", screen: screen)
        setCached(brightnessOverrideSlider.doubleValue, forKey: "brightnessOverride", screen: screen)
        setCached(brightnessThresholdSlider.doubleValue, forKey: "brightnessThreshold", screen: screen)
        
        // Effects
        setCached(effectPopup.titleOfSelectedItem ?? "palette", forKey: "effect", screen: screen)
        setCached(bloomStrengthSlider.doubleValue, forKey: "bloomStrength", screen: screen)
        setCached(bloomSizeSlider.doubleValue, forKey: "bloomSize", screen: screen)
        setCached(highPassThresholdSlider.doubleValue, forKey: "highPassThreshold", screen: screen)
        setCached(ditherMagnitudeSlider.doubleValue, forKey: "ditherMagnitude", screen: screen)
        setCached(hasThunderCheckbox.state == .on, forKey: "hasThunder", screen: screen)
        setCached(rippleTypePopup.titleOfSelectedItem ?? "none", forKey: "rippleTypeName", screen: screen)
        setCached(rippleScaleSlider.doubleValue, forKey: "rippleScale", screen: screen)
        setCached(rippleThicknessSlider.doubleValue, forKey: "rippleThickness", screen: screen)
        setCached(rippleSpeedSlider.doubleValue, forKey: "rippleSpeed", screen: screen)
        
        // Advanced
        setCached(rendererPopup.titleOfSelectedItem ?? "regl", forKey: "renderer", screen: screen)
        setCached(useHalfFloatCheckbox.state == .on, forKey: "useHalfFloat", screen: screen)
        setCached(skipIntroCheckbox.state == .on, forKey: "skipIntro", screen: screen)
        setCached(loopsCheckbox.state == .on, forKey: "loops", screen: screen)
    }
    
    /// Update the URL preview field based on current UI values
    private func updateURLPreview() {
        var items: [URLQueryItem] = []
        
        // Helper to add non-default string values
        func addString(_ paramName: String, value: String?, defaultValue: String) {
            guard let value = value, !value.isEmpty, value != defaultValue else { return }
            items.append(URLQueryItem(name: paramName, value: value))
        }
        
        // Helper to add non-default double values
        func addDouble(_ paramName: String, value: Double, defaultValue: Double) {
            guard abs(value - defaultValue) > 0.001 else { return }
            items.append(URLQueryItem(name: paramName, value: String(format: "%.4g", value)))
        }
        
        // Helper to add non-default int values
        func addInt(_ paramName: String, value: Int, defaultValue: Int) {
            guard value != defaultValue else { return }
            items.append(URLQueryItem(name: paramName, value: String(value)))
        }
        
        // Helper to add non-default bool values
        func addBool(_ paramName: String, value: Bool, defaultValue: Bool) {
            guard value != defaultValue else { return }
            items.append(URLQueryItem(name: paramName, value: value ? "true" : "false"))
        }
        
        // Helper to add color as HSL
        func addColor(_ paramName: String, color: NSColor, defaultColor: NSColor) {
            let calibrated = color.usingColorSpace(.deviceRGB) ?? color
            let defaultCalibrated = defaultColor.usingColorSpace(.deviceRGB) ?? defaultColor
            
            let hDiff = abs(calibrated.hueComponent - defaultCalibrated.hueComponent)
            let sDiff = abs(calibrated.saturationComponent - defaultCalibrated.saturationComponent)
            let bDiff = abs(calibrated.brightnessComponent - defaultCalibrated.brightnessComponent)
            
            if hDiff > 0.01 || sDiff > 0.01 || bDiff > 0.01 {
                let h = String(format: "%.4g", calibrated.hueComponent)
                let s = String(format: "%.4g", calibrated.saturationComponent)
                let l = String(format: "%.4g", calibrated.brightnessComponent)
                items.append(URLQueryItem(name: paramName, value: "\(h),\(s),\(l)"))
            }
        }
        
        // Presets
        addString("version", value: versionPopup.titleOfSelectedItem, defaultValue: "classic")
        addString("font", value: fontPopup.titleOfSelectedItem, defaultValue: "matrixcode")
        
        // Animation
        addDouble("animationSpeed", value: animationSpeedSlider.doubleValue, defaultValue: 1.0)
        addDouble("fallSpeed", value: fallSpeedSlider.doubleValue, defaultValue: 0.3)
        addDouble("cycleSpeed", value: cycleSpeedSlider.doubleValue, defaultValue: 0.03)
        addInt("cycleFrameSkip", value: cycleFrameSkipSlider.integerValue, defaultValue: 1)
        addDouble("forwardSpeed", value: forwardSpeedSlider.doubleValue, defaultValue: 0.25)
        addDouble("raindropLength", value: raindropLengthSlider.doubleValue, defaultValue: 0.75)
        addInt("fps", value: fpsSlider.integerValue, defaultValue: 60)
        addDouble("brightnessDecay", value: brightnessDecaySlider.doubleValue, defaultValue: 1.0)
        
        // Appearance
        addInt("numColumns", value: numColumnsSlider.integerValue, defaultValue: 80)
        addDouble("resolution", value: resolutionSlider.doubleValue, defaultValue: 0.75)
        addDouble("density", value: densitySlider.doubleValue, defaultValue: 1.0)
        addDouble("glyphHeightToWidth", value: glyphHeightToWidthSlider.doubleValue, defaultValue: 1.0)
        addDouble("glyphVerticalSpacing", value: glyphVerticalSpacingSlider.doubleValue, defaultValue: 1.0)
        addDouble("glyphEdgeCrop", value: glyphEdgeCropSlider.doubleValue, defaultValue: 0.0)
        addBool("glyphFlip", value: glyphFlipCheckbox.state == .on, defaultValue: false)
        addInt("glyphRotation", value: glyphRotationSlider.integerValue, defaultValue: 0)
        addDouble("slant", value: slantSlider.doubleValue, defaultValue: 0.0)
        addBool("volumetric", value: volumetricCheckbox.state == .on, defaultValue: false)
        addBool("isometric", value: isometricCheckbox.state == .on, defaultValue: false)
        addBool("isPolar", value: isPolarCheckbox.state == .on, defaultValue: false)
        
        // Textures (only add if not "none")
        if let baseTexture = baseTexturePopup.titleOfSelectedItem, baseTexture != "none" {
            items.append(URLQueryItem(name: "baseTexture", value: baseTexture))
        }
        if let glintTexture = glintTexturePopup.titleOfSelectedItem, glintTexture != "none" {
            items.append(URLQueryItem(name: "glintTexture", value: glintTexture))
        }
        
        // Colors
        addColor("backgroundHSL", color: backgroundColorWell.color, defaultColor: .black)
        addColor("cursorHSL", color: cursorColorWell.color, defaultColor: NSColor(hue: 0.242, saturation: 1.0, brightness: 0.73, alpha: 1.0))
        addColor("glintHSL", color: glintColorWell.color, defaultColor: .white)
        addDouble("cursorIntensity", value: cursorIntensitySlider.doubleValue, defaultValue: 2.0)
        addDouble("glyphIntensity", value: glintIntensitySlider.doubleValue, defaultValue: 1.0)
        addBool("isolateCursor", value: isolateCursorCheckbox.state == .on, defaultValue: true)
        addBool("isolateGlint", value: isolateGlintCheckbox.state == .on, defaultValue: false)
        addDouble("baseBrightness", value: baseBrightnessSlider.doubleValue, defaultValue: -0.5)
        addDouble("baseContrast", value: baseContrastSlider.doubleValue, defaultValue: 1.1)
        addDouble("glintBrightness", value: glintBrightnessSlider.doubleValue, defaultValue: -1.5)
        addDouble("glintContrast", value: glintContrastSlider.doubleValue, defaultValue: 2.5)
        addDouble("brightnessOverride", value: brightnessOverrideSlider.doubleValue, defaultValue: 0.0)
        addDouble("brightnessThreshold", value: brightnessThresholdSlider.doubleValue, defaultValue: 0.0)
        
        // Effects
        addString("effect", value: effectPopup.titleOfSelectedItem, defaultValue: "palette")
        addDouble("bloomStrength", value: bloomStrengthSlider.doubleValue, defaultValue: 0.7)
        addDouble("bloomSize", value: bloomSizeSlider.doubleValue, defaultValue: 0.4)
        addDouble("highPassThreshold", value: highPassThresholdSlider.doubleValue, defaultValue: 0.1)
        addDouble("ditherMagnitude", value: ditherMagnitudeSlider.doubleValue, defaultValue: 0.05)
        addBool("hasThunder", value: hasThunderCheckbox.state == .on, defaultValue: false)
        
        // Ripple (only add if not "none")
        if let rippleType = rippleTypePopup.titleOfSelectedItem, rippleType != "none" {
            items.append(URLQueryItem(name: "rippleTypeName", value: rippleType))
            addDouble("rippleScale", value: rippleScaleSlider.doubleValue, defaultValue: 30.0)
            addDouble("rippleThickness", value: rippleThicknessSlider.doubleValue, defaultValue: 0.2)
            addDouble("rippleSpeed", value: rippleSpeedSlider.doubleValue, defaultValue: 0.2)
        }
        
        // Advanced
        addString("renderer", value: rendererPopup.titleOfSelectedItem, defaultValue: "regl")
        addBool("useHalfFloat", value: useHalfFloatCheckbox.state == .on, defaultValue: false)
        addBool("skipIntro", value: skipIntroCheckbox.state == .on, defaultValue: true)
        addBool("loops", value: loopsCheckbox.state == .on, defaultValue: false)
        
        // Build the URL
        var components = URLComponents(string: "https://rezmason.github.io/matrix/")!
        components.queryItems = items.isEmpty ? nil : items
        
        currentURLString = components.url?.absoluteString ?? "https://rezmason.github.io/matrix/"
        
        // Format for display with newlines
        if items.isEmpty {
            urlPreviewField.stringValue = currentURLString
        } else {
            var displayLines = ["https://rezmason.github.io/matrix/?"]
            for (index, item) in items.enumerated() {
                let prefix = index == 0 ? "  " : "  &"
                let value = item.value ?? ""
                displayLines.append("\(prefix)\(item.name)=\(value)")
            }
            urlPreviewField.stringValue = displayLines.joined(separator: "\n")
        }
    }
    
    /// Persist all cached settings to disk (called on OK)
    private func persistCacheToDisk() {
        os_log("persistCacheToDisk: saving %{public}d cached values, usePerMonitor=%{public}d", log: configLogger, type: .info, settingsCache.count, cachedUsePerMonitorSettings)
        
        // Write directly to the screensaver container's plist file
        // We need the actual user home, not the sandboxed home
        let pw = getpwuid(getuid())
        let realHome = pw != nil ? String(cString: pw!.pointee.pw_dir) : NSHomeDirectory()
        let containerPath = realHome + "/Library/Containers/com.apple.ScreenSaver.Engine.legacyScreenSaver/Data/Library/Preferences/com.trehn.mactrix.plist"
        
        os_log("persistCacheToDisk: realHome=%{public}@, containerPath=%{public}@", log: configLogger, type: .info, realHome, containerPath)
        
        // Read existing plist or create new one
        var plistDict: [String: Any]
        if let existingDict = NSDictionary(contentsOfFile: containerPath) as? [String: Any] {
            plistDict = existingDict
            os_log("persistCacheToDisk: read existing plist with %{public}d keys", log: configLogger, type: .info, plistDict.count)
        } else {
            plistDict = [:]
            os_log("persistCacheToDisk: creating new plist", log: configLogger, type: .info)
        }
        
        // Update with cached values
        plistDict["usePerMonitorSettings"] = cachedUsePerMonitorSettings
        
        for (key, value) in settingsCache {
            if let colorValue = value as? NSColor {
                // Archive colors as Data
                if let data = try? NSKeyedArchiver.archivedData(withRootObject: colorValue, requiringSecureCoding: true) {
                    plistDict[key] = data
                }
            } else {
                plistDict[key] = value
            }
        }
        
        // Write to file
        let nsDict = plistDict as NSDictionary
        let success = nsDict.write(toFile: containerPath, atomically: true)
        os_log("persistCacheToDisk: wrote to file, success=%{public}d", log: configLogger, type: .info, success)
        
        if !success {
            os_log("persistCacheToDisk: direct write failed", log: configLogger, type: .error)
        }
    }
}
