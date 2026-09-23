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
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Lifecycle

    public func activate(host: DropletHost) throws {
        self.host = host
        host.log.info("Battery droplet activated")

        monitor.start()

        // Forward monitor updates to objectWillChange for SwiftUI reactivity
        monitor.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    public func deactivate() {
        cancellables.removeAll()
        monitor.stop()
        host = nil
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
                    contentHeight: .fixed(106)
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

// MARK: - Settings Pane Providing

extension BatteryDroplet: SettingsPaneProviding {
    public func makeSettingsPane(context: SettingsPaneContext) -> AnyView {
        AnyView(BatterySettingsView(droplet: self))
    }

    public var settingsSearchEntries: [SettingsSearchEntry] {
        [
            SettingsSearchEntry(title: "Battery level", keywords: ["battery", "percentage", "charge"]),
            SettingsSearchEntry(title: "Show time remaining", keywords: ["time", "battery", "remaining"])
        ]
    }
}
