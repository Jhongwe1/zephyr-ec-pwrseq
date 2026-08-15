# R04 — 故障注入測試

> **狀態：地基已就緒（twister 跑得動），故障矩陣本身在 P3 撰寫。**

---

## 現在就能跑

```bash
make test
```

```
INFO - 1 of 1 executed test configurations passed (100.00%)
```

目前只有一個 `tests/smoke`——**管線測試**。它存在的目的是「用無聊的理由失敗」，
好讓「工具鏈壞了」跟「我的時序引擎寫錯了」可以分開。
它實際檢查的是 `k_cycle_get_32()` 跟 `k_uptime_get()` 兩個時鐘互相吻合，
因為這個專案之後每一個時間數字都是從前者推導出來的。

---

## P3 要建的東西

### 核心概念：`native_sim` + `gpio_emul`

`native_sim` 把韌體編成一支普通的 Linux 執行檔，`gpio_emul` 提供軟體模擬的 GPIO。
測試自己去驅動 PG 腳位 —— **這就是軟體版的電源軌模型**。
換一份 overlay，**同一支時序引擎**就能在 CI 上跑，一行 C 都不用改。

```c
static void model_pg(int rail, bool assert_it)
{
    /* gpio_emul 的 API 吃 port + pin，沒有 _dt 便利版 */
    gpio_emul_input_set(rails[rail].pg.port, rails[rail].pg.pin, assert_it);
}
```

### 故障矩陣

| ID | 故障 | 觸發條件 | 正確反應 |
|:--:|---|---|---|
| **F1** | PG 逾時 | `EN` 拉高後 `pg-timeout-ms` 內 PG 未到 | 反序關閉**含失敗軌在內**的所有已開軌 → `ST_FAULT` |
| **F2** | PG 中途掉落 | `ST_ON` 期間任一 PG 由高變低 | **立即**緊急反序關閉（不等、不重試） |
| **F3** | PG 抖動 | PG 在 `pg-debounce-us` 內反覆變化 | 去彈跳後才採信 |
| **F4** | PG 已為高 | 拉 `EN` **之前** PG 就是高 | **判為故障**，不得視為成功 |
| **F5** | 使用者中止 | 時序進行中按住 `PWR_BTN#` ≥ 4 s | 立即強制關機（`ST_ROOT` 處理） |

**F4 是這張矩陣裡最容易被整格漏掉的一個。** 只寫「拉 EN → 等 PG 變高」的實作，會讓三種情況
（上次沒關乾淨 / PG 短路到 VCC / 監控 IC 壞了）**全部靜默通過**，
然後在一條實際上不受控的電源軌上繼續開機。

**每一個測試的結尾都要驗四條不變式**（見 [README §2](../../README.md#invariants)）。

### 目標
`F1–F5 × 3 條軌` ≥ 15 個測試，CI 全綠。

---

## 完成標準（DoD）

- [ ] `west twister -T tests/ -p native_sim` 全綠
- [ ] ≥15 個故障注入測試，涵蓋 F1–F4 × 全部軌
- [ ] 每個測試驗 INV2 + INV3
- [ ] GitHub Actions 綠 badge 在 README 頂部
