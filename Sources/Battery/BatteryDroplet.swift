import SwiftUI
import Combine
import DroppyKit

// MARK: - Principal Class

@objc(BatteryPrincipal)
public final class BatteryPrincipal: NSObject, DropletPrincipal {
    public override init() { super.init() }

    @MainActor public func makeDroplet() -> AnyObject {
        BatteryDroplet()
    }
}

// MARK: - Main Droplet Class

@MainActor
public final class BatteryDroplet: NSObject, ObservableObject, Droplet {
    public nonisolated static let id: DropletID = "smooth-battery"

    public let monitor = BatteryMonitor()
    private var host: DropletHost?
    private let activitySubject = CurrentValueSubject<LiveActivityState?, Never>(nil)
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Lifecycle

    public func activate(host: DropletHost) throws {
        self.host = host
        host.log.info("Battery droplet activated")

        monitor.start()

        // Forward monitor updates to live activity publisher and objectWillChange
        monitor.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
                self?.publishActivity()
            }
            .store(in: &cancellables)

        publishActivity()
    }

    public func deactivate() {
        cancellables.removeAll()
        monitor.stop()
        activitySubject.send(nil)
        host = nil
    }

    // MARK: - Live Activity Publishing

    private func publishActivity() {
        guard showsLiveActivity else {
            activitySubject.send(nil)
            return
        }

        let state = LiveActivityState(
            priority: 150,
            accessibilityTitle: "Battery \(monitor.percentage)%, \(monitor.stateSubtitle)",
            isInteractive: false
        )
        activitySubject.send(state)
    }

    // MARK: - Preferences & Settings

    public var showsTimeRemaining: Bool {
        host?.preferences.value(forKey: "showsTimeRemaining", default: true) ?? true
    }

    public var showsTimeRemainingBinding: Binding<Bool> {
        Binding(
            get: { self.showsTimeRemaining },
            set: { [weak self] val in
                self?.host?.preferences.setValue(val, forKey: "showsTimeRemaining")
                self?.objectWillChange.send()
            }
        )
    }

    public var showsLiveActivity: Bool {
        host?.preferences.value(forKey: "showsLiveActivity", default: true) ?? true
    }

    public var showsLiveActivityBinding: Binding<Bool> {
        Binding(
            get: { self.showsLiveActivity },
            set: { [weak self] val in
                self?.host?.preferences.setValue(val, forKey: "showsLiveActivity")
                self?.objectWillChange.send()
                self?.publishActivity()
            }
        )
    }
}

// MARK: - Shelf Widget Providing

extension BatteryDroplet: ShelfWidgetProviding {
    public var widgetDescriptors: [ShelfWidgetDescriptor] {
        [
            ShelfWidgetDescriptor(
                id: "smooth-battery",
                title: "Battery",
                systemImage: "battery.100percent.bolt",
                layoutTraits: ShelfWidgetLayoutTraits(
                    preferredSoloWidth: 420,
                    preferredPairedWidth: 210,
                    contentHeight: .standard
                ),
                searchKeywords: ["battery", "power", "charge", "percentage"]
            )
        ]
    }

    public func makeWidgetView(_ id: ShelfWidgetID, context: ShelfWidgetContext) -> AnyView {
        AnyView(BatteryWidgetView(droplet: self, context: context))
    }

    public func makeWidgetSettingsPopover(_ id: ShelfWidgetID) -> AnyView? {
        nil
    }
}

// MARK: - Live Activity Providing

extension BatteryDroplet: LiveActivityProviding {
    public var liveActivityState: AnyPublisher<LiveActivityState?, Never> {
        activitySubject.eraseToAnyPublisher()
    }

    public func makeCompactLeading() -> AnyView {
        AnyView(
            BatteryCompactLeadingView(
                percentage: monitor.percentage,
                isCharging: monitor.isCharging,
                isLowPower: monitor.lowPowerModeActive
            )
        )
    }

    public func makeCompactTrailing() -> AnyView {
        AnyView(
            BatteryCompactTrailingView(
                percentage: monitor.percentage,
                isCharging: monitor.isCharging
            )
        )
    }

    public func makeExpanded(context: LiveActivityContext) -> AnyView {
        // Droppy does not mount this card (hover opens the shelf),
        // but it is required by the LiveActivityProviding protocol.
        AnyView(
            HStack(spacing: DroppySpacing.md) {
                SmoothBatteryShape(
                    percentage: monitor.percentage,
                    isCharging: monitor.isCharging,
                    isLowPower: monitor.lowPowerModeActive,
                    width: 50,
                    height: 24
                )
                Text("\(monitor.percentage)% • \(monitor.stateSubtitle)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)
            }
            .frame(width: context.availableWidth, height: DroppyLiveActivityMetrics.cardContentHeight)
        )
    }
}

// MARK: - Settings Pane Providing

extension BatteryDroplet: SettingsPaneProviding {
    public func makeSettingsPane(context: SettingsPaneContext) -> AnyView {
        AnyView(BatterySettingsView(droplet: self))
    }

    public var settingsSearchEntries: [SettingsSearchEntry] {
        [
            SettingsSearchEntry(title: "Battery level", keywords: ["battery", "percentage", "charge"]),
            SettingsSearchEntry(title: "Show time remaining", keywords: ["time", "battery", "remaining"]),
            SettingsSearchEntry(title: "Live activity in notch", keywords: ["notch", "island", "battery", "activity"])
        ]
    }
}
