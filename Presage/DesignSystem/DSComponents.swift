import SwiftUI

// MARK: - PariButton

enum PariButtonStyle {
    case primary
    case secondary
    case ghost
    case coral   // signature secondary CTA — the coral pill
}

struct PariButton: View {
    let title: String
    let style: PariButtonStyle
    let icon: String?
    let iconColor: Color?
    let action: () -> Void

    @State private var isPressed = false
    /// Drops repeated taps that arrive within the debounce window.
    /// Without this, a user double-tapping "Save prediction" before the
    /// modal dismisses fires `engine.createPrediction` twice and creates
    /// two identical rows. Cleared after the window so legitimate
    /// re-taps (e.g. after an error alert) still go through.
    @State private var lastFireDate: Date = .distantPast
    private static let debounceInterval: TimeInterval = 0.6

    init(
        _ title: String,
        style: PariButtonStyle = .primary,
        icon: String? = nil,
        iconColor: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.icon = icon
        self.iconColor = iconColor
        self.action = action
    }

    private func debouncedAction() {
        let now = Date()
        guard now.timeIntervalSince(lastFireDate) >= Self.debounceInterval else { return }
        lastFireDate = now
        action()
    }

    var body: some View {
        Button(action: debouncedAction) {
            HStack(spacing: DS.Space.sm) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(iconColor ?? foregroundColor)
                }
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(height: style == .ghost ? 44 : 56)
            .background(background, in: Capsule(style: .continuous))
            .scaleEffect(isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: DS.Palette.darkSurfacePrimary
        case .secondary: DS.Palette.textPrimary
        case .ghost: DS.Palette.textSecondary
        case .coral: DS.Palette.darkSurfacePrimary
        }
    }

    private var background: AnyShapeStyle {
        switch style {
        case .primary:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [DS.Palette.accent, DS.Palette.accent.opacity(0.88)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        case .secondary:
            return AnyShapeStyle(DS.Palette.surfaceTertiary)
        case .ghost:
            return AnyShapeStyle(Color.clear)
        case .coral:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [DS.Palette.accentSecondary, DS.Palette.accentSecondary.opacity(0.88)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
}

// MARK: - PariCard — refined, generous corner radii, subtle inner gradient

struct PariCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = 20

    init(padding: CGFloat = 20, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .pariSurface()
    }
}

// MARK: - PariChip — capsule pill, vivid when selected (reference style)

struct PariChip: View {
    let label: String
    let isSelected: Bool
    var tint: Color = DS.Palette.accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? DS.Palette.darkSurfacePrimary : DS.Palette.textSecondary)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                // minHeight rather than fixed height so the chip can grow
                // vertically at accessibility text sizes — fixed height
                // clipped descenders at AX1+ and clipped the entire label
                // at AX3+.
                .frame(minHeight: 32)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? AnyShapeStyle(tint) : AnyShapeStyle(DS.Palette.surfaceTertiary))
                )
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - PariInput

struct PariInput: View {
    let placeholder: String
    @Binding var text: String
    var isMultiline: Bool = false
    var isFocused: FocusState<Bool>.Binding?

    var body: some View {
        Group {
            if isMultiline {
                TextField(placeholder, text: $text, axis: .vertical)
                    .lineLimit(3...6)
            } else {
                TextField(placeholder, text: $text)
            }
        }
        .font(DS.Typo.body)
        .foregroundStyle(DS.Palette.textPrimary)
        .padding(.horizontal, DS.Space.base)
        .padding(.vertical, DS.Space.md)
        .frame(minHeight: isMultiline ? 96 : 52)
        .background(DS.Palette.surfaceTertiary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - PariDivider

struct PariDivider: View {
    var inset: Bool = false

    var body: some View {
        Rectangle()
            .fill(DS.Palette.separator)
            .frame(height: 1)
            .padding(.horizontal, inset ? DS.Space.base : 0)
    }
}

// MARK: - Stat Tile — large number + tiny whisper label (reference style)

struct PariStatTile: View {
    let label: String
    let value: String
    let detail: String?
    var coralAccent: Bool = false

    init(_ label: String, value: String, detail: String? = nil, coralAccent: Bool = false) {
        self.label = label
        self.value = value
        self.detail = detail
        self.coralAccent = coralAccent
    }

    var body: some View {
        PariCard(padding: 16) {
            VStack(alignment: .leading, spacing: 8) {
                WhisperLabel(text: label)

                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(coralAccent ? DS.Palette.accentSecondary : DS.Palette.textPrimary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                if let detail {
                    Text(detail)
                        .font(DS.Typo.caption)
                        .foregroundStyle(DS.Palette.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Confidence Pill — the badge on each prediction card

struct ConfidencePill: View {
    let percent: Int

    var body: some View {
        HStack(spacing: 4) {
            PariAim(size: 9, filled: true, tint: tintColor)
            Text("\(percent)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text("%")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DS.Palette.accentSecondary)
        }
        .foregroundStyle(tintColor)
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(
            Capsule(style: .continuous)
                .fill(DS.Palette.accentMuted)
        )
    }

    private var tintColor: Color {
        switch percent {
        case 95...99: return DS.Palette.accentSecondary
        case 80...94: return DS.Palette.accent
        default: return DS.Palette.textSecondary
        }
    }
}

// MARK: - Category Badge — minimal, single-tone

struct CategoryBadge: View {
    let category: PredictionCategory

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: category.sfSymbol)
                .font(.system(size: 10, weight: .medium))
            Text(category.displayName.uppercased())
                .font(.system(size: 10, weight: .medium))
                .kerning(1.2)
        }
        .foregroundStyle(DS.Palette.textTertiary)
    }
}

// MARK: - Empty State

struct PariEmptyState: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(DS.Palette.accentMuted)
                    .frame(width: 72, height: 72)
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(DS.Palette.accent)
            }

            VStack(spacing: 8) {
                Text(title)
                    .font(DS.Typo.titleMedium)
                    .foregroundStyle(DS.Palette.textPrimary)
                Text(message)
                    .font(DS.Typo.callout)
                    .foregroundStyle(DS.Palette.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle, let action {
                PariButton(actionTitle, action: action)
                    .padding(.top, DS.Space.sm)
                    .padding(.horizontal, 32)
            }
        }
        .padding(40)
    }
}

// MARK: - FAB — coral, signature shape, ambient glow

struct FloatingActionButton: View {
    let action: () -> Void
    var longPressAction: (() -> Void)? = nil
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                // Ambient glow
                Circle()
                    .fill(DS.Palette.accentSecondary.opacity(0.45))
                    .frame(width: 72, height: 72)
                    .blur(radius: 16)

                // Body
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                DS.Palette.accentSecondary,
                                DS.Palette.accentSecondary.opacity(0.85)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
                    )

                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(DS.Palette.darkSurfacePrimary)
            }
            .shadow(color: DS.Palette.accentSecondary.opacity(0.4), radius: 14, x: 0, y: 6)
            .scaleEffect(isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("New prediction")
        .accessibilityHint("Tap for full form, long-press for quick predict")
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.4)
                .onEnded { _ in
                    if let lp = longPressAction {
                        HapticEngine.shared.resolutionReveal()
                        lp()
                    }
                }
        )
    }
}
