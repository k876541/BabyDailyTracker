import SwiftData
import SwiftUI

struct HistoryView: View {
    @State private var viewModel: HistoryViewModel
    @State private var editor: DailyEditor?
    @State private var showsCalendar = false

    init(context: ModelContext) {
        _viewModel = State(initialValue: HistoryViewModel(repository: DailyRecordRepository(context: context)))
    }

    var body: some View {
        List {
            Section {
                dateNavigation
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                dailySummaryCard
                    .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 4, trailing: 0))
                    .listRowBackground(Color.clear)
                weeklySummaryCard
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 4, trailing: 0))
                    .listRowBackground(Color.clear)
            }

            Section("當日時間軸") {
                if viewModel.timeline.isEmpty {
                    ContentUnavailableView("這天沒有紀錄", systemImage: "calendar.badge.clock")
                } else {
                    ForEach(viewModel.timeline) { item in
                        Button { edit(item) } label: { HistoryTimelineRow(item: item) }
                    }
                    .onDelete(perform: deleteTimelineItems)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.primary.opacity(0.04))
        .navigationTitle("歷史")
        .sheet(isPresented: $showsCalendar) { calendarSheet }
        .sheet(item: $editor) { item in
            DailyRecordEditorSheet(
                editor: item,
                onSaveMeal: viewModel.saveMeal,
                onSaveSleep: viewModel.saveSleep,
                onSaveDiaper: viewModel.saveDiaper
            )
        }
        .alert("提醒", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("好") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .task { viewModel.load() }
    }

    private var dateNavigation: some View {
        HStack(spacing: 12) {
            Button { viewModel.selectPreviousDay() } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 42, height: 42)
                    .background(BabyTheme.sky, in: Circle())
            }
            Spacer()
            Button { showsCalendar = true } label: {
                VStack(spacing: 3) {
                    Text(viewModel.selectedDate.formatted(.dateTime.year().month().day()))
                        .font(.headline)
                    Text(viewModel.selectedDate.formatted(.dateTime.weekday(.wide)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            Spacer()
            Button { viewModel.selectNextDay() } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 42, height: 42)
                    .background(BabyTheme.sky, in: Circle())
            }
            .disabled(!viewModel.canSelectNextDay)
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var dailySummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("當日摘要").font(.headline)
            HStack(spacing: 8) {
                metric(title: "飲食", value: "\(viewModel.dailySummary.mealCount) 次", color: BabyTheme.peach)
                metric(title: "睡眠", value: duration(viewModel.dailySummary.sleepDuration), color: BabyTheme.lavender)
                metric(title: "排便", value: "\(viewModel.dailySummary.diaperCount) 次", color: BabyTheme.mint)
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var weeklySummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("近七日").font(.headline)
            Text("飲食 \(viewModel.weeklySummary.mealCount) 次・排便 \(viewModel.weeklySummary.diaperCount) 次")
            Text("睡眠 \(duration(viewModel.weeklySummary.sleepDuration))・有紀錄 \(viewModel.weeklySummary.recordedDayCount) 天")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(BabyTheme.sky.opacity(0.7), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func metric(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 5) {
            Text(value).font(.headline)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.7), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var calendarSheet: some View {
        NavigationStack {
            DatePicker(
                "選擇日期",
                selection: Binding(get: { viewModel.selectedDate }, set: { viewModel.select($0) }),
                in: ...Date.now,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding()
            .navigationTitle("選擇日期")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { showsCalendar = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        let hours = minutes / 60
        let remainder = minutes % 60
        return hours > 0 ? "\(hours) 小時 \(remainder) 分" : "\(remainder) 分"
    }

    private func edit(_ item: DailyTimelineItem) {
        switch item.id {
        case .meal(let id): editor = viewModel.meals.first { $0.persistentModelID == id }.map(DailyEditor.meal)
        case .sleep(let id): editor = viewModel.sleeps.first { $0.persistentModelID == id }.map(DailyEditor.sleep)
        case .diaper(let id): editor = viewModel.diapers.first { $0.persistentModelID == id }.map(DailyEditor.diaper)
        }
    }

    private func deleteTimelineItems(at offsets: IndexSet) {
        let items = viewModel.timeline
        for offset in offsets {
            switch items[offset].id {
            case .meal(let id):
                if let record = viewModel.meals.first(where: { $0.persistentModelID == id }) { viewModel.delete(record) }
            case .sleep(let id):
                if let record = viewModel.sleeps.first(where: { $0.persistentModelID == id }) { viewModel.delete(record) }
            case .diaper(let id):
                if let record = viewModel.diapers.first(where: { $0.persistentModelID == id }) { viewModel.delete(record) }
            }
        }
    }
}

private struct HistoryTimelineRow: View {
    let item: DailyTimelineItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.18), in: Circle())
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title).font(.body.weight(.medium)).foregroundStyle(.primary)
                Text(item.eventDate.formatted(date: .omitted, time: .shortened))
                    .font(.caption).foregroundStyle(.secondary)
                if !item.detail.isEmpty {
                    Text(item.detail).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 3)
    }

    private var icon: String {
        switch item.kind {
        case .meal: "fork.knife"
        case .sleep: "moon.stars.fill"
        case .diaper: "drop.fill"
        }
    }

    private var color: Color {
        switch item.kind {
        case .meal: BabyTheme.primary
        case .sleep: .purple
        case .diaper: .green
        }
    }
}
