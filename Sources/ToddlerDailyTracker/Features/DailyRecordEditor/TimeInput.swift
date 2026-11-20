import Foundation
import SwiftUI

enum TimeInput {
    static func roundedToFiveMinutes(_ date: Date, calendar: Calendar = .current) -> Date {
        guard let hour = calendar.dateInterval(of: .hour, for: date)?.start else { return date }
        let minute = calendar.component(.minute, from: date)
        let roundedMinute = Int((Double(minute) / 5).rounded()) * 5
        return calendar.date(byAdding: .minute, value: roundedMinute, to: hour) ?? date
    }

    static func parseExact(
        _ text: String,
        on date: Date,
        calendar: Calendar = .current
    ) -> Date? {
        guard text.count == 5, text[text.index(text.startIndex, offsetBy: 2)] == ":" else { return nil }
        let parts = text.split(separator: ":", omittingEmptySubsequences: false)
        guard
            parts.count == 2,
            parts[0].count == 2,
            parts[1].count == 2,
            let hour = Int(parts[0]),
            let minute = Int(parts[1]),
            (0...23).contains(hour),
            (0...59).contains(minute),
            let result = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date)
        else { return nil }
        let resultParts = calendar.dateComponents([.hour, .minute], from: result)
        guard resultParts.hour == hour, resultParts.minute == minute else { return nil }
        return result
    }
}

struct RecordDateTimeInput: View {
    @Binding var date: Date
    @Binding var validationMessage: String?
    @State private var usesExactTime = false
    @State private var exactText: String

    init(date: Binding<Date>, validationMessage: Binding<String?>) {
        _date = date
        _validationMessage = validationMessage
        _exactText = State(initialValue: Self.timeText(date.wrappedValue))
    }

    var body: some View {
        DatePicker("日期", selection: $date, displayedComponents: .date)
        Toggle("精確時間", isOn: $usesExactTime)
            .onChange(of: usesExactTime) { _, enabled in
                validationMessage = nil
                if enabled {
                    exactText = Self.timeText(date)
                } else {
                    date = TimeInput.roundedToFiveMinutes(date)
                }
            }
        if usesExactTime {
            TextField("HH:mm", text: $exactText)
                .onChange(of: exactText) { _, text in
                    guard let parsed = TimeInput.parseExact(text, on: date) else {
                        validationMessage = "請輸入有效的 24 小時時間，例如 09:17。"
                        return
                    }
                    date = parsed
                    validationMessage = nil
                }
        } else {
            HStack {
                Picker("時", selection: hourBinding) {
                    ForEach(0..<24, id: \.self) { Text(String(format: "%02d 時", $0)) }
                }
                Picker("分", selection: minuteBinding) {
                    ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) {
                        Text(String(format: "%02d 分", $0))
                    }
                }
            }
        }
    }

    private var hourBinding: Binding<Int> {
        Binding(
            get: { Calendar.current.component(.hour, from: date) },
            set: { update(hour: $0, minute: Calendar.current.component(.minute, from: date)) }
        )
    }

    private var minuteBinding: Binding<Int> {
        Binding(
            get: { Calendar.current.component(.minute, from: date) },
            set: { update(hour: Calendar.current.component(.hour, from: date), minute: $0) }
        )
    }

    private func update(hour: Int, minute: Int) {
        if let value = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: date) {
            date = value
        }
    }

    private static func timeText(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    }
}
