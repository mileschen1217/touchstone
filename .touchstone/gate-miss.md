# gate-miss ledger — 一行一事件,當下記錄

格式(六欄原語;severity ∈ {C,H,M,L} 與 gate stamp 同詞彙;欄內自由文避用 `|`,以 `/` 代):
`date | artifact | 事件 | 應然 locus | 實然 locus | severity`

- 2026-07-18 | PROPOSAL.md(v2 蒸餾提案) | 未逐支盤點 .touchstone/checker/ 的 16 支 checker,「自我警察全刪」以偏概全(原 class 註記:missing-AC/盤點範圍缺口) | 應然:explore(machinery 盤點)/ PROPOSAL 審查 | 實然:human@assay readiness ask | M
- 2026-07-18 | check-local-artifact-refs.sh | 豁免路徑仍指 B3 已刪的 scripts/tests/,smoke fixtures 新家 scripts/tests-smoke/ 未涵蓋,ship push 被誤擋(原 class 註記:dead-ref/rename 未同步) | 應然:B3 rename 同步 / B4 batch review(dead-ref class) | 實然:pre-push@ship | M
- 2026-07-19 | anvil 終端程序(P2 final-accept 攤牌) | 攤 final-accept 包時未先跑 post-build pair(explainer+quiz),違反「quiz 未過不 approve」 | 應然:anvil Terminal 應指回 phase-ship.md 的 pair 義務 | 實然:human@final-accept 追問 | M
