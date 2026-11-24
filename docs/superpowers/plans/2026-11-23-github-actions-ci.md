# GitHub Actions CI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立 GitHub Actions workflow，在每次 push 與 Pull Request 自動驗證 BabyDailyTracker。

**Architecture:** 使用一個唯讀權限的 `xcode-27` macOS job，依序執行格式檢查、Swift 測試與無簽章 iOS Simulator build。同分支的新執行會取消舊執行，完成後推送分支並讀取 GitHub Actions 的實際結果。

**Tech Stack:** GitHub Actions, Xcode 27, Swift Package Manager, xcodebuild

**Spec:** `docs/superpowers/specs/2026-11-21-github-actions-ci-design.md`

## Global Constraints

- 不加入 Apple 憑證、Secrets、簽章或發布步驟。
- Workflow 僅使用 `contents: read` 權限。
- 所有分支 push 與 Pull Request 都必須觸發。
- 使用單一 job，timeout 為 20 分鐘。
- 本階段不處理 TestFlight、App Store、Android 或 branch protection。

## Review Focus

- Fork Pull Request 不得取得寫入權限或 Secrets；workflow 只宣告 `contents: read`。
- 同一分支快速連續 push 時，舊執行應由 concurrency group 取消。
- iOS build 不得要求簽章；命令固定帶 `CODE_SIGNING_ALLOWED=NO`。
- SwiftPM 測試及 Xcode build 都必須從 repository root 執行。
- GitHub preview runner 暫時不可用時，失敗應明確顯示為 runner／環境問題，不加入隱藏重試或繞過驗證。

---

### Task 1: 建立並驗證 CI Workflow

**Files:**
- Create: `.github/workflows/ci.yml`
- Modify: `README.md`

**Interfaces:**
- Consumes: `Package.swift`, `ToddlerDailyTracker.xcodeproj`, scheme `ToddlerDailyTracker`
- Produces: GitHub Actions workflow `CI` and README CI status badge

- [ ] **Step 1: Verify the workflow is absent**

Run: `test -f .github/workflows/ci.yml`

Expected: exit 1 because the workflow does not exist.

- [ ] **Step 2: Create `.github/workflows/ci.yml`**

設定 `push`、`pull_request`、`permissions: contents: read`、以 workflow 與 ref 組成的 concurrency group、`cancel-in-progress: true`、`runs-on: xcode-27`、`timeout-minutes: 20`，並以 `actions/checkout@v7` checkout。

依序執行：

1. `git diff --check`
2. `swift test --disable-sandbox`
3. `xcodebuild -quiet -project ToddlerDailyTracker.xcodeproj -scheme ToddlerDailyTracker -destination 'generic/platform=iOS Simulator' -derivedDataPath "$RUNNER_TEMP/BabyDailyTrackerDerivedData" CODE_SIGNING_ALLOWED=NO build`

- [ ] **Step 3: Add the CI badge and short documentation**

在 `README.md` 標題下加入 `CI` workflow badge，並說明 push／Pull Request 會自動執行測試與 iOS Simulator build，無需 Apple Developer 憑證。

- [ ] **Step 4: Validate syntax and local equivalents**

Run: `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci.yml", aliases: true)'`

Expected: exit 0.

Run: `git diff --check`

Expected: no output.

Run: `swift test --disable-sandbox`

Expected: 35 tests pass.

Run: `xcodebuild -quiet -project ToddlerDailyTracker.xcodeproj -scheme ToddlerDailyTracker -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/BabyDailyTrackerCIDerivedData CODE_SIGNING_ALLOWED=NO build`

Expected: exit 0.

- [ ] **Step 5: Commit and push**

```bash
git add .github/workflows/ci.yml README.md
git commit -m "ci: add GitHub Actions validation"
git push -u origin chore/github-actions-ci
```

- [ ] **Step 6: Verify the first GitHub Actions run**

使用 GitHub CLI 讀取 `chore/github-actions-ci` 最新 `CI` run，等待完成並確認 conclusion 為 `success`。若失敗，讀取 failed job log，針對實際原因修正並重新推送；不得在未成功前宣告 CI 完成。
