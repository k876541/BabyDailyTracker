# GitHub Actions CI 設計

## 目的

在 BabyDailyTracker 每次 push 或 Pull Request 時，由 GitHub 自動驗證單元測試、iOS Simulator 編譯與格式，讓個人開發也能在合併前發現破壞性修改。

## 目標

- 使用 GitHub Actions，在 GitHub 管理的 macOS runner 執行。
- 所有分支的 push 與 Pull Request 都觸發 CI。
- 同一分支有新 commit 時，取消尚未完成的舊執行。
- 執行完整 `swift test --disable-sandbox`。
- 執行 generic iOS Simulator、停用簽章的 `xcodebuild`。
- 執行 `git diff --check`。
- 僅給 workflow `contents: read` 權限，不使用 Apple 憑證、Secrets 或寫入權限。

## 非目標

- 不封存或發布 App artifact。
- 不上傳 TestFlight 或 App Store。
- 不處理版本號、自動簽章、Apple Developer 憑證或 App Store Connect。
- 不處理 Android build。

## 已考慮方案

### 單一工作

一台 runner 依序執行格式、測試與 iOS build。啟動成本與資源用量較低，設定容易理解，適合目前單一 App 的個人公開專案。

### 拆成測試與編譯工作

兩台 runner 平行執行，失敗分類更明顯，但會重複 checkout 與環境啟動，對目前規模沒有足夠收益。

採用單一工作。

## Workflow

- 路徑：`.github/workflows/ci.yml`
- Runner：`xcode-27`，與本機 Xcode 27 及 README 要求一致；此 runner 目前仍屬 GitHub preview，若發生平台排隊或映像不穩，後續可改為穩定 macOS runner 並明確選擇已安裝的 Xcode。
- Checkout：`actions/checkout@v7`。
- Job timeout：20 分鐘，避免異常執行長時間占用 runner。
- Concurrency group 以 workflow 與 branch／PR ref 組合，`cancel-in-progress: true`。
- Build 使用獨立 DerivedData 暫存路徑，`CODE_SIGNING_ALLOWED=NO`。

## 驗證方式

- 本機解析 YAML 並檢查 workflow 必要欄位。
- 本機重新執行 workflow 中相同的 `swift test`、`xcodebuild` 與 `git diff --check`。
- 提交並推送後，從 GitHub Actions 讀取第一次 workflow run，確認結論為 success；若 GitHub runner 或 workflow 設定失敗，依實際 log 修正後重跑。

## 已知限制

- GitHub Actions 只能驗證模擬器編譯，不能取代真機操作與 UI 測試。
- `xcode-27` runner 處於 preview，可能有排隊或映像變動。
- 未設定 branch protection，因此 CI 失敗目前不會強制阻擋直接 push 或 merge。
