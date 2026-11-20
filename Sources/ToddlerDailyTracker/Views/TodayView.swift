import SwiftData
import SwiftUI

private enum DailyKind: String, CaseIterable, Identifiable {
    case meal = "飲食"
    case sleep = "睡眠"
    case diaper = "排便"
    var id: Self { self }
}

private enum DailyEditor: Identifiable {
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

struct TodayView: View {
    @State private var viewModel: DailyViewModel
    @State private var selected: DailyKind = .meal
    @State private var editor: DailyEditor?

    init(context: ModelContext) {
        _viewModel = State(initialValue: DailyViewModel(repository: DailyRecordRepository(context: context)))
    }

    var body: some View {
        List {
            Picker("紀錄類型", selection: $selected) {
                ForEach(DailyKind.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            switch selected {
            case .meal: meals
            case .sleep: sleeps
            case .diaper: diapers
            }
        }
        .navigationTitle("Toddler Daily Tracker")
        .toolbar {
            Button {
                switch selected {
                case .meal: editor = .meal(nil)
                case .sleep: editor = .sleep(nil)
                case .diaper: editor = .diaper(nil)
                }
            } label: { Image(systemName: "plus") }
        }
        .sheet(item: $editor) { item in editorView(item) }
        .alert("提醒", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) { Button("好") { viewModel.errorMessage = nil } } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .task { viewModel.load() }
    }

    private var meals: some View {
        Section("飲食紀錄") {
            if viewModel.meals.isEmpty { emptyRow("尚無飲食紀錄") }
            ForEach(viewModel.meals) { item in
                Button { editor = .meal(item) } label: {
                    RecordRow(title: "\(item.kind)・\(item.content)", date: item.recordedAt, note: item.note)
                }
            }
            .onDelete { offsets in offsets.forEach { viewModel.delete(viewModel.meals[$0]) } }
        }
    }

    private var sleeps: some View {
        Section("睡眠紀錄") {
            if viewModel.sleeps.isEmpty { emptyRow("尚無睡眠紀錄") }
            ForEach(viewModel.sleeps) { item in
                Button { editor = .sleep(item) } label: {
                    RecordRow(
                        title: "\(item.startedAt.formatted(date: .omitted, time: .shortened))–\(item.endedAt.formatted(date: .omitted, time: .shortened))",
                        date: item.startedAt,
                        note: item.note
                    )
                }
            }
            .onDelete { offsets in offsets.forEach { viewModel.delete(viewModel.sleeps[$0]) } }
        }
    }

    private var diapers: some View {
        Section("排便紀錄") {
            if viewModel.diapers.isEmpty { emptyRow("尚無排便紀錄") }
            ForEach(viewModel.diapers) { item in
                Button { editor = .diaper(item) } label: {
                    RecordRow(title: item.condition, date: item.recordedAt, note: item.note)
                }
            }
            .onDelete { offsets in offsets.forEach { viewModel.delete(viewModel.diapers[$0]) } }
        }
    }

    @ViewBuilder
    private func editorView(_ editor: DailyEditor) -> some View {
        switch editor {
        case .meal(let record):
            MealEditor(record: record) { viewModel.saveMeal($0) }
        case .sleep(let record):
            SleepEditor(record: record) { viewModel.saveSleep($0) }
        case .diaper(let record):
            DiaperEditor(record: record) { viewModel.saveDiaper($0) }
        }
    }

    private func emptyRow(_ text: String) -> some View {
        Text(text).foregroundStyle(.secondary)
    }
}

private struct RecordRow: View {
    let title: String
    let date: Date
    let note: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).foregroundStyle(.primary)
            Text(date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
            if !note.isEmpty { Text(note).font(.caption).foregroundStyle(.secondary) }
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

    init(record: MealRecord?, onSave: @escaping (MealRecord) -> Bool) {
        self.record = record; self.onSave = onSave
        _date = State(initialValue: record?.recordedAt ?? .now)
        _kind = State(initialValue: record?.kind ?? "正餐")
        _content = State(initialValue: record?.content ?? "")
        _note = State(initialValue: record?.note ?? "")
    }
    var body: some View {
        NavigationStack { Form {
            DatePicker("時間", selection: $date)
            Picker("類型", selection: $kind) { ForEach(["正餐", "點心", "奶", "飲水"], id: \.self, content: Text.init) }
            TextField("內容", text: $content)
            TextField("備註", text: $note)
        }.navigationTitle(record == nil ? "新增飲食" : "編輯飲食").toolbar { editorToolbar { save() } } }
    }
    private func save() {
        let value = record ?? MealRecord(recordedAt: date, kind: kind, content: content)
        value.recordedAt = date; value.kind = kind; value.content = content; value.note = note
        if onSave(value) { dismiss() }
    }
    @ToolbarContentBuilder private func editorToolbar(save: @escaping () -> Void) -> some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) { Button("儲存", action: save).disabled(content.trimmingCharacters(in: .whitespaces).isEmpty) }
    }
}

private struct SleepEditor: View {
    @Environment(\.dismiss) private var dismiss
    let record: SleepRecord?
    let onSave: (SleepRecord) -> Bool
    @State private var start: Date
    @State private var end: Date
    @State private var note: String
    init(record: SleepRecord?, onSave: @escaping (SleepRecord) -> Bool) {
        self.record = record; self.onSave = onSave
        _start = State(initialValue: record?.startedAt ?? .now)
        _end = State(initialValue: record?.endedAt ?? .now.addingTimeInterval(3600))
        _note = State(initialValue: record?.note ?? "")
    }
    var body: some View {
        NavigationStack { Form {
            DatePicker("開始", selection: $start)
            DatePicker("結束", selection: $end)
            TextField("備註", text: $note)
        }.navigationTitle(record == nil ? "新增睡眠" : "編輯睡眠").toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("儲存") { save() } }
        } }
    }
    private func save() {
        let value = record ?? SleepRecord(startedAt: start, endedAt: end)
        value.startedAt = start; value.endedAt = end; value.note = note
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
    init(record: DiaperRecord?, onSave: @escaping (DiaperRecord) -> Bool) {
        self.record = record; self.onSave = onSave
        _date = State(initialValue: record?.recordedAt ?? .now)
        _condition = State(initialValue: record?.condition ?? "正常")
        _note = State(initialValue: record?.note ?? "")
    }
    var body: some View {
        NavigationStack { Form {
            DatePicker("時間", selection: $date)
            Picker("狀態", selection: $condition) { ForEach(["正常", "偏硬", "偏稀", "其他"], id: \.self, content: Text.init) }
            TextField("備註", text: $note)
        }.navigationTitle(record == nil ? "新增排便" : "編輯排便").toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("儲存") { save() } }
        } }
    }
    private func save() {
        let value = record ?? DiaperRecord(recordedAt: date, condition: condition)
        value.recordedAt = date; value.condition = condition; value.note = note
        if onSave(value) { dismiss() }
    }
}
