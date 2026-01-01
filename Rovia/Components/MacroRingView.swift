import SwiftUI

struct MacroRingView: View {
    let current: Int
    let target: Int
    let label: String
    let color: Color
    var size: CGFloat = 100
    var lineWidth: CGFloat = 8

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(Double(current) / Double(target), 1.0)
    }

    private var displayValue: String {
        if current >= 1000 {
            return String(format: "%.1fk", Double(current) / 1000)
        }
        return "\(current)"
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Theme.Colors.muted, lineWidth: lineWidth)

            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)

            // Center text
            VStack(spacing: 2) {
                Text(displayValue)
                    .font(.system(size: size * 0.22, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.Colors.foreground)

                Text(label)
                    .font(.system(size: size * 0.12, weight: .medium))
                    .foregroundColor(Theme.Colors.mutedForeground)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Compact Macro Display
struct MacroChip: View {
    let value: Int
    let label: String
    let color: Color
    var unit: String = ""

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)\(unit)")
                .font(.system(size: Theme.Typography.base, weight: .semibold))
                .foregroundColor(color)

            Text(label)
                .font(.system(size: Theme.Typography.xs))
                .foregroundColor(Theme.Colors.mutedForeground)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.Colors.muted)
        .cornerRadius(Theme.Radius.sm)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 40) {
        MacroRingView(
            current: 1450,
            target: 2000,
            label: "cal",
            color: Theme.Colors.calories,
            size: 180,
            lineWidth: 12
        )

        HStack(spacing: 20) {
            MacroRingView(
                current: 95,
                target: 150,
                label: "protein",
                color: Theme.Colors.protein,
                size: 90,
                lineWidth: 6
            )

            MacroRingView(
                current: 180,
                target: 250,
                label: "carbs",
                color: Theme.Colors.carbs,
                size: 90,
                lineWidth: 6
            )

            MacroRingView(
                current: 45,
                target: 70,
                label: "fat",
                color: Theme.Colors.fat,
                size: 90,
                lineWidth: 6
            )
        }
    }
    .padding()
    .background(Theme.Colors.background)
}
