import SwiftUI
import DroppyKit

// MARK: - Compact Live Activity Views (Notch Wings)

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
            width: 24,
            height: 12
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
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text("\(percentage)")
                .font(.system(size: DroppyLiveActivityMetrics.labelFontSize, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)

            Text("%")
                .font(.system(size: DroppyLiveActivityMetrics.labelFontSize * 0.72, weight: .medium, design: .rounded))
                .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
        }
    }
}

// MARK: - Companion Pill (Secondary Live Activity Below the Notch)

public struct BatteryCompanionPillView: View {
    public let percentage: Int
    public let isCharging: Bool
    public let isLowPower: Bool
    public let slotSize: CGSize

    public init(percentage: Int, isCharging: Bool, isLowPower: Bool, slotSize: CGSize) {
        self.percentage = percentage
        self.isCharging = isCharging
        self.isLowPower = isLowPower
        self.slotSize = slotSize
    }

    private var tintColor: Color {
        if isCharging {
            return Color(red: 0.20, green: 0.84, blue: 0.45)
        } else if isLowPower || percentage <= 20 {
            return Color(red: 1.00, green: 0.80, blue: 0.00)
        } else if percentage <= 10 {
            return Color(red: 1.00, green: 0.30, blue: 0.28)
        } else {
            return Color(red: 0.20, green: 0.84, blue: 0.45)
        }
    }

    public var body: some View {
        let size = min(slotSize.width, slotSize.height)
        let ringDiameter = max(16, min(DroppyLiveActivityMetrics.progressRingSize, size - 4))
        let progress = CGFloat(max(0, min(100, percentage))) / 100.0

        ZStack {
            // Background track
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: DroppyLiveActivityMetrics.progressRingLineWidth)
                .frame(width: ringDiameter, height: ringDiameter)

            // Dynamic progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tintColor, style: StrokeStyle(lineWidth: DroppyLiveActivityMetrics.progressRingLineWidth, lineCap: .round))
                .frame(width: ringDiameter, height: ringDiameter)
                .rotationEffect(.degrees(-90))
                .animation(DroppyAnimation.state, value: percentage)

            // Center mark: bold lightning bolt if charging, otherwise compact percentage
            if isCharging {
                Image(systemName: "bolt.fill")
                    .font(.system(size: DroppyLiveActivityMetrics.progressRingGlyphSize, weight: .bold))
                    .foregroundStyle(tintColor)
            } else if percentage < 100 {
                Text("\(percentage)")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)
            } else {
                Image(systemName: "checkmark")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(tintColor)
            }
        }
        .frame(width: slotSize.width, height: slotSize.height, alignment: .center)
    }
}

// MARK: - Companion Accordion Detail (Expanded on Hover)

public struct BatteryCompanionDetailView: View {
    public let percentage: Int
    public let isCharging: Bool
    public let isLowPower: Bool
    public let stateSubtitle: String

    public init(percentage: Int, isCharging: Bool, isLowPower: Bool, stateSubtitle: String) {
        self.percentage = percentage
        self.isCharging = isCharging
        self.isLowPower = isLowPower
        self.stateSubtitle = stateSubtitle
    }

    public var body: some View {
        HStack(spacing: DroppySpacing.xs) {
            Text("\(percentage)%")
                .font(.system(size: DroppyLiveActivityMetrics.labelFontSize, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)

            Text("•")
                .foregroundStyle(AdaptiveColors.notchSurfaceTertiaryText)

            Text(stateSubtitle)
                .font(.system(size: DroppyLiveActivityMetrics.labelFontSize, weight: .medium))
                .foregroundStyle(isCharging ? Color(red: 0.20, green: 0.84, blue: 0.45) : AdaptiveColors.notchSurfaceSecondaryText)
        }
        .lineLimit(1)
    }
}
