import DroppyKit
import DroppyKitHarness
import Battery

@main
struct BatteryHarness: DropletHarnessApp {
    static func makeDroplet() -> any Droplet {
        BatteryDroplet()
    }
}
