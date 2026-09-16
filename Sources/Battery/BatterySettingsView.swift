import SwiftUI
import DroppyKit

public struct BatterySettingsView: View {
    @ObservedObject var droplet: BatteryDroplet

    public init(droplet: BatteryDroplet) {
        self.droplet = droplet
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DroppySpacing.lg) {
            // General Settings Card
            DropletSettingsCard {
                DropletToggleRow(
                    title: "Show time remaining",
                    subtitle: "Estimates time remaining on battery or until full charge.",
                    isOn: droplet.showsTimeRemainingBinding
                )

                DropletSettingsDivider()

                DropletToggleRow(
                    title: "Live activity in notch",
                    subtitle: "Shows compact battery indicator beside the notch or island.",
                    isOn: droplet.showsLiveActivityBinding
                )
            }

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
        }
    }
}
