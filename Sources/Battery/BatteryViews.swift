import SwiftUI
import DroppyKit

// MARK: - Smooth Battery Gauge Component

public struct SmoothBatteryShape: View {
    public let percentage: Int
    public let isCharging: Bool
    public let isLowPower: Bool
    public let width: CGFloat
    public let height: CGFloat

    public init(percentage: Int, isCharging: Bool, isLowPower: Bool = false, width: CGFloat = 72, height: CGFloat = 32) {
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
        let cornerRadius = height * 0.28
        let capWidth = max(2.5, width * 0.05)
        let capHeight = height * 0.38
        let innerPadding: CGFloat = 2.5
        let innerWidth = max(0, width - innerPadding * 2)
        let innerRadius = max(2, cornerRadius - innerPadding)
        let currentFillWidth = innerWidth * (CGFloat(percentage) / 100.0)

        HStack(spacing: 2.5) {
            // Main battery capsule
            ZStack(alignment: .leading) {
                // Outer shell stroke and background
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(AdaptiveColors.notchSurfacePrimaryText.opacity(0.35), lineWidth: 1.8)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.black.opacity(0.3))
                    )

                // Inner track + liquid fill
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                        .fill(Color.white.opacity(0.06))

                    if percentage > 0 {
                        RoundedRectangle(cornerRadius: max(1.5, innerRadius - 1), style: .continuous)
                            .fill(fillColor)
                            .frame(width: max(4, currentFillWidth))
                            .animation(DroppyAnimation.state, value: percentage)
                            .animation(DroppyAnimation.state, value: isCharging)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: innerRadius, style: .continuous))
                .padding(innerPadding)

                // Centered charging bolt
                if isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: height * 0.48, weight: .bold))
                        .foregroundStyle(percentage > 55 ? Color.black.opacity(0.75) : AdaptiveColors.notchSurfacePrimaryText)
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
    @ObservedObject var monitor: BatteryMonitor
    let context: ShelfWidgetContext

    public init(droplet: BatteryDroplet, context: ShelfWidgetContext) {
        self.droplet = droplet
        self.monitor = droplet.monitor
        self.context = context
    }

    private var statusDotColor: Color {
        if monitor.isCharging || monitor.isCharged || (monitor.isACConnected && monitor.percentage == 100) {
            return Color(red: 0.20, green: 0.84, blue: 0.45) // Green
        } else if monitor.lowPowerModeActive || monitor.percentage <= 20 {
            return Color(red: 1.00, green: 0.80, blue: 0.00) // Amber
        } else {
            return AdaptiveColors.notchSurfaceSecondaryText // Muted silver
        }
    }

    public var body: some View {
        ZStack {
            // Distinct outer container with continuous radius covering the slot end-to-end
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )

            // Content structured end-to-end and center-aligned
            VStack(spacing: 0) {
                // Header row
                HStack(spacing: DroppySpacing.xsm) {
                    Image(systemName: monitor.headerIconName)
                        .font(.system(size: 11, weight: .medium))
                    Text("Battery")
                        .font(.system(size: 11, weight: .semibold))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
                .padding(.horizontal, 14)
                .padding(.top, 10)

                Spacer(minLength: 0)

                // Main composition
                if context.isCompact {
                    pairedComposition
                } else {
                    soloComposition
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            monitor.refresh()
        }
        .onChange(of: context.isShelfTransitioning) { _, transitioning in
            if !transitioning {
                monitor.refresh()
            }
        }
    }

    // MARK: - Paired Composition (Slot width ~210, height ~106)
    private var pairedComposition: some View {
        VStack(alignment: .center, spacing: 6) {
            // Large, prominent, center-aligned battery gauge + percentage
            HStack(alignment: .center, spacing: DroppySpacing.md) {
                SmoothBatteryShape(
                    percentage: monitor.percentage,
                    isCharging: monitor.isCharging,
                    isLowPower: monitor.lowPowerModeActive,
                    width: 72,
                    height: 32
                )

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(monitor.percentage)")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)

                    Text("%")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
                }
            }

            // Center-aligned status & duration directly below the battery
            HStack(spacing: 5) {
                Circle()
                    .fill(statusDotColor)
                    .frame(width: 6, height: 6)

                Text(monitor.stateSubtitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(monitor.isCharging ? Color(red: 0.20, green: 0.84, blue: 0.45) : AdaptiveColors.notchSurfacePrimaryText)

                if droplet.showsTimeRemaining, let duration = monitor.formattedDuration {
                    Text("•")
                        .foregroundStyle(AdaptiveColors.notchSurfaceTertiaryText)
                    Text(duration)
                        .font(.system(size: 11))
                        .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
                }
            }
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
    }

    // MARK: - Solo Composition (Full width ~420, height ~106)
    private var soloComposition: some View {
        HStack(alignment: .center, spacing: DroppySpacing.xl) {
            // Left Column: Big centered battery gauge + percentage + state
            VStack(alignment: .center, spacing: 6) {
                HStack(alignment: .center, spacing: DroppySpacing.md) {
                    SmoothBatteryShape(
                        percentage: monitor.percentage,
                        isCharging: monitor.isCharging,
                        isLowPower: monitor.lowPowerModeActive,
                        width: 82,
                        height: 36
                    )

                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(monitor.percentage)")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)

                        Text("%")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
                    }
                }

                HStack(spacing: 5) {
                    Circle()
                        .fill(statusDotColor)
                        .frame(width: 6, height: 6)

                    Text(monitor.stateSubtitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)

                    if droplet.showsTimeRemaining, let duration = monitor.formattedDuration {
                        Text("•")
                            .foregroundStyle(AdaptiveColors.notchSurfaceTertiaryText)
                        Text(duration)
                            .font(.system(size: 11))
                            .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
                    }
                }
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            // Right Column: Power details & specs
            VStack(alignment: .leading, spacing: DroppySpacing.xs) {
                detailRow(label: "Power source", value: monitor.powerSourceState)
                if monitor.lowPowerModeActive {
                    detailRow(label: "Low power mode", value: "On")
                }
                detailRow(label: "Condition", value: monitor.batteryHealth)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, 14)
        .padding(.bottom, 6)
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
            Spacer(minLength: DroppySpacing.sm)
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)
        }
    }
}
