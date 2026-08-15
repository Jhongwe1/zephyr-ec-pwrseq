# R06 — 證據流水線（`make evidence`）

> **狀態：尚未撰寫。P4 補完（第一批擷取存進 `captures/` 之後）。**

---

## 這一步在解什麼問題

| 做法 | 證據等級 | 看的人心裡的疑問 |
|---|:--:|---|
| PulseView 截圖貼 README | T1（弱） | 「這數字怎麼標的？縮放對嗎？」 |
| **原始 `.sr` + VCD + 腳本 + 自動產圖** | **T1 + T2** | **（沒有疑問，他可以自己跑）** |

**但流水線最大的受益者其實是你自己。**
你會重接十幾次線、改二十次時序參數。每次都手動量、手動標、手動貼圖，你會放棄。
**腳本化把重新量測的成本從 30 分鐘壓到 30 秒——這才是你真的會做到 100 次量測的原因。**

---

## 大綱

```
captures/*.sr                     原始擷取（sigrok）
   │  sigrok-cli -O vcd
   ▼
captures/*.vcd                    邊緣式編碼，幾百行而不是一億列
   │  tools/annotate.py
   ├──▶ docs/measurements.md      自動產生的量測表
   ├──▶ docs/img/seq_*.png        標註好的時序圖
   └──▶ UART 解碼結果，時間對齊
```

- [ ] `tools/capture.sh` — sigrok 擷取（Profile A / B）
- [ ] `tools/annotate.py` — VCD → 量測表 + 標註波形圖
- [ ] `tools/boot_stats.py` — 100 次開機的 `t_PG` 分布與直方圖
- [ ] `docs/timing_budget.md` — **PG 逾時為什麼是這個數字**（量測 → 推導 → 兩端代價）
- [ ] `make evidence` — 一行重現全部

---

## README 裡要寫的那句話

> All figures and timing numbers in this README are regenerated from the raw
> captures in `captures/` by `make evidence`. Nothing is hand-drawn or
> hand-measured.

**這一句話把所有的圖從「宣稱」變成「可驗證」。**

---

## `docs/timing_budget.md` 是全案技術密度最高的一份產出

它的骨架：

1. **量測**：100 次開機的 `t_PG` 分布（平均、σ、最小、最大）
2. **與理論不符**：實測比理論小 → 找根因 → 反推驗證
3. **決策**：逾時怎麼選，為什麼
4. **兩端的代價**：設太短 → 正常但較慢的電源被誤判，**開不了機**（客訴最糟型）；
   設太長 → 真短路時大電流多流數十毫秒（但真短路由硬體 OCP 在 µs~ms 級處理，
   EC 的 PG 逾時是次要保護）→ **所以偏向設長是對的**
5. **我沒做到的**：沒在溫度極限量過、沒量過輸入電壓變動的影響……

**量測 → 與理論不符 → 找根因 → 反推驗證 → 做決策 → 講兩端代價 → 說明偏向與理由
→ 誠實列出沒做的。** 這一串就是一個工程決策的完整形狀；
少掉其中任何一節，剩下的就只是一個沒有來歷的常數。

---

## 完成標準（DoD）

- [ ] `make evidence` 從 `captures/` 重新產生所有圖表與數字
- [ ] `docs/timing_budget.md` 有 100 次開機統計與逾時推導
- [ ] 韌體時間戳 × 邏輯分析儀交叉驗證表（**真板子上量的**）
- [ ] README §5 填滿
