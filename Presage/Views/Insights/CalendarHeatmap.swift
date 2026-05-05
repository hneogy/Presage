import SwiftUI

/// Year-in-Pixels view (Daylio's signature, repurposed for calibration).
/// Each day is a colored cell — hue = accuracy, intensity = volume.
struct CalendarHeatmap: View {
    let predictions: [Prediction]
    let endDate: Date

    init(predictions: [Prediction], endDate: Date = .now) {
        self.predictions = predictions
        self.endDate = endDate
    }

    private struct DayCell: Identifiable {
        let id: Date
        let date: Date
        let resolvedCount: Int
        let avgBrier: Double?
    }

    private var cells: [DayCell] {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -364, to: endDate) ?? endDate
        let grouped = Dictionary(grouping: predictions.compactMap { p -> (Date, Prediction)? in
            guard let resolved = p.resolvedAt else { return nil }
            return (cal.startOfDay(for: resolved), p)
        }) { $0.0 }
            .mapValues { $0.map(\.1) }

        var result: [DayCell] = []
        var cursor = cal.startOfDay(for: start)
        while cursor <= cal.startOfDay(for: endDate) {
            let day = grouped[cursor] ?? []
            let count = day.count
            let brier = ScoringEngine.aggregateBrier(day)
            result.append(DayCell(id: cursor, date: cursor, resolvedCount: count, avgBrier: brier))
            cursor = cal.date(byAdding: .day, value: 1, to: cursor) ?? cursor
        }
        return result
    }

    var body: some View {
        GeometryReader { geo in
            let columns = 53  // ~52 weeks
            let rows = 7
            let spacing: CGFloat = 3
            let totalSpacing = spacing * CGFloat(columns - 1)
            let cellSize = max(6, (geo.size.width - totalSpacing) / CGFloat(columns))

            VStack(spacing: 8) {
                LazyHGrid(rows: Array(repeating: GridItem(.fixed(cellSize), spacing: spacing), count: rows), spacing: spacing) {
                    ForEach(cells) { cell in
                        cellView(cell, size: cellSize)
                    }
                }
                .frame(height: cellSize * CGFloat(rows) + spacing * CGFloat(rows - 1))

                legend
            }
        }
        .frame(height: 100)
    }

    private func cellView(_ cell: DayCell, size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(color(for: cell))
            .frame(width: size, height: size)
            .accessibilityLabel(label(for: cell))
    }

    private func color(for cell: DayCell) -> Color {
        guard cell.resolvedCount > 0, let brier = cell.avgBrier else {
            return DS.Palette.surfaceTertiary.opacity(0.4)
        }
        // Lower brier (better) → teal; higher brier (worse) → coral
        let intensity = min(1.0, Double(cell.resolvedCount) / 4.0)
        if brier < 0.15 {
            return DS.Palette.accent.opacity(0.3 + 0.7 * intensity)
        } else if brier < 0.25 {
            return DS.Palette.textSecondary.opacity(0.3 + 0.5 * intensity)
        } else {
            return DS.Palette.accentSecondary.opacity(0.3 + 0.7 * intensity)
        }
    }

    private func label(for cell: DayCell) -> String {
        let formatter = DateFormatter(); formatter.dateStyle = .medium
        let dateStr = formatter.string(from: cell.date)
        if cell.resolvedCount == 0 { return "\(dateStr): no predictions" }
        let brierStr = cell.avgBrier.map { PariFormat.brier($0) } ?? "—"
        return "\(dateStr): \(cell.resolvedCount) resolved, Brier \(brierStr)"
    }

    private var legend: some View {
        // 10×10 swatches are below the 44×44 touch-target minimum, but
        // these are decorative-only — the legend never becomes
        // tappable. If a future revision adds tap-to-filter behaviour
        // here, swap to PariChip-sized hit targets so the touch targets
        // grow back to 32+pt.
        HStack(spacing: 6) {
            Text("Less")
                .font(.system(size: 10))
                .foregroundStyle(DS.Palette.textTertiary)
            Rectangle().fill(DS.Palette.surfaceTertiary).frame(width: 10, height: 10).cornerRadius(2)
                .accessibilityHidden(true)
            Rectangle().fill(DS.Palette.accent.opacity(0.5)).frame(width: 10, height: 10).cornerRadius(2)
                .accessibilityHidden(true)
            Rectangle().fill(DS.Palette.accent).frame(width: 10, height: 10).cornerRadius(2)
                .accessibilityHidden(true)
            Rectangle().fill(DS.Palette.accentSecondary).frame(width: 10, height: 10).cornerRadius(2)
                .accessibilityHidden(true)
            Text("More / worse")
                .font(.system(size: 10))
                .foregroundStyle(DS.Palette.textTertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Legend: less to more, or worse")
    }
}
