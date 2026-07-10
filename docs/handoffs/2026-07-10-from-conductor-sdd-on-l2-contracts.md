# Handoff: SDD on conductor L2 contracts（anvil Level-B 的正式化候選）

**From:** conductor session 2026-07-10（orchestration-mode build 完成後與人的延伸討論）
**To:** 未來的 touchstone epic scaffold（本文件是輸入，不是 epic 本身）

## The claim

anvil 文件裡的具名 deferral「Level-B — re-owning SDD's inner loop so the per-task
builder≠reviewer swap is program-enforced」有了具體的實作路徑與更完整的價值命題：
**SDD 的派工/回收改走 conductor L2 contracts**（task-contract + result schema +
check-result.py + fallback generator，vendor-neutral，已 build 完並 smoke 驗證）。

## 價值命題（比「紀律變硬」多一層）

機械驗收是「便宜模型跑 orchestration 迴圈」的前提：驗收機械化後，迴圈跑者的模型
等級與驗收嚴格度脫鉤——sonnet 級跑 dispatch/harvest/簿記，checker 駁 INVALID，
真判斷時刻（BLOCKED 裁決、reviewer ⚠️、品質 verdict）走 escalation ladder 上送。
**frontier 的錢只花在 plan 和裁決兩點**；今日 anvil 用主 session（frontier）做大量
sonnet 級收發，13-task run 的簿記燒 frontier context 是可觀察的浪費。

附帶槓桿——granularity：SDD 均勻 bite-size（小 scope 也 7-10 task × implementer+
reviewer）是模板固定開銷；contract 化後粒度由 commander 依 complexity tiering 判
（simple 批次成一張契約）。誠實邊界：粒度粗 = review 晚且大，槓桿是風險定粒度，
不是少切；另小 scope 浪費部分是 routing miss（該走 PRD+seams 輕迴圈）。

## 歸屬判斷（已與人確認）

- **不屬於 `touchstone-as-harness`**：那是信任邊界/out-of-band 題（un-forgeable
  oracle、CI-handoff、API-billed inversion）。本題是 **in-band 機械化**（checker
  只是 Bash，orchestrator 仍是互動 session，不離開訂閱頻帶）——skill-ceiling 的鄰居。
- 建議形狀：新 proposed epic（slug 如 `sdd-on-l2-contracts`），或併入 skill-ceiling
  的 phase——scaffold 時由 intention-first gate 裁。

## 依賴與前置

- conductor L2 已 shipped（github.com/mileschen1217/conductor @ main）；其
  pending-live benchmark（AC-2/10/12）與本題獨立，不互為前置。
- conductor 側同輪記錄：project memory `conductor-sdd-on-l2-contracts`（含
  doctrine 待補的一行：L2 可被任何 orchestrator 複用、entry gate 只治理 mode 本身）。
