# Toddler Daily Tracker MVP Implementation Plan

**Goal:** 完成飲食、睡眠、排便與寶寶成長紀錄的本機 iOS MVP。

**Architecture:** SwiftUI 畫面透過 MVVM 消費 Repository；Repository 使用 SwiftData。成長驗證、排序、最新值與差異計算以純領域邏輯實作。

**Tech Stack:** Swift 6、SwiftUI、SwiftData、Swift Charts、Swift Testing。

**Spec:** `docs/specs/2026-11-20-toddler-daily-tracker-mvp.md`

## 任務

- [x] 建立 Swift Package 與領域測試，確認測試先因缺少實作而失敗。
- [x] 實作 SwiftData models、驗證與成長統計，讓領域測試通過。
- [x] 實作 Repository、ViewModels 與四類紀錄 UI。
- [x] 執行完整測試與 debug build，記錄已知限制。

## Review Focus

- 身高與體重皆空、零、負數或非有限數不可儲存。
- 只填一種測量時，另一種趨勢與差異不可被干擾。
- 補登資料必須依測量日期重新排序與比較。
- 只有一次有效測量時，差異顯示為無前次資料。
- 睡眠結束早於開始時不可儲存。

