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
            Section {
                welcomeCard
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                quickActions
                    .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 4, trailing: 0))
                    .listRowBackground(Color.clear)
            }

            Section("今日時間軸") {
                if viewModel.timeline.isEmpty { emptyRow("今天還沒有紀錄") }
                ForEach(viewModel.timeline) { item in
                    Button { edit(item) } label: { TimelineRow(item: item) }
                }
                .onDelete(perform: deleteTimelineItems)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.primary.opacity(0.04))
        .navigationTitle("今天")
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

    private var welcomeCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(.white.opacity(0.82)).frame(width: 58, height: 58)
                Image(systemName: "figure.child").font(.system(size: 28, weight: .semibold)).foregroundStyle(BabyTheme.primary)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).month().day()))
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text("今天也一起照顧寶寶")
                    .font(.title3.bold()).foregroundStyle(.primary)
                Text(todaySummary).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(18)
        .background(
            LinearGradient(colors: [BabyTheme.peach, BabyTheme.lavender.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
    }

    private var todaySummary: String {
        let calendar = Calendar.current
        let meals = viewModel.meals.filter { calendar.isDateInToday($0.recordedAt) }.count
        let sleeps = viewModel.sleeps.filter { calendar.isDateInToday($0.startedAt) }.count
        let diapers = viewModel.diapers.filter { calendar.isDateInToday($0.recordedAt) }.count
        return "飲食 \(meals)・睡眠 \(sleeps)・排便 \(diapers)"
    }

    private var quickActions: some View {
        HStack(spacing: 10) {
            quickAction(.meal, icon: "fork.knife", color: BabyTheme.peach)
            quickAction(.sleep, icon: "moon.stars.fill", color: BabyTheme.lavender)
            quickAction(.diaper, icon: "drop.fill", color: BabyTheme.mint)
        }
    }

    private func quickAction(_ kind: DailyKind, icon: String, color: Color) -> some View {
        Button {
            selected = kind
            switch kind {
            case .meal: editor = .meal(nil)
            case .sleep:
                if viewModel.activeSleep == nil { _ = viewModel.startSleep() }
                else { _ = viewModel.finishActiveSleep() }
            case .diaper: editor = .diaper(nil)
            }
        } label: {
            VStack(spacing: 9) {
                Image(systemName: icon).font(.title3).foregroundStyle(selected == kind ? .white : .primary)
                Text(kind == .sleep && viewModel.activeSleep != nil ? "醒來" : kind.rawValue)
                    .font(.caption.weight(.semibold)).foregroundStyle(selected == kind ? .white : .primary)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(selected == kind ? BabyTheme.primary : color, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("新增\(kind.rawValue)紀錄")
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
                        title: sleepTitle(item),
                        date: item.startedAt,
                        note: item.note
                    )
                }
            }
            .onDelete { offsets in offsets.forEach { viewModel.delete(viewModel.sleeps[$0]) } }
        }
    }

    private func sleepTitle(_ item: SleepRecord) -> String {
        let start = item.startedAt.formatted(date: .omitted, time: .shortened)
        guard let end = item.endedAt else { return "\(start)–睡眠中" }
        return "\(start)–\(end.formatted(date: .omitted, time: .shortened))"
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

    private func edit(_ item: DailyTimelineItem) {
        switch item.kind {
        case .meal: editor = viewModel.meals.first { $0.recordedAt == item.eventDate }.map(DailyEditor.meal)
        case .sleep: editor = viewModel.sleeps.first { $0.startedAt == item.eventDate }.map(DailyEditor.sleep)
        case .diaper: editor = viewModel.diapers.first { $0.recordedAt == item.eventDate }.map(DailyEditor.diaper)
        }
    }

    private func deleteTimelineItems(at offsets: IndexSet) {
        let items = viewModel.timeline
        for offset in offsets {
            let item = items[offset]
            switch item.kind {
            case .meal:
                if let record = viewModel.meals.first(where: { $0.recordedAt == item.eventDate }) { viewModel.delete(record) }
            case .sleep:
                if let record = viewModel.sleeps.first(where: { $0.startedAt == item.eventDate }) { viewModel.delete(record) }
            case .diaper:
                if let record = viewModel.diapers.first(where: { $0.recordedAt == item.eventDate }) { viewModel.delete(record) }
            }
        }
    }
}

private struct TimelineRow: View {
    let item: DailyTimelineItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).frame(width: 30, height: 30).background(color.opacity(0.18), in: Circle()).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title).font(.body.weight(.medium))
                Text(item.eventDate.formatted(date: .omitted, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                if !item.detail.isEmpty { Text(item.detail).font(.caption).foregroundStyle(.secondary) }
            }
        }
        .padding(.vertical, 3)
    }

    private var icon: String {
        switch item.kind { case .meal: "fork.knife"; case .sleep: "moon.stars.fill"; case .diaper: "drop.fill" }
    }

    private var color: Color {
        switch item.kind { case .meal: BabyTheme.primary; case .sleep: .purple; case .diaper: .green }
    }
}

private struct RecordRow: View {
    let title: String
    let date: Date
    let note: String
    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(BabyTheme.primary.opacity(0.13)).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.body.weight(.medium)).foregroundStyle(.primary)
            Text(date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
            if !note.isEmpty { Text(note).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
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
    @State private var validationMessage: String?

    init(record: MealRecord?, onSave: @escaping (MealRecord) -> Bool) {
        self.record = record; self.onSave = onSave
        _date = State(initialValue: record?.recordedAt ?? .now)
        _kind = State(initialValue: record?.kind ?? "正餐")
        _content = State(initialValue: record?.content ?? "")
        _note = State(initialValue: record?.note ?? "")
        _amountText = State(initialValue: record?.amount.map { String($0) } ?? "")
        _unit = State(initialValue: record?.unit ?? "ml")
        _validationMessage = State(initialValue: nil)
    }
    var body: some View {
        NavigationStack { Form {
            DatePicker("時間", selection: $date)
            Picker("類型", selection: $kind) { ForEach(["正餐", "點心", "奶", "飲水"], id: \.self, content: Text.init) }
            TextField("內容", text: $content)
            HStack {
                TextField("份量（可留空）", text: $amountText)
                Picker("單位", selection: $unit) { ForEach(["ml", "g", "份"], id: \.self, content: Text.init) }.labelsHidden()
            }
            TextField("備註", text: $note)
        }
        .navigationTitle(record == nil ? "新增飲食" : "編輯飲食")
        .toolbar { editorToolbar { save() } }
        .alert("輸入有誤", isPresented: Binding(
            get: { validationMessage != nil },
            set: { if !$0 { validationMessage = nil } }
        )) { Button("好") { validationMessage = nil } } message: { Text(validationMessage ?? "") }
        }
    }
    private func save() {
        let input = amountText.trimmingCharacters(in: .whitespacesAndNewlines)
        let amount: Double?
        if input.isEmpty {
            amount = nil
        } else if let parsed = Double(input), parsed.isFinite, parsed > 0 {
            amount = parsed
        } else {
            validationMessage = "份量必須是大於 0 的數字。"
            return
        }
        let value = record ?? MealRecord(recordedAt: date, kind: kind, content: content)
        value.recordedAt = date; value.kind = kind; value.content = content; value.note = note
        value.amount = amount; value.unit = amount == nil ? nil : unit
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
