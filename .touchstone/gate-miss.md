# gate-miss ledger — 一行一事件,當下記錄

格式(六欄原語;severity ∈ {C,H,M,L} 與 gate stamp 同詞彙;欄內自由文避用 `|`,以 `/` 代):
`date | artifact | 事件 | 應然 locus | 實然 locus | severity`

- 2026-07-18 | PROPOSAL.md(v2 蒸餾提案) | 未逐支盤點 .touchstone/checker/ 的 16 支 checker,「自我警察全刪」以偏概全(原 class 註記:missing-AC/盤點範圍缺口) | 應然:explore(machinery 盤點)/ PROPOSAL 審查 | 實然:human@assay readiness ask | M
- 2026-07-18 | check-local-artifact-refs.sh | 豁免路徑仍指 B3 已刪的 scripts/tests/,smoke fixtures 新家 scripts/tests-smoke/ 未涵蓋,ship push 被誤擋(原 class 註記:dead-ref/rename 未同步) | 應然:B3 rename 同步 / B4 batch review(dead-ref class) | 實然:pre-push@ship | M
- 2026-07-19 | anvil 終端程序(P2 final-accept 攤牌) | 攤 final-accept 包時未先跑 post-build pair(explainer+quiz),違反「quiz 未過不 approve」 | 應然:anvil Terminal 應指回 phase-ship.md 的 pair 義務 | 實然:human@final-accept 追問 | M
- 2026-07-20 | phase3-batch2-explainer.md §2 | quiz Q3 答「有 -o 檔 => ok」漏空檔 case——PARTIAL 三分邊界以連續散文一句帶過,空檔分支被壓縮進「缺失或空」未獨立成列(原 class:dense single-clause compression) | 應然:explainer 邊界條列化,每分支獨立一行 | 實然:human@quiz Q3 | L
- 2026-07-20 | 2026-07-19-cross-provider-slim-design.md ↔ ADR-0020 pt2 | spec 反轉 standing Accepted ADR(composite pair 不合併)未 supersede,鏈上五道 gate(challenge/design-review×2/batch/Stage3)零命中(class:standing-ADR contradiction 無 sweep lens——cold reviewer 沒被指去看 ADR corpus) | 應然:design-review doc lens(i) ADR-consistency sweep(本日已裝) | 實然:AC-9(b) fresh-session composite review@post-ship | H
