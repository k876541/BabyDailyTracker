import SwiftData
import SwiftUI

private enum DailyKind: String, CaseIterable, Identifiable {
    case meal = "飲食"
    case sleep = "睡眠"
    case diaper = "排便"
    var id: Self { self }
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
        DailyRecordEditorSheet(
            editor: editor,
            onSaveMeal: viewModel.saveMeal,
            onSaveSleep: viewModel.saveSleep,
            onSaveDiaper: viewModel.saveDiaper
        )
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
