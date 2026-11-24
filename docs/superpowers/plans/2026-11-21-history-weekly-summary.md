# History and Weekly Summary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新增可按日期回顧日常紀錄的歷史分頁、當日與近七日摘要，以及五分鐘快速選擇和任意分鐘精確輸入。

**Architecture:** 以純函式 `HistoryCalculator` 處理日期篩選與睡眠區間統計，`HistoryViewModel` 管理選定日期和 Repository 狀態，SwiftUI 畫面只負責呈現與操作。既有日常編輯器抽成共用功能，讓今天與歷史畫面使用同一套驗證及時間輸入。

**Tech Stack:** SwiftUI, Observation, SwiftData, Swift Testing, iOS 18+

**Spec:** `docs/superpowers/specs/2026-11-21-history-weekly-summary-design.md`

## Global Constraints

- 維持 SwiftUI + MVVM + Repository + SwiftData，不新增第三方套件。
- 未來日期不能成為歷史頁選定日期。
- 七日範圍包含選定日和之前六個日曆日，依 `Calendar` 的時區及日界線計算。
- 時間軸的睡眠以開始時間歸日；摘要的睡眠時間則按每日實際重疊區間分配。
- 精確時間使用有效的 24 小時 `HH:mm`，不可因錯誤輸入而 Crash 或靜默改成其他時間。
- 本計畫不實作提醒、通知、餵藥紀錄或伺服器 Push Notification。

## Review Focus

- 夏令時間造成一天不是固定 24 小時時，必須使用 Calendar 日界線而非固定秒數；由 Task 1 測試。
- 跨午夜或跨七日邊界的睡眠，只計算落在指定範圍內的區間；由 Task 1 測試。
- 進行中的睡眠開始時間晚於 `now` 時，摘要不得出現負數；由 Task 1 測試。
- `23:58` 四捨五入到五分鐘時需正確進入次日 `00:00`；由 Task 2 測試。
- 精確時間需拒絕 `24:00`、缺少前導零、非數字及不存在的分鐘；由 Task 2 測試。

---

### Task 1: 歷史摘要領域計算

**Files:**
- Create: `Sources/ToddlerDailyTracker/Features/History/HistoryCalculator.swift`
- Create: `Tests/ToddlerDailyTrackerTests/HistoryCalculatorTests.swift`

**Interfaces:**
- Consumes: `MealRecord`, `SleepRecord`, `DiaperRecord`, `DailyTimelineBuilder.build(...)`
- Produces: `DailyHistorySummary`, `WeeklyHistorySummary`, `HistoryCalculator.dailySummary(...)`, `HistoryCalculator.weeklySummary(...)`, `HistoryCalculator.timeline(...)`

- [ ] **Step 1: Write failing summary tests**

新增測試：選定日只計算當日飲食與排便；跨午夜睡眠按日界線切分；進行中及未來睡眠不產生負數；七日摘要排除第八日前資料；使用自訂時區 Calendar 驗證日界線。

- [ ] **Step 2: Run tests and verify RED**

Run: `swift test --disable-sandbox --filter HistoryCalculatorTests`

Expected: FAIL because `HistoryCalculator` and summary types do not exist.

- [ ] **Step 3: Implement summary interfaces**

```swift
struct DailyHistorySummary: Equatable {
    let mealCount: Int
    let diaperCount: Int
    let sleepDuration: TimeInterval
}

struct WeeklyHistorySummary: Equatable {
    let mealCount: Int
    let diaperCount: Int
    let sleepDuration: TimeInterval
    let recordedDayCount: Int
}

enum HistoryCalculator {
    static func dailySummary(meals: [MealRecord], sleeps: [SleepRecord], diapers: [DiaperRecord], day: Date, now: Date, calendar: Calendar) -> DailyHistorySummary
    static func weeklySummary(meals: [MealRecord], sleeps: [SleepRecord], diapers: [DiaperRecord], endingOn day: Date, now: Date, calendar: Calendar) -> WeeklyHistorySummary
    static func timeline(meals: [MealRecord], sleeps: [SleepRecord], diapers: [DiaperRecord], day: Date, calendar: Calendar) -> [DailyTimelineItem]
}
```

睡眠以 `[max(start, rangeStart), min(end ?? now, rangeEnd)]` 的正向交集累計；日界線一律由 `Calendar.dateInterval(of: .day, for:)` 取得。

- [ ] **Step 4: Run focused and full tests**

Run: `swift test --disable-sandbox --filter HistoryCalculatorTests`

Expected: PASS.

Run: `swift test --disable-sandbox`

Expected: all existing and new tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/ToddlerDailyTracker/Features/History/HistoryCalculator.swift Tests/ToddlerDailyTrackerTests/HistoryCalculatorTests.swift
git commit -m "feat: add history summary calculations"
```

### Task 2: 五分鐘快速時間與精確輸入

**Files:**
- Create: `Sources/ToddlerDailyTracker/Features/DailyRecordEditor/TimeInput.swift`
- Create: `Tests/ToddlerDailyTrackerTests/TimeInputTests.swift`

**Interfaces:**
- Consumes: Foundation `Date`, `Calendar`
- Produces: `TimeInput.roundedToFiveMinutes(_:calendar:)`, `TimeInput.parseExact(_:on:calendar:)`, `RecordDateTimeInput`

- [ ] **Step 1: Write failing time tests**

新增測試：`09:17` 取最近五分鐘成 `09:15`；`09:18` 成 `09:20`；`23:58` 成次日 `00:00`；精確輸入接受 `09:17` 並保留日期；拒絕 `9:17`、`24:00`、`12:60`、空值與非數字。

- [ ] **Step 2: Run tests and verify RED**

Run: `swift test --disable-sandbox --filter TimeInputTests`

Expected: FAIL because `TimeInput` does not exist.

- [ ] **Step 3: Implement parsing and rounding**

```swift
enum TimeInput {
    static func roundedToFiveMinutes(_ date: Date, calendar: Calendar = .current) -> Date
    static func parseExact(_ text: String, on date: Date, calendar: Calendar = .current) -> Date?
}
```

`parseExact` 僅接受正則概念等同 `^[0-2][0-9]:[0-5][0-9]$` 的字串，並另行限制小時 `0...23`。

- [ ] **Step 4: Add `RecordDateTimeInput`**

建立共用 SwiftUI 元件：日期 DatePicker、0...23 小時 Picker、每五分鐘 Picker、精確時間 Toggle 與 `HH:mm` TextField。元件以 `@Binding var date: Date` 回寫結果，無效精確時間透過 `validationMessage` 顯示並阻止儲存。

- [ ] **Step 5: Run focused and full tests**

Run: `swift test --disable-sandbox --filter TimeInputTests`

Expected: PASS.

Run: `swift test --disable-sandbox`

Expected: all tests PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/ToddlerDailyTracker/Features/DailyRecordEditor/TimeInput.swift Tests/ToddlerDailyTrackerTests/TimeInputTests.swift
git commit -m "feat: add flexible record time input"
```

### Task 3: 共用日常紀錄編輯器

**Files:**
- Create: `Sources/ToddlerDailyTracker/Features/DailyRecordEditor/DailyRecordEditors.swift`
- Modify: `Sources/ToddlerDailyTracker/Views/TodayView.swift`
- Modify: `ToddlerDailyTracker.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: `RecordDateTimeInput`, `DailyViewModel.saveMeal`, `saveSleep`, `saveDiaper`
- Produces: internal `DailyEditor`, `DailyRecordEditorSheet`, reusable by Today and History screens

- [ ] **Step 1: Move editor views without behavior changes**

把 `DailyEditor`、`MealEditor`、`SleepEditor`、`DiaperEditor` 及工具列移至 `DailyRecordEditors.swift`；以 `DailyRecordEditorSheet(editor:onSaveMeal:onSaveSleep:onSaveDiaper:)` 作為共用入口。

- [ ] **Step 2: Replace all editor DatePickers**

飲食與排便使用一個 `RecordDateTimeInput`；睡眠開始及結束各使用一個。新增紀錄初始時間先經五分鐘取整，編輯既有紀錄時保留原始精確分鐘。

- [ ] **Step 3: Reconnect TodayView**

讓 `TodayView` 使用共用 editor sheet，確認新增、編輯、份量驗證、睡眠範圍驗證與刪除行為不變。

- [ ] **Step 4: Add files to Xcode target and verify**

Run: `swift test --disable-sandbox`

Expected: all tests PASS.

Run: `xcodebuild -quiet -project ToddlerDailyTracker.xcodeproj -scheme ToddlerDailyTracker -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/BabyDailyTrackerDerivedData CODE_SIGNING_ALLOWED=NO build`

Expected: exit 0.

- [ ] **Step 5: Commit**

```bash
git add Sources/ToddlerDailyTracker/Features/DailyRecordEditor Sources/ToddlerDailyTracker/Views/TodayView.swift ToddlerDailyTracker.xcodeproj/project.pbxproj
git commit -m "refactor: share daily record editors"
```

### Task 4: 歷史 ViewModel 與日期操作

**Files:**
- Create: `Sources/ToddlerDailyTracker/Features/History/HistoryViewModel.swift`
- Create: `Tests/ToddlerDailyTrackerTests/HistoryViewModelTests.swift`

**Interfaces:**
- Consumes: `DailyRecordRepository`, `HistoryCalculator`, daily record models
- Produces: `HistoryViewModel` with `selectedDate`, `timeline`, `dailySummary`, `weeklySummary`, `selectPreviousDay()`, `selectNextDay()`, save/delete functions

- [ ] **Step 1: Write failing date navigation tests**

以固定 `now` 及 Calendar 測試：預設選今天；前一天正確跨月；下一天不超過今天；選擇未來日期會正規化為今天；存檔或刪除後會重新載入摘要。

- [ ] **Step 2: Run tests and verify RED**

Run: `swift test --disable-sandbox --filter HistoryViewModelTests`

Expected: FAIL because `HistoryViewModel` does not exist.

- [ ] **Step 3: Implement `HistoryViewModel`**

```swift
@MainActor @Observable
final class HistoryViewModel {
    init(repository: DailyRecordRepository, now: @escaping () -> Date = Date.init, calendar: Calendar = .current)
    var selectedDate: Date { get set }
    var timeline: [DailyTimelineItem] { get }
    var dailySummary: DailyHistorySummary { get }
    var weeklySummary: WeeklyHistorySummary { get }
    func select(_ date: Date)
    func selectPreviousDay()
    func selectNextDay()
    func load()
}
```

同時提供和 `DailyViewModel` 一致的三類 save/delete 入口，錯誤文字沿用現有語意。

- [ ] **Step 4: Run focused and full tests**

Run: `swift test --disable-sandbox --filter HistoryViewModelTests`

Expected: PASS.

Run: `swift test --disable-sandbox`

Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/ToddlerDailyTracker/Features/History/HistoryViewModel.swift Tests/ToddlerDailyTrackerTests/HistoryViewModelTests.swift
git commit -m "feat: add history view model"
```

### Task 5: 歷史分頁與 App 整合

**Files:**
- Create: `Sources/ToddlerDailyTracker/Features/History/HistoryView.swift`
- Modify: `Sources/ToddlerDailyTracker/Views/ContentView.swift`
- Modify: `Sources/ToddlerDailyTracker/Domain/GrowthMetrics.swift`
- Modify: `ToddlerDailyTracker.xcodeproj/project.pbxproj`
- Modify: `README.md`

**Interfaces:**
- Consumes: `HistoryViewModel`, `DailyRecordEditorSheet`, `DailyTimelineItem`
- Produces: `HistoryView(context:)` and a third `TabView` item labelled「歷史」

- [ ] **Step 1: Make timeline identity stable**

讓 `DailyTimelineItem` 攜帶來源紀錄的穩定識別資訊，History 與 Today 的編輯／刪除不再只用相同時間比對，避免兩筆同時間紀錄操作錯誤。

- [ ] **Step 2: Build HistoryView**

加入日期導覽、日曆 sheet、當日摘要卡、七日摘要卡、統一時間軸、空狀態、點擊編輯、滑動刪除及錯誤 alert。今天時停用下一日按鈕，所有顯示數值皆取自 ViewModel。

- [ ] **Step 3: Add History tab and target membership**

在 `MainTabView` 的「日常」與「成長」之間加入「歷史」，system image 使用 `calendar`；將 History 新檔加入 Xcode Sources build phase。

- [ ] **Step 4: Update README**

補上歷史查詢、七日摘要、跨日睡眠統計及五分鐘／精確時間輸入說明；提醒與 Push Notification 仍列為後續項目。

- [ ] **Step 5: Verify all tests and iOS build**

Run: `swift test --disable-sandbox`

Expected: all tests PASS with no failures.

Run: `xcodebuild -quiet -project ToddlerDailyTracker.xcodeproj -scheme ToddlerDailyTracker -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/BabyDailyTrackerDerivedData CODE_SIGNING_ALLOWED=NO build`

Expected: exit 0.

Run: `git diff --check`

Expected: no output.

- [ ] **Step 6: Commit**

```bash
git add Sources/ToddlerDailyTracker/Features/History Sources/ToddlerDailyTracker/Views/ContentView.swift Sources/ToddlerDailyTracker/Domain/GrowthMetrics.swift ToddlerDailyTracker.xcodeproj/project.pbxproj README.md
git commit -m "feat: add history and weekly summary"
```
