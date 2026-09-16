import Foundation
import Combine
import IOKit.ps

/// Real-time macOS battery & power source monitor using IOKit IOPowerSources.
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

    public init() {
        refresh()
    }

    public func start() {
        refresh()

        // 1. Register for real-time OS power source notifications via CFRunLoop
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        if let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let monitor = Unmanaged<BatteryMonitor>.fromOpaque(context).takeUnretainedValue()
            Task { @MainActor in
                monitor.refresh()
            }
        }, context)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            self.runLoopSource = source
        }

        // 2. Periodic fallback to update minute counters smoothly
        periodicTimer = Timer.publish(every: 10, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refresh()
            }
    }

    public func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
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

                // Time remaining on battery: positive integer in minutes, or negative if calculating
                if let toEmpty = desc[kIOPSTimeToEmptyKey] as? Int, toEmpty > 0 {
                    self.timeRemainingMinutes = toEmpty
                } else {
                    self.timeRemainingMinutes = nil
                }

                // Time to full charge: positive integer in minutes
                if let toFull = desc[kIOPSTimeToFullChargeKey] as? Int, toFull > 0 {
                    self.timeToFullChargeMinutes = toFull
                } else {
                    self.timeToFullChargeMinutes = nil
                }

                if let lpm = desc["LPM Active"] as? Bool {
                    self.lowPowerModeActive = lpm
                } else if let lpmInt = desc["LPM Active"] as? Int {
                    self.lowPowerModeActive = (lpmInt != 0)
                } else {
                    self.lowPowerModeActive = ProcessInfo.processInfo.isLowPowerModeEnabled
                }

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

    /// User-friendly formatted time remaining / charge status.
    public var formattedDuration: String? {
        if isCharging {
            if let toFull = timeToFullChargeMinutes {
                let h = toFull / 60
                let m = toFull % 60
                return h > 0 ? "\(h)h \(m)m until full" : "\(m)m until full"
            }
            return isCharged ? "Fully charged" : "Charging"
        } else if isACConnected {
            return isCharged ? "Fully charged" : "Power connected"
        } else if let toEmpty = timeRemainingMinutes {
            let h = toEmpty / 60
            let m = toEmpty % 60
            return h > 0 ? "\(h)h \(m)m remaining" : "\(m)m remaining"
        }
        return nil
    }

    /// Primary state subtitle.
    public var stateSubtitle: String {
        if isCharging {
            return "Charging"
        } else if isCharged && isACConnected {
            return "Charged"
        } else if isACConnected {
            return "Power Connected"
        } else {
            return "On Battery"
        }
    }
}
