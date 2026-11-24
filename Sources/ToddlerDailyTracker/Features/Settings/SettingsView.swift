import SwiftData
import SwiftUI

struct SettingsView: View {
    @State private var viewModel: SettingsViewModel
    let onReset: () -> Void

    init(context: ModelContext, onReset: @escaping () -> Void) {
        _viewModel = State(initialValue: SettingsViewModel(
            repository: SwiftDataAppDataResetRepository(context: context),
            scheduler: UserNotificationMedicationScheduler()
        ))
        self.onReset = onReset
    }

    var body: some View {
        Form {
            Section {
                Button("移除寶寶資料", role: .destructive) {
                    viewModel.requestReset()
                }
                .disabled(viewModel.isResetting)

                if viewModel.isResetting {
                    HStack {
                        ProgressView()
                        Text("正在移除所有本機資料…")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("寶寶資料")
            } footer: {
                Text("將清除寶寶資料、飲食、睡眠、排便、成長與餵藥紀錄，且無法復原。")
            }
        }
        .navigationTitle("設定")
        .confirmationDialog(
            "要移除寶寶資料嗎？",
            isPresented: stageBinding(.first),
            titleVisibility: .visible
        ) {
            Button("繼續") { viewModel.confirmFirstReset() }
            Button("取消", role: .cancel) { viewModel.cancelReset() }
        } message: {
            Text("下一步會再次確認；目前尚未刪除任何資料。")
        }
        .alert("永久刪除所有資料？", isPresented: stageBinding(.permanent)) {
            Button("取消", role: .cancel) { viewModel.cancelReset() }
            Button("永久刪除", role: .destructive) {
                Task {
                    if await viewModel.confirmPermanentReset() {
                        onReset()
                    }
                }
            }
        } message: {
            Text("這會刪除所有本機紀錄與尚未送出的餵藥提醒，完成後無法復原。")
        }
        .alert("無法移除資料", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("好") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private func stageBinding(_ stage: SettingsConfirmationStage) -> Binding<Bool> {
        Binding(
            get: { viewModel.confirmationStage == stage },
            set: { if !$0 { viewModel.cancelReset() } }
        )
    }
}
