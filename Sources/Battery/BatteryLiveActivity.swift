import SwiftUI
import DroppyKit

// MARK: - Compact Live Activity Views

public struct BatteryCompactLeadingView: View {
    public let percentage: Int
    public let isCharging: Bool
    public let isLowPower: Bool

    public init(percentage: Int, isCharging: Bool, isLowPower: Bool) {
        self.percentage = percentage
        self.isCharging = isCharging
        self.isLowPower = isLowPower
    }

    public var body: some View {
        SmoothBatteryShape(
            percentage: percentage,
            isCharging: isCharging,
            isLowPower: isLowPower,
            width: 26,
            height: 14
        )
    }
}

public struct BatteryCompactTrailingView: View {
    public let percentage: Int
    public let isCharging: Bool

    public init(percentage: Int, isCharging: Bool) {
        self.percentage = percentage
        self.isCharging = isCharging
    }

    public var body: some View {
        HStack(spacing: 1) {
            Text("\(percentage)")
                .font(.system(size: DroppyLiveActivityMetrics.labelFontSize, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text("%")
                .font(.system(size: DroppyLiveActivityMetrics.labelFontSize * 0.75, weight: .medium, design: .rounded))
        }
        .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)
    }
}
