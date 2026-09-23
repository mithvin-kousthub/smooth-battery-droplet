import Foundation
import Combine
import IOKit.ps
import notify
import AppKit

/// Real-time macOS battery & power source monitor using IOKit IOPowerSources and Darwin notifications.
@MainActor
public final class BatteryMonitor: ObservableObject {
    @Published public private(set) var percentage: Int = 100
    @Published public private(set) var isCharging: Bool = false
    @Published public private(set) var isCharged: Bool = false
    @Published public private(set) var isACConnected: Bool = true
    @Published public private(set) var powerSourceState: String = "AC Power"
    @Published public private(set) var timeRemainingMinutes: Int? = nil
    @Published public private(set) var timeToFullChargeMinutes: Int? = nil
    @Published public private(set) var lowPowerModeActive: Bool = false
    @Published public private(set) var batteryHealth: String = "Normal"
    @Published public private(set) var hasInternalBattery: Bool = true

    private var runLoopSource: CFRunLoopSource?
    private var periodicTimer: AnyCancellable?
    private var workspaceCancellables = Set<AnyCancellable>()
    private var notifyTokens: [Int32] = []
    private var lpmNotifyToken: Int32 = -1
    private var isMonitoring: Bool = false

    public init() {
        start()
    }

    public func start() {
        guard !isMonitoring else {
            refresh()
            return
        }
        isMonitoring = true
        refresh()

        // 1. Register for real-time OS power source notifications via CFRunLoopSource
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        if let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let monitor = Unmanaged<BatteryMonitor>.fromOpaque(context).takeUnretainedValue()
            if Thread.isMainThread {
                monitor.refresh()
            } else {
                DispatchQueue.main.async {
                    monitor.refresh()
                }
            }
        }, context)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            self.runLoopSource = source
        }

        // 2. Darwin notifications for instantaneous kernel-level power and Low Power Mode events
        let kernelNotifications = [
            "com.apple.system.lowpowermode",
            "com.apple.system.powersources.lowpowermode",
            "com.apple.system.powersources",
            "com.apple.system.powersources.source",
            "com.apple.system.powersources.timeremaining",
            "com.apple.system.powersources.percent",
            "com.apple.system.powersources.lowbattery",
            "com.apple.system.powersources.attach"
        ]

        for name in kernelNotifications {
            var token: Int32 = 0
            let status = notify_register_dispatch(name, &token, DispatchQueue.main) { [weak self] t in
                if name == "com.apple.system.lowpowermode" {
                    self?.updateLowPowerMode()
                }
                self?.refresh()
            }
            if status == NOTIFY_STATUS_OK {
                if name == "com.apple.system.lowpowermode" {
                    self.lpmNotifyToken = token
                }
                notifyTokens.append(token)
            }
        }

        // 3. Foundation power state change notification (instantaneous Low Power Mode toggles)
        NotificationCenter.default.publisher(for: NSNotification.Name.NSProcessInfoPowerStateDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateLowPowerMode()
                self?.refresh()
            }
            .store(in: &workspaceCancellables)

        // 4. Workspace notifications on wake/sleep
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &workspaceCancellables)

        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.screensDidWakeNotification)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &workspaceCancellables)

        // 5. Ultra-responsive 0.5-second timer fallback to guarantee real-time accuracy
        periodicTimer = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateLowPowerMode()
                self?.refresh()
            }
    }

    public func stop() {
        guard isMonitoring else { return }
        isMonitoring = false

        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }

        for token in notifyTokens {
            notify_cancel(token)
        }
        notifyTokens.removeAll()
        lpmNotifyToken = -1

        workspaceCancellables.removeAll()
        periodicTimer?.cancel()
        periodicTimer = nil
    }

    public func refresh() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              !sources.isEmpty else {
            // Desktop Mac with no battery or unable to copy power sources
            self.hasInternalBattery = false
            self.percentage = 100
            self.isACConnected = true
            self.isCharging = false
            self.isCharged = true
            self.powerSourceState = "AC Power"
            return
        }

        var foundBattery = false

        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }

            let type = desc[kIOPSTypeKey] as? String ?? ""
            if type == kIOPSInternalBatteryType || desc[kIOPSIsPresentKey] as? Bool == true || (desc[kIOPSCurrentCapacityKey] as? Int) != nil {
                foundBattery = true

                let current = desc[kIOPSCurrentCapacityKey] as? Int ?? 100
                let maxCap = desc[kIOPSMaxCapacityKey] as? Int ?? 100
                if maxCap > 0 {
                    self.percentage = min(100, max(0, Int((Double(current) / Double(maxCap)) * 100.0)))
                } else {
                    self.percentage = current
                }

                self.isCharging = (desc[kIOPSIsChargingKey] as? Bool) ?? false
                self.isCharged = (desc[kIOPSIsChargedKey] as? Bool) ?? (self.percentage == 100 && (desc[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue))
                let psState = desc[kIOPSPowerSourceStateKey] as? String ?? kIOPSACPowerValue
                self.isACConnected = (psState == kIOPSACPowerValue)
                self.powerSourceState = self.isACConnected ? "Power Adapter" : "Battery Power"

                // Time remaining on battery & time to full charge with AppleSmartBattery fallback
                let smartBattery = self.readAppleSmartBatteryDetails()

                if let toEmpty = desc[kIOPSTimeToEmptyKey] as? Int, toEmpty > 0 && toEmpty < 65535 {
                    self.timeRemainingMinutes = toEmpty
                } else if let avgEmpty = smartBattery.avgTimeToEmpty {
                    self.timeRemainingMinutes = avgEmpty
                } else {
                    self.timeRemainingMinutes = nil
                }

                // Time to full charge: positive integer in minutes
                if let toFull = desc[kIOPSTimeToFullChargeKey] as? Int, toFull > 0 && toFull < 65535 {
                    self.timeToFullChargeMinutes = toFull
                } else if let avgFull = smartBattery.avgTimeToFull {
                    self.timeToFullChargeMinutes = avgFull
                } else {
                    self.timeToFullChargeMinutes = nil
                }

                self.updateLowPowerMode()

                if let health = desc[kIOPSBatteryHealthKey] as? String {
                    self.batteryHealth = health
                } else {
                    self.batteryHealth = "Normal"
                }

                break
            }
        }

        self.hasInternalBattery = foundBattery
    }

    /// Instantaneous detection of Low Power Mode via Foundation ProcessInfo and Darwin state
    public func updateLowPowerMode() {
        let processInfoActive = ProcessInfo.processInfo.isLowPowerModeEnabled
        var darwinActive = false
        if lpmNotifyToken >= 0 {
            var state: UInt64 = 0
            if notify_get_state(lpmNotifyToken, &state) == NOTIFY_STATUS_OK {
                darwinActive = (state != 0)
            }
        }
        let active = processInfoActive || darwinActive
        if self.lowPowerModeActive != active {
            self.lowPowerModeActive = active
        }
    }

    /// Reads IORegistry AppleSmartBattery properties for accurate average runtime and charge estimates
    private func readAppleSmartBatteryDetails() -> (avgTimeToEmpty: Int?, avgTimeToFull: Int?) {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return (nil, nil) }
        defer { IOObjectRelease(service) }

        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = props?.takeRetainedValue() as? [String: Any] else {
            return (nil, nil)
        }

        var emptyMin: Int? = nil
        if let val = dict["AvgTimeToEmpty"] as? Int, val > 0 && val < 65535 {
            emptyMin = val
        } else if let val = dict["TimeRemaining"] as? Int, val > 0 && val < 65535 {
            emptyMin = val
        }

        var fullMin: Int? = nil
        if let val = dict["AvgTimeToFull"] as? Int, val > 0 && val < 65535 {
            fullMin = val
        }

        return (emptyMin, fullMin)
    }

    /// Header SF symbol matching current state and level.
    public var headerIconName: String {
        if isCharging {
            return "battery.100percent.bolt"
        } else if percentage >= 88 {
            return "battery.100percent"
        } else if percentage >= 63 {
            return "battery.75percent"
        } else if percentage >= 38 {
            return "battery.50percent"
        } else if percentage >= 13 {
            return "battery.25percent"
        } else {
            return "battery.0percent"
        }
    }

    /// User-friendly formatted time duration, ensuring "Show time remaining" always delivers accurate estimates.
    public var formattedDuration: String? {
        if isCharging {
            if let toFull = timeToFullChargeMinutes, toFull > 0 {
                let h = toFull / 60
                let m = toFull % 60
                return h > 0 ? "\(h)h \(m)m until full" : "\(m)m until full"
            }
            return "Calculating..."
        } else if isACConnected {
            if isCharged || percentage == 100 {
                if let toEmpty = timeRemainingMinutes, toEmpty > 0 {
                    let h = toEmpty / 60
                    let m = toEmpty % 60
                    return h > 0 ? "~\(h)h \(m)m runtime" : "~\(m)m runtime"
                }
                return "Full charge"
            } else {
                if let toEmpty = timeRemainingMinutes, toEmpty > 0 {
                    let h = toEmpty / 60
                    let m = toEmpty % 60
                    return h > 0 ? "~\(h)h \(m)m on battery" : "~\(m)m on battery"
                }
                return "AC Power"
            }
        } else if let toEmpty = timeRemainingMinutes, toEmpty > 0 {
            let h = toEmpty / 60
            let m = toEmpty % 60
            return h > 0 ? "\(h)h \(m)m remaining" : "\(m)m remaining"
        }
        return "Calculating..."
    }

    /// Primary state subtitle.
    public var stateSubtitle: String {
        if isCharging {
            return "Charging"
        } else if isCharged || (isACConnected && percentage == 100) {
            return "Fully Charged"
        } else if isACConnected {
            return "Not Charging"
        } else {
            return "On Battery"
        }
    }
}
