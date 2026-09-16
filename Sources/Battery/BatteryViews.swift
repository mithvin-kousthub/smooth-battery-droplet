import SwiftUI
import DroppyKit

// MARK: - Smooth Battery Gauge Component

public struct SmoothBatteryShape: View {
    public let percentage: Int
    public let isCharging: Bool
    public let isLowPower: Bool
    public let width: CGFloat
    public let height: CGFloat

    public init(percentage: Int, isCharging: Bool, isLowPower: Bool = false, width: CGFloat = 60, height: CGFloat = 28) {
        self.percentage = max(0, min(100, percentage))
        self.isCharging = isCharging
        self.isLowPower = isLowPower
        self.width = width
        self.height = height
    }

    private var fillColor: Color {
        if isCharging {
            return Color(red: 0.20, green: 0.84, blue: 0.45) // Apple Battery Green
        } else if isLowPower {
            return Color(red: 1.00, green: 0.80, blue: 0.00) // Apple Low Power Yellow
        } else if percentage <= 10 {
            return Color(red: 1.00, green: 0.30, blue: 0.28) // Critical Red
        } else if percentage <= 20 {
            return Color(red: 1.00, green: 0.80, blue: 0.00) // Low Amber
        } else {
            return Color(red: 0.20, green: 0.84, blue: 0.45) // Normal Green
        }
    }

    public var body: some View {
        let cornerRadius = height * 0.30
        let capWidth = max(2.5, width * 0.05)
        let capHeight = height * 0.38
        let innerPadding: CGFloat = 2.5
        let innerWidth = max(0, width - innerPadding * 2)
        let innerRadius = max(2, cornerRadius - innerPadding)
        let currentFillWidth = innerWidth * (CGFloat(percentage) / 100.0)

        HStack(spacing: 2) {
            // Main battery capsule
            ZStack(alignment: .leading) {
                // Outer shell stroke
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(AdaptiveColors.notchSurfacePrimaryText.opacity(0.35), lineWidth: 1.6)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.black.opacity(0.25))
                    )

                // Inner track + liquid fill
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                        .fill(Color.white.opacity(0.06))

                    if percentage > 0 {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(fillColor)
                            .frame(width: max(3, currentFillWidth))
                            .animation(DroppyAnimation.state, value: percentage)
                            .animation(DroppyAnimation.state, value: isCharging)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: innerRadius, style: .continuous))
                .padding(innerPadding)

                // Centered charging bolt
                if isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: height * 0.44, weight: .bold))
                        .foregroundStyle(percentage > 55 ? Color.black.opacity(0.7) : AdaptiveColors.notchSurfacePrimaryText)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .frame(width: width, height: height)

            // Positive terminal cap
            RoundedRectangle(cornerRadius: capWidth * 0.4, style: .continuous)
                .fill(AdaptiveColors.notchSurfacePrimaryText.opacity(0.35))
                .frame(width: capWidth, height: capHeight)
        }
    }
}

// MARK: - Main Shelf Widget View

public struct BatteryWidgetView: View {
    @ObservedObject var droplet: BatteryDroplet
    let context: ShelfWidgetContext

    public init(droplet: BatteryDroplet, context: ShelfWidgetContext) {
        self.droplet = droplet
        self.context = context
    }

    private var statusDotColor: Color {
        if droplet.monitor.isCharging || droplet.monitor.isCharged || (droplet.monitor.isACConnected && droplet.monitor.percentage == 100) {
            return Color(red: 0.20, green: 0.84, blue: 0.45) // Green
        } else if droplet.monitor.lowPowerModeActive || droplet.monitor.percentage <= 20 {
            return Color(red: 1.00, green: 0.80, blue: 0.00) // Amber
        } else {
            return AdaptiveColors.notchSurfaceSecondaryText // Muted silver
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DroppySpacing.sm) {
            // Standard Droppy Header Row (clean, no awkward corner controls)
            HStack(spacing: DroppySpacing.xsm) {
                Image(systemName: droplet.monitor.isCharging ? "battery.100percent.bolt" : "battery.75percent")
                    .font(.system(size: 12, weight: .medium))
                Text("Battery")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)

            // Body branching on context.isCompact
            if context.isCompact {
                pairedComposition
            } else {
                soloComposition
            }

            Spacer(minLength: 0)
        }
        .padding(context.contentInsets)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Paired Composition (Slot width ~210)
    private var pairedComposition: some View {
        VStack(alignment: .leading, spacing: DroppySpacing.xs) {
            // Battery gauge and percentage unified on the leading side
            HStack(alignment: .center, spacing: DroppySpacing.md) {
                SmoothBatteryShape(
                    percentage: droplet.monitor.percentage,
                    isCharging: droplet.monitor.isCharging,
                    isLowPower: droplet.monitor.lowPowerModeActive,
                    width: 48,
                    height: 22
                )

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(droplet.monitor.percentage)")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)

                    Text("%")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(droplet.monitor.stateSubtitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(droplet.monitor.isCharging ? Color(red: 0.20, green: 0.84, blue: 0.45) : AdaptiveColors.notchSurfacePrimaryText)

                if droplet.showsTimeRemaining, let duration = droplet.monitor.formattedDuration {
                    Text(duration)
                        .font(.system(size: 11))
                        .foregroundStyle(AdaptiveColors.notchSurfaceTertiaryText)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Solo Composition (Full width ~420)
    private var soloComposition: some View {
        HStack(alignment: .top, spacing: DroppySpacing.xl) {
            // Left Column: Battery gauge + percentage + state
            VStack(alignment: .leading, spacing: DroppySpacing.sm) {
                HStack(alignment: .center, spacing: DroppySpacing.md) {
                    SmoothBatteryShape(
                        percentage: droplet.monitor.percentage,
                        isCharging: droplet.monitor.isCharging,
                        isLowPower: droplet.monitor.lowPowerModeActive,
                        width: 62,
                        height: 28
                    )

                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(droplet.monitor.percentage)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)

                        Text("%")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
                    }
                }

                HStack(spacing: DroppySpacing.xs) {
                    Circle()
                        .fill(statusDotColor)
                        .frame(width: 7, height: 7)

                    Text(droplet.monitor.stateSubtitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)

                    if droplet.showsTimeRemaining, let duration = droplet.monitor.formattedDuration {
                        Text("•")
                            .foregroundStyle(AdaptiveColors.notchSurfaceTertiaryText)
                        Text(duration)
                            .font(.system(size: 12))
                            .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right Column: Power details & specs
            VStack(alignment: .leading, spacing: DroppySpacing.xs) {
                detailRow(label: "Power source", value: droplet.monitor.powerSourceState)
                if droplet.monitor.lowPowerModeActive {
                    detailRow(label: "Low power mode", value: "On")
                }
                detailRow(label: "Condition", value: droplet.monitor.batteryHealth)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, DroppySpacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
            Spacer(minLength: DroppySpacing.md)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)
        }
    }
}
