import SwiftData
import SwiftUI

enum DailyEditor: Identifiable {
    case meal(MealRecord?)
    case sleep(SleepRecord?)
    case diaper(DiaperRecord?)

    var id: String {
        switch self {
        case .meal(let value): "meal-\(value?.persistentModelID.hashValue ?? 0)"
        case .sleep(let value): "sleep-\(value?.persistentModelID.hashValue ?? 0)"
        case .diaper(let value): "diaper-\(value?.persistentModelID.hashValue ?? 0)"
        }
    }
}

struct DailyRecordEditorSheet: View {
    let editor: DailyEditor
    let onSaveMeal: (MealRecord) -> Bool
    let onSaveSleep: (SleepRecord) -> Bool
    let onSaveDiaper: (DiaperRecord) -> Bool

    var body: some View {
        switch editor {
        case .meal(let record): MealEditor(record: record, onSave: onSaveMeal)
        case .sleep(let record): SleepEditor(record: record, onSave: onSaveSleep)
        case .diaper(let record): DiaperEditor(record: record, onSave: onSaveDiaper)
        }
    }
}

private struct MealEditor: View {
    @Environment(\.dismiss) private var dismiss
    let record: MealRecord?
    let onSave: (MealRecord) -> Bool
    @State private var date: Date
    @State private var kind: String
    @State private var content: String
    @State private var note: String
    @State private var amountText: String
    @State private var unit: String
    @State private var timeValidationMessage: String?
    @State private var formValidationMessage: String?

    init(record: MealRecord?, onSave: @escaping (MealRecord) -> Bool) {
        self.record = record
        self.onSave = onSave
        _date = State(initialValue: record?.recordedAt ?? TimeInput.roundedToFiveMinutes(.now))
        _kind = State(initialValue: record?.kind ?? "正餐")
        _content = State(initialValue: record?.content ?? "")
        _note = State(initialValue: record?.note ?? "")
        _amountText = State(initialValue: record?.amount.map { String($0) } ?? "")
        _unit = State(initialValue: record?.unit ?? "ml")
        _timeValidationMessage = State(initialValue: nil)
        _formValidationMessage = State(initialValue: nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("時間") {
                    RecordDateTimeInput(date: $date, validationMessage: $timeValidationMessage)
                }
                Picker("類型", selection: $kind) {
                    ForEach(["正餐", "點心", "奶", "飲水"], id: \.self, content: Text.init)
                }
                TextField("內容", text: $content)
                HStack {
                    TextField("份量（可留空）", text: $amountText)
                    Picker("單位", selection: $unit) {
                        ForEach(["ml", "g", "份"], id: \.self, content: Text.init)
                    }
                    .labelsHidden()
                }
                TextField("備註", text: $note)
            }
            .navigationTitle(record == nil ? "新增飲食" : "編輯飲食")
            .toolbar { editorToolbar(save: save, isDisabled: content.trimmingCharacters(in: .whitespaces).isEmpty) }
            .alert("輸入有誤", isPresented: errorPresented) {
                Button("好") { formValidationMessage = nil }
            } message: {
                Text(formValidationMessage ?? "")
            }
        }
    }

    private var errorPresented: Binding<Bool> {
        Binding(get: { formValidationMessage != nil }, set: { if !$0 { formValidationMessage = nil } })
    }

    private func save() {
        guard timeValidationMessage == nil else {
            formValidationMessage = timeValidationMessage
            return
        }
        let input = amountText.trimmingCharacters(in: .whitespacesAndNewlines)
        let amount: Double?
        if input.isEmpty {
            amount = nil
        } else if let parsed = Double(input), parsed.isFinite, parsed > 0 {
            amount = parsed
        } else {
            formValidationMessage = "份量必須是大於 0 的數字。"
            return
        }
        let value = record ?? MealRecord(recordedAt: date, kind: kind, content: content)
        value.recordedAt = date
        value.kind = kind
        value.content = content
        value.note = note
        value.amount = amount
        value.unit = amount == nil ? nil : unit
        if onSave(value) { dismiss() }
    }

    @ToolbarContentBuilder
    private func editorToolbar(save: @escaping () -> Void, isDisabled: Bool) -> some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) { Button("儲存", action: save).disabled(isDisabled) }
    }
}

private struct SleepEditor: View {
    @Environment(\.dismiss) private var dismiss
    let record: SleepRecord?
    let onSave: (SleepRecord) -> Bool
    @State private var start: Date
    @State private var end: Date
    @State private var note: String
    @State private var startValidationMessage: String?
    @State private var endValidationMessage: String?
    @State private var formValidationMessage: String?

    init(record: SleepRecord?, onSave: @escaping (SleepRecord) -> Bool) {
        self.record = record
        self.onSave = onSave
        let defaultStart = TimeInput.roundedToFiveMinutes(.now)
        _start = State(initialValue: record?.startedAt ?? defaultStart)
        _end = State(initialValue: record?.endedAt ?? defaultStart.addingTimeInterval(3600))
        _note = State(initialValue: record?.note ?? "")
        _startValidationMessage = State(initialValue: nil)
        _endValidationMessage = State(initialValue: nil)
        _formValidationMessage = State(initialValue: nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("開始") {
                    RecordDateTimeInput(date: $start, validationMessage: $startValidationMessage)
                }
                Section("結束") {
                    RecordDateTimeInput(date: $end, validationMessage: $endValidationMessage)
                }
                TextField("備註", text: $note)
            }
            .navigationTitle(record == nil ? "新增睡眠" : "編輯睡眠")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("儲存") { save() } }
            }
            .alert("輸入有誤", isPresented: errorPresented) {
                Button("好") { formValidationMessage = nil }
            } message: {
                Text(formValidationMessage ?? "")
            }
        }
    }

    private var errorPresented: Binding<Bool> {
        Binding(get: { formValidationMessage != nil }, set: { if !$0 { formValidationMessage = nil } })
    }

    private func save() {
        guard startValidationMessage == nil, endValidationMessage == nil else {
            formValidationMessage = startValidationMessage ?? endValidationMessage
            return
        }
        let value = record ?? SleepRecord(startedAt: start, endedAt: end)
        value.startedAt = start
        value.endedAt = end
        value.note = note
        if onSave(value) { dismiss() }
    }
}

private struct DiaperEditor: View {
    @Environment(\.dismiss) private var dismiss
    let record: DiaperRecord?
    let onSave: (DiaperRecord) -> Bool
    @State private var date: Date
    @State private var condition: String
    @State private var note: String
    @State private var timeValidationMessage: String?
    @State private var formValidationMessage: String?

    init(record: DiaperRecord?, onSave: @escaping (DiaperRecord) -> Bool) {
        self.record = record
        self.onSave = onSave
        _date = State(initialValue: record?.recordedAt ?? TimeInput.roundedToFiveMinutes(.now))
        _condition = State(initialValue: record?.condition ?? "正常")
        _note = State(initialValue: record?.note ?? "")
        _timeValidationMessage = State(initialValue: nil)
        _formValidationMessage = State(initialValue: nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("時間") {
                    RecordDateTimeInput(date: $date, validationMessage: $timeValidationMessage)
                }
                Picker("狀態", selection: $condition) {
                    ForEach(["正常", "偏硬", "偏稀", "其他"], id: \.self, content: Text.init)
                }
                TextField("備註", text: $note)
            }
            .navigationTitle(record == nil ? "新增排便" : "編輯排便")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("儲存") { save() } }
            }
            .alert("輸入有誤", isPresented: errorPresented) {
                Button("好") { formValidationMessage = nil }
            } message: {
                Text(formValidationMessage ?? "")
            }
        }
    }

    private var errorPresented: Binding<Bool> {
        Binding(get: { formValidationMessage != nil }, set: { if !$0 { formValidationMessage = nil } })
    }

    private func save() {
        guard timeValidationMessage == nil else {
            formValidationMessage = timeValidationMessage
            return
        }
        let value = record ?? DiaperRecord(recordedAt: date, condition: condition)
        value.recordedAt = date
        value.condition = condition
        value.note = note
        if onSave(value) { dismiss() }
    }
}
