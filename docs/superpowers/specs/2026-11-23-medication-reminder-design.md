# 固定時段餵藥提醒設計

## 目的

讓照顧者在看完醫生後，快速設定一段有限天數的餵藥提醒。第一版不管理藥名、劑量或多種藥物，只處理固定時間提醒、完成紀錄、延後提醒與最低間隔警示。

## 目標

- 設定開始日期、提醒天數與每天多個固定時間。
- 設定最低服藥間隔，預設 4 小時，可選 4 或 5 小時。
- 設定延後提醒分鐘數，預設 5 分鐘，使用五分鐘步進。
- 儲存前檢查整段療程內相鄰時段，包含跨日間隔。
- 最多建立 48 個固定時段，依每天時段數動態限制療程天數。
- 使用本機通知顯示「已完成」與「知道了」兩個操作。
- 「已完成」保存實際完成時間；「知道了」依設定分鐘數再次提醒。
- 晚完成不調整後續固定時段，只在 App 顯示與下一時段間隔不足的提示。
- 支援查看今日狀態、編輯、提前結束與刪除療程。

## 非目標

- 不記錄藥名、劑量、單位或藥物照片。
- 不支援多組同時進行的療程。
- 不依實際完成時間自動順延後續提醒。
- 不提供醫療建議或判斷能否服藥。
- 不使用 APNs、後端、帳號、雲端同步或跨裝置同步。
- 不保證使用者關閉通知權限、專注模式或系統摘要時仍顯示橫幅。

## 採用方案

採有限天數的一次性本機通知：療程內每個固定時段建立獨立通知，最多 48 筆。相較滾動排程，此方案不依賴使用者重新開啟 App；相較遠端 Push，不需要後端與裝置 Token。保留系統其餘通知額度供延後提醒使用。

## 使用流程

1. 使用者從「提醒」頁建立餵藥提醒。
2. 設定開始日期、天數、最低間隔與延後分鐘數。
3. 新增每日固定時間；時間選擇以五分鐘為單位。
4. 當時間不足最低間隔、天數無效或總時段超過 48 時，畫面立即說明原因並禁止儲存。
5. 第一次儲存前請求通知權限；拒絕時保留草稿並顯示前往系統設定的說明，不建立有效療程。
6. 儲存成功後建立療程、所有時段紀錄及本機通知。
7. 通知上的「已完成」將該時段標記完成並保存實際時間。
8. 「知道了」會將該時段標記為已延後，並建立一筆新的單次通知。
9. App 今日頁顯示待完成、已延後與已完成時段；若完成時間距下一固定時段不足設定間隔，顯示非醫療性的時間提示。
10. 編輯、提前結束或刪除療程時，移除相關待送通知並依新設定重新排程。

## 資料模型

### MedicationReminderPlan

- `id: UUID`
- `startDate: Date`
- `durationDays: Int`
- `minimumIntervalMinutes: Int`
- `snoozeMinutes: Int`
- `isActive: Bool`
- `createdAt: Date`

第一版 Repository 只允許一筆進行中的療程。

### MedicationReminderTime

- `id: UUID`
- `hour: Int`
- `minute: Int`
- 與 `MedicationReminderPlan` 關聯

### MedicationDoseOccurrence

- `id: UUID`
- `scheduledAt: Date`
- `statusRawValue: String`，狀態為 `pending`、`snoozed`、`completed`、`skipped`
- `completedAt: Date?`
- `nextReminderAt: Date?`
- `snoozeCount: Int`
- 與 `MedicationReminderPlan` 關聯

每個固定時段預先建立一筆 occurrence。通知 identifier 使用 occurrence ID，避免同時間紀錄混淆。

## 架構

維持 SwiftUI + MVVM + Repository + SwiftData：

- `Features/MedicationReminder/` 放置 View、ViewModel、驗證與 `DESIGN.md`。
- SwiftData models 保持在既有 Models 層；Repository 負責療程與 occurrence 的一致性寫入。
- `MedicationReminderScheduling` protocol 隔離 `UNUserNotificationCenter`，正式環境使用本機通知實作，測試使用 fake scheduler。
- App 啟動時註冊 notification category 與兩個 action。
- `UNUserNotificationCenterDelegate` 將操作轉交給 `@MainActor` 的 notification response handler，再透過 Repository 更新 SwiftData。
- 排程採先驗證、建立資料、排通知；任一步失敗時取消本次已加入的通知並回復資料，避免部分成功。

## 通知規則

- Category：`MEDICATION_REMINDER`
- Action：`MEDICATION_COMPLETED`、`MEDICATION_SNOOZE`
- 「已完成」不開啟 App 即可處理；完成後取消同 occurrence 尚未送出的延後通知。
- 「知道了」使用當下時間加上 `snoozeMinutes` 建立單次通知，並更新 occurrence。
- 使用者直接點通知時開啟 App 並定位到今日提醒。
- App 在前景時仍顯示 banner 與聲音，行為由 notification center delegate 決定。

## 驗證規則

- 提醒天數必須大於 0。
- 每天至少一個提醒時間，且不得重複。
- 時間按實際療程日期展開後排序，再檢查所有相鄰 occurrence 的間隔。
- 相鄰間隔少於設定的 4 或 5 小時時禁止儲存。
- `每天時段數 × 療程天數` 不得超過 48；畫面顯示目前設定可用的最大天數。
- 延後分鐘數必須為正數。
- 任何通知或 SwiftData 錯誤都轉為可顯示狀態，不使用強制解包或造成 Crash。

## 畫面

- 新增「提醒」分頁。
- 無療程時顯示簡短說明與「建立餵藥提醒」。
- 設定頁包含開始日期、天數、每日時間、最低間隔與延後時間。
- 有療程時顯示今日時段、狀態及實際完成時間，並提供編輯、提前結束與刪除。
- 警示文案只描述時間，例如「距離下一個提醒少於 4 小時」，不判斷是否可以服藥。

## 測試

- 時段排序、重複時間、跨日間隔、4／5 小時邊界與 48 筆上限。
- 建立、編輯、提前結束與刪除時的 Repository 一致性。
- 排程成功、部分失敗回復、取消與重新排程。
- 「已完成」狀態與實際完成時間。
- 「知道了」延後時間、重複延後與已完成後取消延後通知。
- 晚完成不改動下一固定時段，但能產生間隔提示。
- 通知權限未決定、允許、拒絕與之後被關閉的狀態。
- ViewModel 的空值、錯誤與重入行為；測試不使用固定 `sleep` 等待。

## 已知限制

- iOS 決定通知橫幅的實際呈現；專注模式、通知摘要與系統設定可能延後或隱藏通知。
- 第一版最多 48 個固定時段；延後通知不計入療程上限，但同一 occurrence 同時只保留一筆延後通知。
- 裝置時間或時區變更後，App 下次啟動時重新核對未來通知。
- 本功能是生活紀錄工具，不替代醫囑。
