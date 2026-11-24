import SwiftData
import SwiftUI

struct MedicationReminderView: View {
    @State private var viewModel: MedicationReminderViewModel
    @State private var showsEditor = false
    @State private var showsEndConfirmation = false
    @State private var showsDeleteConfirmation = false

    init(context: ModelContext) {
        let repository = SwiftDataMedicationReminderRepository(context: context)
        let scheduler = UserNotificationMedicationScheduler()
        let coordinator = MedicationReminderCoordinator(repository: repository, scheduler: scheduler)
        _viewModel = State(initialValue: MedicationReminderViewModel(
            repository: repository,
            coordinator: coordinator
        ))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if viewModel.activePlan == nil {
                    emptyState
                } else {
                    activeCourse
                }
            }
            .padding()
        }
        .background(BabyTheme.peach.opacity(0.2))
        .navigationTitle("餵藥提醒")
        .task { viewModel.load() }
        .sheet(isPresented: $showsEditor) {
            MedicationReminderEditor(viewModel: viewModel, isPresented: $showsEditor)
        }
        .alert("提醒", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("好") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .confirmationDialog("要提前結束這次提醒嗎？", isPresented: $showsEndConfirmation) {
            Button("提前結束", role: .destructive) { Task { await viewModel.end() } }
        }
        .confirmationDialog("要刪除這次提醒與紀錄嗎？", isPresented: $showsDeleteConfirmation) {
            Button("刪除", role: .destructive) { Task { await viewModel.delete() } }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "bell.badge")
                .font(.system(size: 48))
                .foregroundStyle(BabyTheme.primary)
            Text("設定固定時段提醒")
                .font(.title2.bold())
            Text("設定提醒天數與每天的固定時間，通知可直接標記完成或延後確認。")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("建立餵藥提醒") { showsEditor = true }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var activeCourse: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("今天的提醒").font(.title2.bold())
                    Text("固定時間不會因晚完成而自動順延")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("編輯") { showsEditor = true }
            }

            if let warning = viewModel.intervalWarning {
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            }

            if viewModel.todayOccurrences.isEmpty {
                ContentUnavailableView("今天沒有提醒", systemImage: "calendar.badge.checkmark")
            } else {
                ForEach(viewModel.todayOccurrences, id: \.id) { occurrence in
                    MedicationOccurrenceRow(occurrence: occurrence)
                }
            }

            HStack {
                Button("提前結束") { showsEndConfirmation = true }
                    .buttonStyle(.bordered)
                Button("刪除", role: .destructive) { showsDeleteConfirmation = true }
                    .buttonStyle(.bordered)
            }
        }
        .padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct MedicationOccurrenceRow: View {
    let occurrence: MedicationDoseOccurrence

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title3)
            VStack(alignment: .leading, spacing: 3) {
                Text(occurrence.scheduledAt, format: .dateTime.hour().minute())
                    .font(.headline)
                Text(statusText).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let completedAt = occurrence.completedAt {
                Text(completedAt, format: .dateTime.hour().minute())
                    .font(.caption.monospacedDigit())
            }
        }
        .padding(14)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
    }

    private var icon: String {
        switch occurrence.status {
        case .pending: "clock"
        case .snoozed: "clock.arrow.circlepath"
        case .completed: "checkmark.circle.fill"
        case .skipped: "minus.circle"
        }
    }

    private var color: Color {
        switch occurrence.status {
        case .pending: BabyTheme.primary
        case .snoozed: .orange
        case .completed: .green
        case .skipped: .secondary
        }
    }

    private var statusText: String {
        switch occurrence.status {
        case .pending: "待完成"
        case .snoozed: "已延後 \(occurrence.snoozeCount) 次"
        case .completed: "已完成"
        case .skipped: "已結束"
        }
    }
}

private struct MedicationReminderEditor: View {
    @Bindable var viewModel: MedicationReminderViewModel
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("療程") {
                    DatePicker(
                        "開始日期",
                        selection: $viewModel.draft.startDate,
                        in: Calendar.current.startOfDay(for: .now)...,
                        displayedComponents: .date
                    )
                    Stepper(
                        "提醒 \(viewModel.draft.durationDays) 天",
                        value: $viewModel.draft.durationDays,
                        in: 1...max(viewModel.maximumDurationDays, 1)
                    )
                    Text("目前每天 \(viewModel.draft.times.count) 次，最多可設定 \(viewModel.maximumDurationDays) 天。")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("每天固定時間") {
                    ForEach(viewModel.draft.times.indices, id: \.self) { index in
                        HStack {
                            DatePicker(
                                "提醒 \(index + 1)",
                                selection: timeBinding(at: index),
                                displayedComponents: .hourAndMinute
                            )
                            if viewModel.draft.times.count > 1 {
                                Button(role: .destructive) {
                                    viewModel.draft.times.remove(at: index)
                                } label: {
                                    Image(systemName: "trash")
                                }
                            }
                        }
                    }
                    Button("新增時間", systemImage: "plus") {
                        viewModel.draft.times.append(MedicationReminderTime(hour: 21, minute: 0))
                    }
                }

                Section("提醒規則") {
                    Picker("最低間隔", selection: $viewModel.draft.minimumIntervalMinutes) {
                        Text("4 小時").tag(240)
                        Text("5 小時").tag(300)
                    }
                    Stepper(
                        "知道了後 \(viewModel.draft.snoozeMinutes) 分鐘再提醒",
                        value: $viewModel.draft.snoozeMinutes,
                        in: 5...60,
                        step: 5
                    )
                }

                Section {
                    Text("如果較晚才完成，下一個固定提醒不會自動順延；間隔不足時只會顯示時間提示。")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle(viewModel.activePlan == nil ? "建立提醒" : "編輯提醒")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(viewModel.isSaving ? "儲存中…" : "儲存") {
                        Task {
                            await viewModel.save()
                            if viewModel.errorMessage == nil { isPresented = false }
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
        }
    }

    private func timeBinding(at index: Int) -> Binding<Date> {
        Binding(
            get: {
                let time = viewModel.draft.times[index]
                return Calendar.current.date(
                    bySettingHour: time.hour,
                    minute: time.minute,
                    second: 0,
                    of: viewModel.draft.startDate
                ) ?? viewModel.draft.startDate
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                guard let hour = components.hour, let minute = components.minute else { return }
                viewModel.draft.times[index] = MedicationReminderTime(
                    hour: hour,
                    minute: (minute / 5) * 5
                )
                viewModel.draft.times.sort { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
            }
        )
    }
}
