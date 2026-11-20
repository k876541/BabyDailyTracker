import Charts
import SwiftData
import SwiftUI

struct GrowthScreen: View {
    @State private var viewModel: GrowthViewModel
    @State private var editor: GrowthEditorState?
    @State private var showingProfileEditor = false

    init(context: ModelContext) {
        _viewModel = State(initialValue: GrowthViewModel(
            repository: SwiftDataGrowthRepository(context: context),
            profileRepository: BabyProfileRepository(context: context)
        ))
    }

    var body: some View {
        List {
            profileSection
            summarySection
            chartSection
            historySection
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.primary.opacity(0.04))
        .navigationTitle("成長")
        .toolbar {
            Button { editor = GrowthEditorState() } label: { Image(systemName: "plus") }
        }
        .sheet(item: $editor) { state in
            GrowthEditor(state: state) { measuredAt, height, weight in
                let record = state.record ?? GrowthRecord(measuredAt: measuredAt)
                return viewModel.save(record: record, measuredAt: measuredAt, height: height, weight: weight)
            }
        }
        .sheet(isPresented: $showingProfileEditor) {
            if let profile = viewModel.profile {
                ProfileEditor(profile: profile) { name, birthday in
                    viewModel.saveProfile(name: name, birthday: birthday)
                }
            }
        }
        .alert("提醒", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) { Button("好") { viewModel.errorMessage = nil } } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .task { viewModel.load() }
    }

    private var profileSection: some View {
        Section {
            Button { showingProfileEditor = true } label: {
            HStack {
                ZStack {
                    Circle().fill(.white.opacity(0.8)).frame(width: 58, height: 58)
                    Image(systemName: "figure.child").font(.system(size: 28, weight: .semibold)).foregroundStyle(BabyTheme.primary)
                }
                VStack(alignment: .leading) {
                    Text(viewModel.profile?.name ?? "寶寶").font(.title3.bold()).foregroundStyle(.primary)
                    Text(profileSubtitle)
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(
                LinearGradient(colors: [BabyTheme.sky, BabyTheme.mint.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
            }
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    private var profileSubtitle: String {
        guard let birthday = viewModel.profile?.birthday else { return "尚未設定生日" }
        let components = Calendar.current.dateComponents([.year, .month], from: birthday, to: .now)
        let years = max(0, components.year ?? 0)
        let months = max(0, components.month ?? 0)
        let age = years > 0 ? "\(years) 歲 \(months) 個月" : "\(months) 個月"
        return "生日 \(birthday.formatted(date: .abbreviated, time: .omitted))・\(age)"
    }

    private var summarySection: some View {
        Section("最新測量") {
            HStack(spacing: 12) {
                metricCard(.height, icon: "ruler.fill", color: BabyTheme.peach)
                metricCard(.weight, icon: "scalemass.fill", color: BabyTheme.lavender)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    private func metricCard(_ metric: GrowthMetric, icon: String, color: Color) -> some View {
        let summary = viewModel.summary(for: metric)
        return VStack(alignment: .leading, spacing: 9) {
            Image(systemName: icon).foregroundStyle(BabyTheme.primary)
            Text(metric.rawValue).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(summaryText(metric)).font(.title3.bold()).lineLimit(1).minimumScaleFactor(0.75)
            Text(changeText(summary?.change, unit: metric.unit)).font(.caption).foregroundStyle(changeColor(summary?.change))
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(15)
        .background(color, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var chartSection: some View {
        Section("歷史趨勢") {
            Picker("趨勢", selection: $viewModel.selectedMetric) {
                ForEach(GrowthMetric.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            if viewModel.trend.isEmpty {
                ContentUnavailableView("尚無資料", systemImage: "chart.xyaxis.line")
            } else {
                Chart(viewModel.trend) { point in
                    LineMark(x: .value("日期", point.date), y: .value(viewModel.selectedMetric.rawValue, point.value))
                    PointMark(x: .value("日期", point.date), y: .value(viewModel.selectedMetric.rawValue, point.value))
                }
                .foregroundStyle(BabyTheme.primary)
                .frame(height: 210)
                .chartYAxisLabel(viewModel.selectedMetric.unit)
            }
        }
    }

    private var historySection: some View {
        Section("歷史紀錄") {
            if viewModel.records.isEmpty {
                Text("按右上角＋新增第一次測量").foregroundStyle(.secondary)
            }
            ForEach(viewModel.records) { record in
                Button {
                    editor = GrowthEditorState(record: record)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(record.measuredAt.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.primary)
                        HStack {
                            if let height = record.heightCM { Text("身高 \(height.formatted()) cm") }
                            if let weight = record.weightKG { Text("體重 \(weight.formatted()) kg") }
                        }
                        .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { offsets in
                for index in offsets { viewModel.delete(viewModel.records[index]) }
            }
        }
    }

    private func summaryText(_ metric: GrowthMetric) -> String {
        guard let value = viewModel.summary(for: metric)?.latest else { return "尚無資料" }
        return value.formatted(.number.precision(.fractionLength(0...2))) + " " + metric.unit
    }

    private func changeText(_ value: Double?, unit: String) -> String {
        guard let value else { return "無前次資料" }
        let sign = value > 0 ? "+" : ""
        return "較前次 \(sign)\(value.formatted(.number.precision(.fractionLength(0...2)))) \(unit)"
    }

    private func changeColor(_ value: Double?) -> Color {
        guard let value else { return .secondary }
        return value >= 0 ? .green : .orange
    }
}

private struct ProfileEditor: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (String, Date) -> Void
    @State private var name: String
    @State private var birthday: Date

    init(profile: BabyProfile, onSave: @escaping (String, Date) -> Void) {
        self.onSave = onSave
        _name = State(initialValue: profile.name)
        _birthday = State(initialValue: profile.birthday)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("姓名", text: $name)
                DatePicker("生日", selection: $birthday, in: ...Date.now, displayedComponents: .date)
            }
            .navigationTitle("寶寶資料")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") { onSave(name, birthday); dismiss() }
                }
            }
        }
    }
}

struct GrowthEditorState: Identifiable {
    let id = UUID()
    let record: GrowthRecord?
    init(record: GrowthRecord? = nil) { self.record = record }
}

private struct GrowthEditor: View {
    @Environment(\.dismiss) private var dismiss
    let state: GrowthEditorState
    let onSave: (Date, Double?, Double?) -> Bool
    @State private var measuredAt: Date
    @State private var heightText: String
    @State private var weightText: String
    @State private var inputError: String?

    init(state: GrowthEditorState, onSave: @escaping (Date, Double?, Double?) -> Bool) {
        self.state = state
        self.onSave = onSave
        _measuredAt = State(initialValue: state.record?.measuredAt ?? .now)
        _heightText = State(initialValue: state.record?.heightCM.map { String($0) } ?? "")
        _weightText = State(initialValue: state.record?.weightKG.map { String($0) } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("測量時間", selection: $measuredAt)
                TextField("身高（cm，可留空）", text: $heightText).growthNumberKeyboard()
                TextField("體重（kg，可留空）", text: $weightText).growthNumberKeyboard()
                Text("至少填寫身高或體重其中一項。").font(.caption).foregroundStyle(.secondary)
            }
            .navigationTitle(state.record == nil ? "新增測量" : "編輯測量")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        do {
                            let input = try GrowthInputParser.parse(heightText: heightText, weightText: weightText)
                            if onSave(measuredAt, input.height, input.weight) { dismiss() }
                        } catch GrowthValidationError.invalidHeight {
                            inputError = "身高必須是大於 0 的數字。"
                        } catch GrowthValidationError.invalidWeight {
                            inputError = "體重必須是大於 0 的數字。"
                        } catch {
                            inputError = "請至少填寫身高或體重。"
                        }
                    }
                }
            }
            .alert("輸入有誤", isPresented: Binding(
                get: { inputError != nil }, set: { if !$0 { inputError = nil } }
            )) { Button("好") { inputError = nil } } message: { Text(inputError ?? "") }
        }
    }
}

private extension View {
    @ViewBuilder
    func growthNumberKeyboard() -> some View {
        #if os(iOS)
        self.keyboardType(.decimalPad)
        #else
        self
        #endif
    }
}

