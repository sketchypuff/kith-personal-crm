import SwiftUI

/// Day · Month · Year wheels, with a "----" year for dates whose year is
/// unknown — the same shape as the birthday picker in Contacts. Column order
/// follows the locale's day/month convention.
struct KeyDateWheelPicker: View {
    @Binding var draft: KeyDateDraft

    // Day and year are short; the month column gets whatever width is left
    // so full month names don't truncate.
    @ScaledMetric(relativeTo: .title2) private var dayWidth = 72.0
    @ScaledMetric(relativeTo: .title2) private var yearWidth = 108.0

    private let calendar = Calendar.current

    private var monthSymbols: [String] { calendar.monthSymbols }

    private var dayRange: ClosedRange<Int> {
        1...KeyDateDraft.daysIn(month: draft.month, year: draft.year, calendar: calendar)
    }

    /// Ascending years up to next year, then the no-year row at the bottom.
    private var yearOptions: [Int?] {
        let thisYear = calendar.component(.year, from: .now)
        return Array(1900...(thisYear + 1)).map(Optional.some) + [nil]
    }

    var body: some View {
        HStack(spacing: 0) {
            if Self.monthPrecedesDay {
                monthWheel
                dayWheel
            } else {
                dayWheel
                monthWheel
            }
            yearWheel
        }
        .onChange(of: draft.month) { clampDay() }
        .onChange(of: draft.year) { clampDay() }
    }

    private var dayWheel: some View {
        Picker("Day", selection: $draft.day) {
            ForEach(dayRange, id: \.self) { day in
                Text(day, format: .number).tag(day)
            }
        }
        .pickerStyle(.wheel)
        .labelsHidden()
        .frame(width: dayWidth)
        .clipped()
    }

    private var monthWheel: some View {
        Picker("Month", selection: $draft.month) {
            ForEach(1...12, id: \.self) { month in
                Text(monthSymbols[month - 1]).tag(month)
            }
        }
        .pickerStyle(.wheel)
        .labelsHidden()
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private var yearWheel: some View {
        Picker("Year", selection: $draft.year) {
            ForEach(yearOptions, id: \.self) { year in
                if let year {
                    Text(year, format: .number.grouping(.never)).tag(Optional(year))
                } else {
                    Text("----").tag(Optional<Int>.none)
                }
            }
        }
        .pickerStyle(.wheel)
        .labelsHidden()
        .frame(width: yearWidth)
        .clipped()
        .accessibilityHint("Choose ---- if the year is unknown")
    }

    private func clampDay() {
        draft.clampDay(calendar: calendar)
    }

    /// True for locales that write the month before the day (e.g. en_US).
    private static var monthPrecedesDay: Bool {
        let template = DateFormatter.dateFormat(fromTemplate: "dMMMM", options: 0, locale: .current) ?? "d MMMM"
        guard let d = template.firstIndex(of: "d"), let m = template.firstIndex(of: "M") else { return false }
        return m < d
    }
}

#Preview {
    @Previewable @State var draft = KeyDateDraft(type: .birthday, month: 9, day: 9)
    Form {
        KeyDateWheelPicker(draft: $draft)
    }
}
