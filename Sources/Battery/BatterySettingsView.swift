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

                DropletControlRow(title: "Battery condition") {
                    DropletValuePill(text: droplet.monitor.batteryHealth)
                }
            }

            // Options Card: Show time remaining below Battery status
            DropletSettingsCard {
                DropletToggleRow(
                    title: "Show time remaining",
                    subtitle: "Estimates time remaining on battery or until full charge.",
                    isOn: droplet.showsTimeRemainingBinding
                )
            }
        }
    }
}
