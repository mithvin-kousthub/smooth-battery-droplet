import SwiftUI
import DroppyKit

public struct BatterySettingsView: View {
    @ObservedObject var droplet: BatteryDroplet

    public init(droplet: BatteryDroplet) {
        self.droplet = droplet
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DroppySpacing.lg) {
            // Battery Status Card
            DropletSettingsCard {
                DropletControlRow(title: "Battery level") {
                    DropletValuePill(text: "\(droplet.monitor.percentage)%")
                }

                DropletSettingsDivider()

                DropletControlRow(title: "Power state") {
                    DropletValuePill(text: droplet.monitor.stateSubtitle)
                }

                DropletSettingsDivider()

                DropletControlRow(title: "Low power mode") {
                    DropletValuePill(text: droplet.monitor.lowPowerModeActive ? "On" : "Off")
                }

                DropletSettingsDivider()

                DropletControlRow(title: "Battery condition") {
                    DropletValuePill(text: droplet.monitor.batteryHealth)
                }
            }
        }
    }
}

