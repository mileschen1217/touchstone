# 0040 — source-as-truth:opt-in discipline → always-on,錨定 epic lifecycle

- **Status:** accepted
- **Date:** 2026-07-18
- **Deciders:** miles
- **Supersedes:** local ADR-0004(source-as-truth 分類為 per-project opt-in discipline;該檔在 `.touchstone/docs/adr/`,gitignored)
- **Bet-owner:** miles
- **Flip-trigger:** 連續 ≥3 個 epic close 的 Disposition pass 結果為 `all none`(無 promote、無 retire、kill-on 全 quiet)→ 回訪本決定,考慮縮回 opt-in 或再減面。看的人:close 的執行者。
- **Assumptions:** ①epic 是所有 durable prose 的唯一生產通道(繞過 epic 產生的 standing doc 不受本機制管)②promote 目標(docs/adr/、CONTEXT.md、README)足以容納 durable residue,不需新家

## Context

v2 蒸餾把 close 端的 Doc Reckoning 整支移除,design-spec 的 Source-level Deposit 節成為 write-only 孤兒(全 repo 僅 template.md 命中,無 consumer)。史上退役機制 live 跑過一次、退役數為零——按 R2 準入回測,v1 那套教義塔(four doc kinds / proximity ladder / rubric / schema)不會被admitted。但外部證據支持「完成即處置」這一步不可省:spec-kit 無退役步驟的結局是 spec 腐化、團隊改讀 code(官方 discussion #152);OpenSpec 的 archive 原子動作(值得留的併回 truth + 整目錄移 dated archive)是最小可移植形;agent 情境下 stale context 會以 ground truth 姿態誤導後續 session。

## Decision

1. **always-on**:`bridge-content-gate` / `standing-vs-transient` 注入改無條件;init 不再選 discipline,`adopted_disciplines` 鍵退役(legacy 鍵忽略)。
2. **閉環讀取端 = close 的 Disposition pass**(prose 步驟,無 script):讀各 spec 的 Deposit → durable residue promote 進 canonical 家 / bridge 退役 + kill-on 檢查 → epic 目錄整體移 `archive/epics/`。「epics/ 目錄空 = 無在途工作」為 workspace 狀態不變式。
3. **教義塔不回歸**;freshness/drift 自動偵測不預建,准入路徑 = gate-miss「stale-doc 誤導」≥3 筆走 R2。

## Consequences

- Deposit 由 write-only 恢復為有 consumer 的宣告面;close 的清理從考古變 checklist。
- 非 epic 通道產生的 standing doc 落在機制外(假設①的邊界)——出現此類漏網即記 gate-miss。
- 舊專案 yaml 含 `adopted_disciplines` 者無需遷移,鍵被忽略。
