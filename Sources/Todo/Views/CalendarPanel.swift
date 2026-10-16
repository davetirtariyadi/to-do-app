import SwiftUI
import TodoCore

/// Month grid shown over the Add screen. Keyboard input is handled by the
/// Date button (focus never leaves it); this view only draws and takes clicks.
struct CalendarPanel: View {
    let cursor: String
    let selected: String?
    let today: String
    let pick: (String?) -> Void
    let shiftMonth: (Int) -> Void

    private let weekdays = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        let month = DayKey.parts(cursor).month
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 2) {
                Text(DayKey.monthTitle(cursor))
                    .font(.system(size: 13.5, weight: .semibold))
                    .padding(.leading, 4)
                Spacer()
                monthButton("chevron.left", label: "Previous month") { shiftMonth(-1) }
                monthButton("chevron.right", label: "Next month") { shiftMonth(1) }
            }
            .frame(height: 26)

            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    Text(weekdays[i]).frame(maxWidth: .infinity)
                }
            }
            .font(.system(size: 10.5, weight: .medium))
            .foregroundStyle(Theme.muted)
            .frame(height: 14)

            VStack(spacing: 0) {
                ForEach(DayKey.monthGrid(for: cursor), id: \.self) { week in
                    HStack(spacing: 0) {
                        ForEach(week, id: \.self) { day in
                            dayCell(day, inMonth: DayKey.parts(day).month == month)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 24)
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                chip("Today", today)
                chip("Tomorrow", DayKey.addDays(today, 1))
                chip("This weekend", DayKey.thisWeekend(from: today))
                chip("Next Mon", DayKey.nextMonday(after: today))
                chip("Clear", nil)
            }
            HintText(text: "←→↑↓ day · PgUp/Dn month · T today · ⌫ clear · ⏎ pick")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.surface)
                .shadow(color: .black.opacity(0.16), radius: 14, y: 8)
        )
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.stroke))
    }

    private func dayCell(_ day: String, inMonth: Bool) -> some View {
        let isSelected = day == selected
        let isCursor = day == cursor
        let isToday = day == today
        let color: Color = isSelected ? Theme.onAccent
            : !inMonth ? Theme.dim
            : day < today ? Theme.faint
            : Theme.ink
        return Button { pick(day) } label: {
            Text("\(DayKey.parts(day).day)")
                .font(.system(size: 12, weight: isToday ? .bold : .regular))
                .underline(isToday && !isSelected)
                .foregroundStyle(color)
                .frame(width: 32, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Theme.accent : isCursor ? Theme.accentSoft : .clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isCursor ? Theme.accent : .clear, lineWidth: 1.5)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(DayKey.pickerLabel(day, today: today))
    }

    private func monthButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.ink2)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func chip(_ title: String, _ value: String?) -> some View {
        Button { pick(value) } label: {
            Text(title)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.ink2)
                .padding(.horizontal, 8)
                .frame(height: 24)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
