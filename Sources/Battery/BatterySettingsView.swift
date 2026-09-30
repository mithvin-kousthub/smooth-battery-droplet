import SwiftUI
import DroppyKit

public struct BatterySettingsView: View {
    @ObservedObject var droplet: BatteryDroplet

    public init(droplet: BatteryDroplet) {
        self.droplet = droplet
    }

    public var body: some View {
        DropletSettingsPane {
            DropletSettingsCard {
                if droplet.monitor.hasInternalBattery {
                    DropletControlRow(title: "Battery level") {
                        DropletValuePill(text: "\(droplet.monitor.percentage)%")
                    }

                    DropletControlRow(title: "Power state") {
                        DropletValuePill(text: droplet.monitor.stateSubtitle)
                    }

                    DropletControlRow(title: "Low power mode") {
                        DropletValuePill(text: droplet.monitor.lowPowerModeActive ? "On" : "Off")
                    }

                    DropletControlRow(title: "Battery condition") {
                        DropletValuePill(text: droplet.monitor.batteryHealth)
                    }
                } else {
                    DropletControlRow(title: "Power source") {
                        DropletValuePill(text: droplet.monitor.powerSourceState)
                    }

                    DropletControlRow(title: "Battery") {
                        DropletValuePill(text: "Not present")
                    }

                    DropletControlRow(title: "Low power mode") {
                        DropletValuePill(text: droplet.monitor.lowPowerModeActive ? "On" : "Off")
                    }
                }
            }
        }
    }
}

