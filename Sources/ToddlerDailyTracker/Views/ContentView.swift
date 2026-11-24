import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context

    var body: some View {
        AppRootView(context: context)
    }
}

private struct AppRootView: View {
    @State private var viewModel: AppLaunchViewModel

    init(context: ModelContext) {
        _viewModel = State(initialValue: AppLaunchViewModel(repository: SwiftDataBabyProfileRepository(context: context)))
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView("準備寶寶資料…")
            case .needsBabyProfile:
                BabyOnboardingView { name, birthday in viewModel.save(name: name, birthday: birthday) }
            case .ready:
                MainTabView { viewModel.showOnboarding() }
            }
        }
        .task { if viewModel.state == .loading { viewModel.load() } }
        .alert("提醒", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) { Button("好") { viewModel.errorMessage = nil } } message: { Text(viewModel.errorMessage ?? "") }
    }
}

private struct MainTabView: View {
    @Environment(\.modelContext) private var context
    @AppStorage(MedicationReminderNavigation.selectedTabKey) private var selectedTab = MainTabSelection.today.rawValue
    let onReset: () -> Void

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { TodayView(context: context) }
                .tabItem { Label("日常", systemImage: "list.bullet.clipboard") }
                .tag(MainTabSelection.today.rawValue)
            NavigationStack { HistoryView(context: context) }
                .tabItem { Label("歷史", systemImage: "calendar") }
                .tag(MainTabSelection.history.rawValue)
            NavigationStack { GrowthScreen(context: context) }
                .tabItem { Label("成長", systemImage: "chart.xyaxis.line") }
                .tag(MainTabSelection.growth.rawValue)
            NavigationStack { MedicationReminderView(context: context) }
                .tabItem { Label("提醒", systemImage: "bell.badge") }
                .tag(MainTabSelection.reminder.rawValue)
            NavigationStack { SettingsView(context: context, onReset: onReset) }
                .tabItem { Label("設定", systemImage: "gearshape") }
                .tag(MainTabSelection.settings.rawValue)
        }
        .tint(BabyTheme.primary)
    }
}

private struct BabyOnboardingView: View {
    let onSave: (String, Date) -> Bool
    @State private var name = ""
    @State private var birthday = Date.now

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    ZStack {
                        Circle().fill(BabyTheme.peach).frame(width: 112, height: 112)
                        Image(systemName: "figure.child").font(.system(size: 52, weight: .semibold)).foregroundStyle(BabyTheme.primary)
                    }
                    VStack(spacing: 8) {
                        Text("先認識寶寶").font(.largeTitle.bold())
                        Text("完成基本資料後，就可以開始記錄每天的重要時刻。")
                            .multilineTextAlignment(.center).foregroundStyle(.secondary)
                    }
                    VStack(spacing: 16) {
                        TextField("寶寶姓名", text: $name)
                            .textFieldStyle(.roundedBorder)
                        DatePicker("生日", selection: $birthday, in: ...Date.now, displayedComponents: .date)
                    }
                    .padding(20)
                    .background(.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    Button("開始使用") { _ = onSave(name, birthday) }
                        .buttonStyle(.borderedProminent).controlSize(.large).frame(maxWidth: .infinity)
                }
                .padding(24)
            }
            .background(BabyTheme.peach.opacity(0.35))
        }
    }
}

enum BabyTheme {
    static let primary = Color(red: 0.91, green: 0.48, blue: 0.36)
    static let peach = Color(red: 1.00, green: 0.91, blue: 0.85)
    static let mint = Color(red: 0.82, green: 0.94, blue: 0.88)
    static let lavender = Color(red: 0.89, green: 0.87, blue: 0.97)
    static let sky = Color(red: 0.84, green: 0.92, blue: 0.98)
}

