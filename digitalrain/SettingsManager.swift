import Foundation
import ScreenSaver
import AppKit
import os.log

private let settingsLogger = OSLog(subsystem: "com.trehn.digitalrain", category: "Settings")

/// Manages all settings for the Digital Rain screensaver with support for per-monitor configuration
class SettingsManager {
    
    static let shared = SettingsManager()
    
    // Made internal so ConfigSheetController can persist cached values directly
    var defaults: UserDefaults
    private let moduleName = "com.trehn.digitalrain"
    
    // Direct plist data for bypassing UserDefaults caching
    private var plistData: [String: Any] = [:]
    private var usePlistData = false
    
    // MARK: - Settings Keys
    
    enum Key: String {
        // Multi-monitor
        case usePerMonitorSettings
        
        // Presets
        case version
        case font
        
        // Animation
        case animationSpeed
        case fallSpeed
        case cycleSpeed
        case cycleFrameSkip
        case forwardSpeed
        case raindropLength
        case fps
        case brightnessDecay
        
        // Appearance
        case numColumns
        case resolution
        case density
        case glyphHeightToWidth
        case glyphVerticalSpacing
        case glyphEdgeCrop
        case glyphFlip
        case glyphRotation
        case slant
        case volumetric
        case isometric
        case isPolar
        case baseTexture
        case glintTexture
        
        // Colors
        case backgroundColor
        case cursorColor
        case glintColor
        case cursorIntensity
        case glintIntensity
        case isolateCursor
        case isolateGlint
        case baseBrightness
        case baseContrast
        case glintBrightness
        case glintContrast
        case brightnessOverride
        case brightnessThreshold
        case paletteData
        case stripeColors
        
        // Effects
        case effect
        case bloomStrength
        case bloomSize
        case highPassThreshold
        case ditherMagnitude
        case hasThunder
        case rippleTypeName
        case rippleScale
        case rippleThickness
        case rippleSpeed
        
        // Advanced
        case renderer
        case useHalfFloat
        case skipIntro
        case loops
    }
    
    // MARK: - Default Values
    
    struct Defaults {
        static let version = "classic"
        static let font = "matrixcode"
        static let animationSpeed: Double = 1.0
        static let fallSpeed: Double = 0.3
        static let cycleSpeed: Double = 0.03
        static let cycleFrameSkip: Int = 1
        static let forwardSpeed: Double = 0.25
        static let raindropLength: Double = 0.75
        static let fps: Int = 60
        static let brightnessDecay: Double = 1.0
        static let numColumns: Int = 80
        static let resolution: Double = 0.75
        static let density: Double = 1.0
        static let glyphHeightToWidth: Double = 1.0
        static let glyphVerticalSpacing: Double = 1.0
        static let glyphEdgeCrop: Double = 0.0
        static let glyphFlip = false
        static let glyphRotation: Int = 0
        static let slant: Double = 0.0
        static let volumetric = false
        static let isometric = false
        static let isPolar = false
        static let baseTexture = "none"
        static let glintTexture = "none"
        static let backgroundColor = NSColor.black
        static let cursorColor = NSColor(hue: 0.242, saturation: 1.0, brightness: 0.73, alpha: 1.0)
        static let glintColor = NSColor.white
        static let cursorIntensity: Double = 2.0
        static let glintIntensity: Double = 1.0
        static let isolateCursor = true
        static let isolateGlint = false
        static let baseBrightness: Double = -0.5
        static let baseContrast: Double = 1.1
        static let glintBrightness: Double = -1.5
        static let glintContrast: Double = 2.5
        static let brightnessOverride: Double = 0.0
        static let brightnessThreshold: Double = 0.0
        static let effect = "palette"
        static let bloomStrength: Double = 0.7
        static let bloomSize: Double = 0.4
        static let highPassThreshold: Double = 0.1
        static let ditherMagnitude: Double = 0.05
        static let hasThunder = false
        static let rippleTypeName = "none"
        static let rippleScale: Double = 30.0
        static let rippleThickness: Double = 0.2
        static let rippleSpeed: Double = 0.2
        static let renderer = "regl"
        static let useHalfFloat = false
        static let skipIntro = true
        static let loops = false
    }
    
    // MARK: - Initialization
    
    private init() {
        // Use UserDefaults with suite name - ScreenSaverDefaults doesn't persist dynamic keys properly
        if let suiteDefaults = UserDefaults(suiteName: moduleName) {
            defaults = suiteDefaults
            os_log("SettingsManager: initialized with UserDefaults suite for %{public}@", log: settingsLogger, type: .info, moduleName)
        } else {
            defaults = UserDefaults.standard
            os_log("SettingsManager: WARNING - falling back to standard defaults", log: settingsLogger, type: .error)
        }
        registerDefaults()
    }
    
    private func registerDefaults() {
        let defaultValues: [String: Any] = [
            Key.usePerMonitorSettings.rawValue: false,
            Key.version.rawValue: Defaults.version,
            Key.font.rawValue: Defaults.font,
            Key.animationSpeed.rawValue: Defaults.animationSpeed,
            Key.fallSpeed.rawValue: Defaults.fallSpeed,
            Key.cycleSpeed.rawValue: Defaults.cycleSpeed,
            Key.cycleFrameSkip.rawValue: Defaults.cycleFrameSkip,
            Key.forwardSpeed.rawValue: Defaults.forwardSpeed,
            Key.raindropLength.rawValue: Defaults.raindropLength,
            Key.fps.rawValue: Defaults.fps,
            Key.brightnessDecay.rawValue: Defaults.brightnessDecay,
            Key.numColumns.rawValue: Defaults.numColumns,
            Key.resolution.rawValue: Defaults.resolution,
            Key.density.rawValue: Defaults.density,
            Key.glyphHeightToWidth.rawValue: Defaults.glyphHeightToWidth,
            Key.glyphVerticalSpacing.rawValue: Defaults.glyphVerticalSpacing,
            Key.glyphEdgeCrop.rawValue: Defaults.glyphEdgeCrop,
            Key.glyphFlip.rawValue: Defaults.glyphFlip,
            Key.glyphRotation.rawValue: Defaults.glyphRotation,
            Key.slant.rawValue: Defaults.slant,
            Key.volumetric.rawValue: Defaults.volumetric,
            Key.isometric.rawValue: Defaults.isometric,
            Key.isPolar.rawValue: Defaults.isPolar,
            Key.baseTexture.rawValue: Defaults.baseTexture,
            Key.glintTexture.rawValue: Defaults.glintTexture,
            Key.cursorIntensity.rawValue: Defaults.cursorIntensity,
            Key.glintIntensity.rawValue: Defaults.glintIntensity,
            Key.isolateCursor.rawValue: Defaults.isolateCursor,
            Key.isolateGlint.rawValue: Defaults.isolateGlint,
            Key.baseBrightness.rawValue: Defaults.baseBrightness,
            Key.baseContrast.rawValue: Defaults.baseContrast,
            Key.glintBrightness.rawValue: Defaults.glintBrightness,
            Key.glintContrast.rawValue: Defaults.glintContrast,
            Key.brightnessOverride.rawValue: Defaults.brightnessOverride,
            Key.brightnessThreshold.rawValue: Defaults.brightnessThreshold,
            Key.effect.rawValue: Defaults.effect,
            Key.bloomStrength.rawValue: Defaults.bloomStrength,
            Key.bloomSize.rawValue: Defaults.bloomSize,
            Key.highPassThreshold.rawValue: Defaults.highPassThreshold,
            Key.ditherMagnitude.rawValue: Defaults.ditherMagnitude,
            Key.hasThunder.rawValue: Defaults.hasThunder,
            Key.rippleTypeName.rawValue: Defaults.rippleTypeName,
            Key.rippleScale.rawValue: Defaults.rippleScale,
            Key.rippleThickness.rawValue: Defaults.rippleThickness,
            Key.rippleSpeed.rawValue: Defaults.rippleSpeed,
            Key.renderer.rawValue: Defaults.renderer,
            Key.useHalfFloat.rawValue: Defaults.useHalfFloat,
            Key.skipIntro.rawValue: Defaults.skipIntro,
            Key.loops.rawValue: Defaults.loops,
        ]
        defaults.register(defaults: defaultValues)
    }
    
    // MARK: - Multi-Monitor Support
    
    var usePerMonitorSettings: Bool {
        get {
            if usePlistData {
                return (plistData[Key.usePerMonitorSettings.rawValue] as? Bool) ?? false
            }
            return defaults.bool(forKey: Key.usePerMonitorSettings.rawValue)
        }
        set {
            defaults.set(newValue, forKey: Key.usePerMonitorSettings.rawValue)
            defaults.synchronize()
        }
    }
    
    private func key(_ base: Key, forScreen screenID: String?) -> String {
        if let screenID = screenID, usePerMonitorSettings {
            return "\(base.rawValue)_\(screenID)"
        }
        return base.rawValue
    }
    
    // MARK: - Getters with Screen Support
    
    /// Force reload settings from disk (needed because config sheet and screensaver run in different processes)
    func reload() {
        // Read directly from the plist file to bypass cfprefsd caching
        let pw = getpwuid(getuid())
        let realHome = pw != nil ? String(cString: pw!.pointee.pw_dir) : NSHomeDirectory()
        let plistPath = realHome + "/Library/Containers/com.apple.ScreenSaver.Engine.legacyScreenSaver/Data/Library/Preferences/com.trehn.digitalrain.plist"
        
        if let dict = NSDictionary(contentsOfFile: plistPath) as? [String: Any] {
            plistData = dict
            usePlistData = true
        } else {
            os_log("SettingsManager: could not read plist from %{public}@, using defaults", log: settingsLogger, type: .info, plistPath)
            usePlistData = false
        }
    }
    
    func string(for key: Key, screen: String? = nil) -> String {
        let k = self.key(key, forScreen: screen)
        
        if usePlistData {
            let perScreenValue = plistData[k] as? String
            let globalValue = plistData[key.rawValue] as? String
            return perScreenValue ?? globalValue ?? ""
        }
        
        let perScreenValue = defaults.string(forKey: k)
        let globalValue = defaults.string(forKey: key.rawValue)
        return perScreenValue ?? globalValue ?? ""
    }
    
    func double(for key: Key, screen: String? = nil) -> Double {
        let k = self.key(key, forScreen: screen)
        
        if usePlistData {
            if let value = plistData[k] as? Double {
                return value
            }
            if let value = plistData[key.rawValue] as? Double {
                return value
            }
            return 0.0
        }
        
        if defaults.object(forKey: k) != nil {
            return defaults.double(forKey: k)
        }
        return defaults.double(forKey: key.rawValue)
    }
    
    func integer(for key: Key, screen: String? = nil) -> Int {
        let k = self.key(key, forScreen: screen)
        
        if usePlistData {
            if let value = plistData[k] as? Int {
                return value
            }
            if let value = plistData[key.rawValue] as? Int {
                return value
            }
            return 0
        }
        
        if defaults.object(forKey: k) != nil {
            return defaults.integer(forKey: k)
        }
        return defaults.integer(forKey: key.rawValue)
    }
    
    func bool(for key: Key, screen: String? = nil) -> Bool {
        let k = self.key(key, forScreen: screen)
        
        if usePlistData {
            if let value = plistData[k] as? Bool {
                return value
            }
            if let value = plistData[key.rawValue] as? Bool {
                return value
            }
            return false
        }
        
        if defaults.object(forKey: k) != nil {
            return defaults.bool(forKey: k)
        }
        return defaults.bool(forKey: key.rawValue)
    }
    
    func color(for key: Key, screen: String? = nil) -> NSColor {
        let k = self.key(key, forScreen: screen)
        
        if usePlistData {
            if let data = plistData[k] as? Data,
               let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) {
                return color
            }
            if let data = plistData[key.rawValue] as? Data,
               let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) {
                return color
            }
        } else {
            if let data = defaults.data(forKey: k),
               let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) {
                return color
            }
            if let data = defaults.data(forKey: key.rawValue),
               let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) {
                return color
            }
        }
        
        // Return defaults
        switch key {
        case .backgroundColor: return Defaults.backgroundColor
        case .cursorColor: return Defaults.cursorColor
        case .glintColor: return Defaults.glintColor
        default: return NSColor.white
        }
    }
    
    // MARK: - Setters with Screen Support
    
    func set(_ value: String, for key: Key, screen: String? = nil) {
        let k = self.key(key, forScreen: screen)
        os_log("Setting %{public}@ = %{public}@", log: settingsLogger, type: .info, k, value)
        defaults.set(value, forKey: k)
        defaults.synchronize()
    }
    
    func set(_ value: Double, for key: Key, screen: String? = nil) {
        let k = self.key(key, forScreen: screen)
        os_log("Setting %{public}@ = %{public}f", log: settingsLogger, type: .info, k, value)
        defaults.set(value, forKey: k)
        defaults.synchronize()
    }
    
    func set(_ value: Int, for key: Key, screen: String? = nil) {
        let k = self.key(key, forScreen: screen)
        os_log("Setting %{public}@ = %{public}d", log: settingsLogger, type: .info, k, value)
        defaults.set(value, forKey: k)
        defaults.synchronize()
    }
    
    func set(_ value: Bool, for key: Key, screen: String? = nil) {
        let k = self.key(key, forScreen: screen)
        os_log("Setting %{public}@ = %{public}d", log: settingsLogger, type: .info, k, value)
        defaults.set(value, forKey: k)
        defaults.synchronize()
    }
    
    func set(_ color: NSColor, for key: Key, screen: String? = nil) {
        let k = self.key(key, forScreen: screen)
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: true) {
            defaults.set(data, forKey: k)
            defaults.synchronize()
        }
    }
    
    // MARK: - Copy Settings Between Screens
    
    func copySettings(from sourceScreen: String?, to targetScreen: String) {
        let allKeys: [Key] = [
            .version, .font, .animationSpeed, .fallSpeed, .cycleSpeed, .cycleFrameSkip,
            .forwardSpeed, .raindropLength, .fps, .brightnessDecay, .numColumns, .resolution,
            .density, .glyphHeightToWidth, .glyphVerticalSpacing, .glyphEdgeCrop, .glyphFlip,
            .glyphRotation, .slant, .volumetric, .isometric, .isPolar, .baseTexture, .glintTexture,
            .backgroundColor, .cursorColor, .glintColor, .cursorIntensity, .glintIntensity,
            .isolateCursor, .isolateGlint, .baseBrightness, .baseContrast, .glintBrightness,
            .glintContrast, .brightnessOverride, .brightnessThreshold, .effect, .bloomStrength,
            .bloomSize, .highPassThreshold, .ditherMagnitude, .hasThunder, .rippleTypeName,
            .rippleScale, .rippleThickness, .rippleSpeed, .renderer, .useHalfFloat, .skipIntro, .loops
        ]
        
        for key in allKeys {
            let sourceKey = sourceScreen.map { "\(key.rawValue)_\($0)" } ?? key.rawValue
            let targetKey = "\(key.rawValue)_\(targetScreen)"
            
            if let value = defaults.object(forKey: sourceKey) {
                defaults.set(value, forKey: targetKey)
            }
        }
        defaults.synchronize()
    }
    
    func copyToAllScreens(from sourceScreen: String?) {
        for screen in NSScreen.screens {
            if let screenID = screenID(for: screen), screenID != sourceScreen {
                copySettings(from: sourceScreen, to: screenID)
            }
        }
    }
    
    // MARK: - Screen ID Helper
    
    func screenID(for screen: NSScreen) -> String? {
        if let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
            return String(screenNumber)
        }
        return nil
    }
    
    // MARK: - Build URL Query String
    
    func buildQueryString(forScreen screenID: String? = nil) -> String {
        var items: [URLQueryItem] = []
        
        os_log("buildQueryString: screenID=%{public}@, usePerMonitor=%{public}d", log: settingsLogger, type: .info, screenID ?? "nil", usePerMonitorSettings)
        
        // Helper to add non-default string values
        func addString(_ key: Key, defaultValue: String, paramName: String? = nil) {
            let value = string(for: key, screen: screenID)
            if value != defaultValue && !value.isEmpty {
                items.append(URLQueryItem(name: paramName ?? key.rawValue, value: value))
            }
        }
        
        // Helper to add non-default double values
        func addDouble(_ key: Key, defaultValue: Double, paramName: String? = nil) {
            let value = double(for: key, screen: screenID)
            if abs(value - defaultValue) > 0.001 {
                items.append(URLQueryItem(name: paramName ?? key.rawValue, value: String(value)))
            }
        }
        
        // Helper to add non-default int values
        func addInt(_ key: Key, defaultValue: Int, paramName: String? = nil) {
            let value = integer(for: key, screen: screenID)
            if value != defaultValue {
                items.append(URLQueryItem(name: paramName ?? key.rawValue, value: String(value)))
            }
        }
        
        // Helper to add non-default bool values
        func addBool(_ key: Key, defaultValue: Bool, paramName: String? = nil) {
            let value = bool(for: key, screen: screenID)
            if value != defaultValue {
                items.append(URLQueryItem(name: paramName ?? key.rawValue, value: value ? "true" : "false"))
            }
        }
        
        // Helper to add color as HSL
        func addColor(_ key: Key, defaultColor: NSColor, paramName: String) {
            let color = self.color(for: key, screen: screenID)
            let calibrated = color.usingColorSpace(.deviceRGB) ?? color
            let defaultCalibrated = defaultColor.usingColorSpace(.deviceRGB) ?? defaultColor
            
            if calibrated.hueComponent != defaultCalibrated.hueComponent ||
               calibrated.saturationComponent != defaultCalibrated.saturationComponent ||
               calibrated.brightnessComponent != defaultCalibrated.brightnessComponent {
                let h = calibrated.hueComponent
                let s = calibrated.saturationComponent
                let l = calibrated.brightnessComponent
                items.append(URLQueryItem(name: paramName, value: "\(h),\(s),\(l)"))
            }
        }
        
        // Presets
        addString(.version, defaultValue: Defaults.version)
        addString(.font, defaultValue: Defaults.font)
        
        // Animation
        addDouble(.animationSpeed, defaultValue: Defaults.animationSpeed)
        addDouble(.fallSpeed, defaultValue: Defaults.fallSpeed)
        addDouble(.cycleSpeed, defaultValue: Defaults.cycleSpeed)
        addInt(.cycleFrameSkip, defaultValue: Defaults.cycleFrameSkip)
        addDouble(.forwardSpeed, defaultValue: Defaults.forwardSpeed)
        addDouble(.raindropLength, defaultValue: Defaults.raindropLength)
        addInt(.fps, defaultValue: Defaults.fps)
        addDouble(.brightnessDecay, defaultValue: Defaults.brightnessDecay)
        
        // Appearance
        addInt(.numColumns, defaultValue: Defaults.numColumns)
        addDouble(.resolution, defaultValue: Defaults.resolution)
        addDouble(.density, defaultValue: Defaults.density)
        addDouble(.glyphHeightToWidth, defaultValue: Defaults.glyphHeightToWidth)
        addDouble(.glyphVerticalSpacing, defaultValue: Defaults.glyphVerticalSpacing)
        addDouble(.glyphEdgeCrop, defaultValue: Defaults.glyphEdgeCrop)
        addBool(.glyphFlip, defaultValue: Defaults.glyphFlip)
        addInt(.glyphRotation, defaultValue: Defaults.glyphRotation)
        addDouble(.slant, defaultValue: Defaults.slant)
        addBool(.volumetric, defaultValue: Defaults.volumetric)
        addBool(.isometric, defaultValue: Defaults.isometric)
        addBool(.isPolar, defaultValue: Defaults.isPolar)
        
        // Textures (only add if not "none")
        let baseTexture = string(for: .baseTexture, screen: screenID)
        if baseTexture != "none" && !baseTexture.isEmpty {
            items.append(URLQueryItem(name: "baseTexture", value: baseTexture))
        }
        let glintTexture = string(for: .glintTexture, screen: screenID)
        if glintTexture != "none" && !glintTexture.isEmpty {
            items.append(URLQueryItem(name: "glintTexture", value: glintTexture))
        }
        
        // Colors
        addColor(.backgroundColor, defaultColor: Defaults.backgroundColor, paramName: "backgroundHSL")
        addColor(.cursorColor, defaultColor: Defaults.cursorColor, paramName: "cursorHSL")
        addColor(.glintColor, defaultColor: Defaults.glintColor, paramName: "glintHSL")
        addDouble(.cursorIntensity, defaultValue: Defaults.cursorIntensity)
        addDouble(.glintIntensity, defaultValue: Defaults.glintIntensity, paramName: "glyphIntensity")
        addBool(.isolateCursor, defaultValue: Defaults.isolateCursor)
        addBool(.isolateGlint, defaultValue: Defaults.isolateGlint)
        addDouble(.baseBrightness, defaultValue: Defaults.baseBrightness)
        addDouble(.baseContrast, defaultValue: Defaults.baseContrast)
        addDouble(.glintBrightness, defaultValue: Defaults.glintBrightness)
        addDouble(.glintContrast, defaultValue: Defaults.glintContrast)
        addDouble(.brightnessOverride, defaultValue: Defaults.brightnessOverride)
        addDouble(.brightnessThreshold, defaultValue: Defaults.brightnessThreshold)
        
        // Effects
        addString(.effect, defaultValue: Defaults.effect)
        addDouble(.bloomStrength, defaultValue: Defaults.bloomStrength)
        addDouble(.bloomSize, defaultValue: Defaults.bloomSize)
        addDouble(.highPassThreshold, defaultValue: Defaults.highPassThreshold)
        addDouble(.ditherMagnitude, defaultValue: Defaults.ditherMagnitude)
        addBool(.hasThunder, defaultValue: Defaults.hasThunder)
        
        // Ripple (only add if not "none")
        let rippleType = string(for: .rippleTypeName, screen: screenID)
        if rippleType != "none" && !rippleType.isEmpty {
            items.append(URLQueryItem(name: "rippleTypeName", value: rippleType))
            addDouble(.rippleScale, defaultValue: Defaults.rippleScale)
            addDouble(.rippleThickness, defaultValue: Defaults.rippleThickness)
            addDouble(.rippleSpeed, defaultValue: Defaults.rippleSpeed)
        }
        
        // Advanced
        addString(.renderer, defaultValue: Defaults.renderer)
        addBool(.useHalfFloat, defaultValue: Defaults.useHalfFloat)
        addBool(.skipIntro, defaultValue: Defaults.skipIntro)
        addBool(.loops, defaultValue: Defaults.loops)
        
        // Always suppress warnings in screensaver context
        items.append(URLQueryItem(name: "suppressWarnings", value: "true"))
        
        var components = URLComponents()
        components.queryItems = items.isEmpty ? nil : items
        let query = components.query ?? ""
        os_log("buildQueryString: result=%{public}@", log: settingsLogger, type: .info, query)
        return query
    }
    
    // MARK: - Available Options
    
    static let availableVersions = [
        "classic", "3d", "megacity", "neomatrixology", "operator", "nightmare",
        "paradise", "resurrections", "trinity", "morpheus", "bugs", "palimpsest", "twilight"
    ]
    
    static let availableFonts = [
        "matrixcode", "resurrections", "gothic", "coptic", "megacity",
        "huberfishA", "huberfishD", "gtarg_tenretniolleh", "gtarg_alientext", "neomatrixology"
    ]
    
    static let availableEffects = ["palette", "plain", "stripes", "pride", "trans", "none"]
    
    static let availableTextures = ["none", "sand", "pixels", "mesh", "metal"]
    
    static let availableRippleTypes = ["none", "box", "circle"]
    
    static let availableRenderers = ["regl", "webgpu"]
}
