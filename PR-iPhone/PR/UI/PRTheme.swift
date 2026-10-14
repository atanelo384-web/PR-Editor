import SwiftUI

enum PRTheme {
    static let background = Color(red: 0.045, green: 0.052, blue: 0.064)
    static let panel = Color(red: 0.105, green: 0.118, blue: 0.136)
    static let panelLight = Color(red: 0.16, green: 0.18, blue: 0.205)
    static let accent = Color(red: 0.66, green: 0.79, blue: 0.90)
    static let muted = Color(red: 0.54, green: 0.59, blue: 0.65)
    static let border = Color.white.opacity(0.12)
}

// Vector-rendered Aero button: no external images, crisp at any resolution.
struct AeroButton: View {
    let symbol: String
    let title: String
    var isSelected = false
    var isDisabled = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                Text(title).font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Color.white : Color(red: 0.86, green: 0.90, blue: 0.95))
            .padding(.horizontal, 13)
            .frame(height: 37)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(colors: isSelected ? [Color(red:0.32,green:0.47,blue:0.61), Color(red:0.10,green:0.17,blue:0.27)] : [PRTheme.panelLight, PRTheme.panel.opacity(0.92), Color(red: 0.07, green: 0.08, blue: 0.10)], startPoint: .top, endPoint: .bottom))
                    .overlay(alignment: .top) {
                        UnevenRoundedRectangle(topLeadingRadius: 7, topTrailingRadius: 7)
                            .fill(LinearGradient(colors: [.white.opacity(0.23), .clear], startPoint: .top, endPoint: .bottom))
                            .frame(height: 17)
                            .padding(1)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(LinearGradient(colors: [.white.opacity(0.34), .white.opacity(0.035), .white.opacity(0.15)], startPoint: .top, endPoint: .bottom), lineWidth: 0.8)
                    }
                    .shadow(color: .black.opacity(0.35), radius: 3, y: 2)
            }
        }
        .buttonStyle(.plain)
        .opacity(isDisabled ? 0.36 : 1)
        .disabled(isDisabled)
        .accessibilityLabel(title)
    }
}

struct EditorSectionHeading: View {
    let title: String
    var body: some View {
        HStack(spacing: 9) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(2.1)
                .foregroundStyle(PRTheme.muted)
            Rectangle().fill(PRTheme.border).frame(height: 1)
        }
    }
}

struct EditorSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var format: String = "%.2f"
    var displayMultiplier: Double = 1
    var onEditingChanged: (Bool) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(label).font(.system(size: 12)).foregroundStyle(.white.opacity(0.84))
                Spacer()
                Text(String(format: format, value * displayMultiplier))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(PRTheme.muted)
                    .monospacedDigit()
            }
            Slider(value: $value, in: range, onEditingChanged: onEditingChanged)
                .controlSize(.mini)
        }
    }
}

struct EditorChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? Color.white : PRTheme.muted)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(selected ? PRTheme.panelLight : PRTheme.panel, in: RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(selected ? PRTheme.accent.opacity(0.55) : PRTheme.border, lineWidth: 0.8))
        }
        .buttonStyle(.plain)
    }
}

struct BlankWorkspace: View {
    let symbol: String
    let message: String
    let detail: String

    var body: some View {
        VStack(spacing: 13) {
            Image(systemName: symbol)
                .font(.system(size: 39, weight: .ultraLight))
                .foregroundStyle(PRTheme.accent.opacity(0.62))
            Text(message)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.78))
            Text(detail)
                .font(.system(size: 12))
                .foregroundStyle(PRTheme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
