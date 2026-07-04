import SwiftUI

/// Colored status dot + label, Docker Desktop style.
struct StatusBadge: View {
    let state: ContainerState

    var color: Color {
        switch state {
        case .running: return .green
        case .stopped: return .secondary.opacity(0.6)
        case .stopping, .creating, .created: return .orange
        case .paused: return .yellow
        case .unknown: return .gray
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(state.displayName)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }
}

/// Centered placeholder for empty lists.
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.title3.weight(.semibold))
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

/// Dismissible red error banner shown at the top of the content area.
struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.white)
            Text(message)
                .font(.callout)
                .foregroundStyle(.white)
                .lineLimit(3)
                .textSelection(.enabled)
            Spacer()
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.red.opacity(0.88), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

/// Small circular icon button used in table rows.
struct RowActionButton: View {
    let systemImage: String
    let help: String
    var tint: Color = .primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(.quaternary.opacity(0.5), in: Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

/// Left-aligned wrapping layout for variable-width chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        let width = maxWidth.isFinite ? maxWidth : max(0, x - spacing)
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// Self-updating "4 min ago" text — SwiftUI's .relative style ticks every second.
struct RelativeTimeText: View {
    let iso: String?

    var body: some View {
        if let date = Formatters.date(fromISO: iso) {
            Text("\(Text(date, style: .relative)) ago")
        } else {
            Text("—")
        }
    }
}

/// Key/value row used in detail info grids.
struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        GridRow {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.trailing)
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
                .gridColumnAlignment(.leading)
        }
    }
}

/// InfoRow variant whose value is a live-updating relative timestamp.
struct InfoDateRow: View {
    let label: String
    let iso: String?

    var body: some View {
        GridRow {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.trailing)
            RelativeTimeText(iso: iso)
                .font(.system(size: 12, design: .monospaced))
                .gridColumnAlignment(.leading)
        }
    }
}
