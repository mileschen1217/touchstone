# 0039 — eval 機制形態:輕量計量 + 產物存活兩軸,無自動化管線

- **Status:** accepted
- **Date:** 2026-07-18
- **Deciders:** miles
- **Triggered by:** `/touchstone:assay`(v2-dilute epic,record: `.touchstone/epics/v2-dilute/assay-2026-07-18-touchstone-v2-eval-and-dilution.md`)
- **Related ADRs:** 0028(insight/proposal 層,本 ADR 廢其管線)、0032(size ratchet 與 74% human-catch 數據)、0009(evidence-honesty,derived-not-stored 同源)
- **Flip-trigger:** 手寫 stamp + gate-miss 跑滿一個完整 epic 後,當下捕捉率明顯低於 ~80%,或 epic-close reckon 讀不出可裁決的訊號 → 回訪本決定(考慮最小機械輔助,仍受 R2 準入)。看的人:epic close 的裁決臂執行者。
- **Bet-owner:** miles
- **Assumptions:** ①重要的 pain 會重複發生,漏記單次不漏 class(soft capture 足夠的前提)②eval 資料的消費端是 threshold/trend 型,容忍 ~20% 漏記 ③conductor 的 precedent/constants 迴圈持續存在,執行層經濟不需 touchstone 重建

## Context

insight v1(自動 sweep → LLM 分類 → 提案 → 安裝 checker)實測失敗:0.6% hit rate、一次 sweep 1.14M tokens 換 1 個被 defer 的提案、~2.1k 行管線維護稅;根因是「事後考古」——74% gate-miss 本來就是人當場抓到的(ADR-0032),機器在重新推導人已知的事。同時整個 suite 缺 fitness function:沒有任何機制回答「這個 gate 付租了嗎」,演化退化為單向增生。v2 需要一個防復發的 eval 機制,且必須 generic 跨 artifact 型(source code、spec、skill prose)。

## Decision

我們採**兩軸輕量 eval,零自動化管線**:

1. **機制軸(attribution)**:每次 gate 運行結束,gate skill 程序的最後一步 append 一行 stamp(發現數×嚴重度、修復數、粗成本)到 `.touchstone/eval/stamps.jsonl`。
2. **產物軸(ground truth)**:使用點失敗事件一行記錄,統一原語 `date | artifact | 事件 | 應然 locus | 實然 locus | severity`——gate-miss.md(人抓漏當下)、deviation log(build 期)、quiz-miss(post-build pair)都是此原語的實例。品質在使用點量測,不在生產點宣稱;prose 的使用即測試(invoke 即 eval run:人工糾正、誤讀、out-of-file lookup、activation miss)。
3. **裁決與提案**:epic close 人工讀兩軸資料,一頁 reckon,產出雙向提案(keep / adjust / kill / 新規則);任何機械化安裝受 R2 準入(≥3 筆同 class pain + prose 先行一個 epic)。
4. **capture 為 soft**:目標 ~80% 當下捕捉 + close 時固定問句「這個 epic 你抓到哪些 gates 沒抓到的?」補漏;不宣稱完備。
5. **邊界**:touchstone 只量自身 review/contract gates 的 yield;派工經濟(tokens/tier)歸 conductor 的 precedent/constants 迴圈,不重建。

eval 機制自身受 R2:先以 prose 程序 + 手寫記錄跑滿 ≥1 個 epic,才允許任何 script 化。

## Alternatives Considered

- **(a) 純人工定期 review**:零機制,但無資料積累,退化為印象分——落選。
- **(c) 自動化 eval harness(golden tasks + 定期跑)**:涓流訊號配工業管線,正是 insight v1 的復發路徑——落選。
- **(B-2 單用)只量產物不量機制**:知道爛、不知道哪爛(無 attribution)——併入而非單用。
- **cross-provider-architect 批判派工**:省略。理由:本 fork 的裁定已有 v1 的實測失敗資料(0.6%/1.14M tokens)與 human bet-owner ruling 支撐,批判評審的邊際價值低於成本。

## Consequences

- 變容易:刪除 ~2.1k 行 insight 管線與其併發防護;eval 資料可直接引用 conductor journal/precedent;review 節奏(per-commit 移除)成為第一個受測旋鈕,由資料而非教條決定復職。
- 變困難:capture 依賴 gate 程序自律與人的當下配合;資料在首個 epic 前是空的,早期裁決仍靠判斷。
- 新義務:每個 v2 gate skill 程序尾必含 stamp 步;epic close 程序含固定補漏問句與一頁 reckon;flip-trigger 由裁決臂執行者盯。
