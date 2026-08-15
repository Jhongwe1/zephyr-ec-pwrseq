# RUNBOOK

> **這份文件存在的唯一理由：**
> 讓「三個月後的我」或「一個完全沒碰過這個題目的人」，clone 下這個 repo 之後，
> **不用問任何人**，就能把它跑起來、量出一樣的結果。
>
> 如果你照著做卻卡住了，那是這份文件的 bug，不是你的問題 —— 請把它修好再往下走。

*The runbooks are written in Traditional Chinese, the author's working language.
English readers: [README.md](README.md) is the project overview, `make help` is
the command surface, and all code comments, devicetree bindings and commit
messages are in English.*

---

## 我對這份 runbook 的四條寫作規則

1. **每一步都要有「你應該看到什麼」。** 沒有預期輸出的步驟不算步驟——你無法判斷自己成功了沒。
2. **每一個會失敗的地方，都要寫出失敗長什麼樣子。** 錯誤訊息就是索引鍵。
3. **不准寫「顯然」「很簡單」「應該就可以」。** 三個月後的我不記得任何事，高中生更沒有義務知道。
4. **指令一律整段可複製貼上。** 需要你手動改的地方用 `<這樣>` 標出來。

---

## 0. 三十秒搞懂這個 repo

筆電裡有一顆一直醒著的小晶片叫 **EC（Embedded Controller）**，負責電源、風扇、電池、鍵盤。
它最核心的職責是**電源時序**：開機時十幾條電源軌不能同時打開，必須照晶片廠規定的順序一條一條開，
每開一條要等它的 **PG（Power Good）** 訊號確認起來了才能開下一條。順序錯、或某條沒起來還硬往下開，
輕則開不了機，重則燒晶片。

**這個 repo 是那顆 EC 的韌體**，跑在一塊 STM32F411 開發板上，並且：

- 電源軌的**順序與時序寫在 Devicetree**（資料），C 那邊是一支泛用引擎 → 加一條軌不改一行 C
- 狀態機用 Zephyr 官方的 **SMF**（階層式），跑 `G3 → S5 → S3 → S0 → S0ix`
- 故障（PG 不來 / PG 中途掉 / PG 抖動 / PG 一開始就是高…）寫成**自動化測試**，
  同時跑在 **native_sim（CI，零硬體）** 與**實體板**上
- 最後用 8 通道邏輯分析儀把時序**量出來**，其中一張圖的 CH7 是解碼出來的韌體 UART log，
  **跟波形在同一條時間軸上**

詳細設計：[README.md](README.md)

---

## 1. 你現在在哪（專案狀態）

| 階段 | 內容 | 狀態 | 完成日 |
|---|---|:--:|---|
| **P0** | 環境 + 工具鏈 + repo 骨架 | ✅ **完成** | 2026-08-12 |
| **P1** | DT 驅動時序引擎，三軌依序上電 | ⬜ **下一個** | — |
| P2 | F1–F4 故障保護 + 反序關閉 + 四不變式 + SMF 階層 | ⬜ 未開始 | — |
| P3 | native_sim + gpio_emul + ztest 故障矩陣 + CI | 🟡 地基已就緒 | — |
| P4 | 邏輯分析儀量測 + 標註 + 證據流水線 | ⬜ 未開始 | — |
| P5 | 加值（SBS 電池 / ACPI EC / HIL）擇一 | ⬜ 未開始 | — |
| P6 | 上游 PR 到 Zephyr 主線 | ⬜ 未開始 | — |

**階段是有順序的，但這張表不填預定日期**——日期是做完之後才補上去的。
預定日期不是事實，而這份文件裡只放事實。P1–P6 是這個 repo 對外的統一階段編號，
README、程式碼註解、TODO 都用同一套。

**P0 實際驗收結果（2026-08-12）**

| 驗收項 | 結果 |
|---|---|
| ARM 工具鏈編得出韌體 | ✅ `blackpill_f411ce/stm32f411xe`，FLASH 27728 B / 512 KB |
| `native_sim` 編得出且跑得起來 | ✅ 印出 banner |
| 本 repo 的測試在 twister 下全綠 | ✅ 1/1 passed |
| 環境自檢 | ✅ `make doctor` 全 PASS |
| 實體板燒錄（Smoke 3） | ⬜ **板未到貨**，順延至到貨後 |

---

## 2. 我想做什麼？（選一條路）

| 我想… | 去哪 | 狀態 |
|---|---|:--:|
| **我已經有 Linux / WSL，直接跑起來看看** | [R00 快速開始](docs/runbook/R00-quickstart.md) | ✅ 20 min |
| **我的電腦什麼都沒有，從零開始** | [R01 環境建置](docs/runbook/R01-environment.md) | ✅ 60–90 min |
| **接硬體、接線、拍照** | [R02 硬體](docs/runbook/R02-hardware.md) | 板到貨後補 |
| **每天開發的固定循環** | [R03 日常迴圈](docs/runbook/R03-daily-loop.md) | ✅ 部分完成 |
| **跑故障注入測試** | [R04 測試](docs/runbook/R04-testing.md) | P3 補 |
| **接邏輯分析儀量波形** | [R05 量測](docs/runbook/R05-measurement.md) | P4 補 |
| **一鍵重現所有圖表與數字** | [R06 證據流水線](docs/runbook/R06-evidence.md) | P4 補 |
| **壞掉了 / 看到看不懂的錯誤** | [R99 疑難排解](docs/runbook/R99-troubleshooting.md) | ✅ 滾動更新 |

---

## 3. 三個你每天都會用到的指令

在 repo 目錄下：

```bash
make doctor    # 環境自檢。程式壞掉之前，先確認不是環境壞掉
make test      # 故障注入測試（native_sim，不需要任何硬體）
make build     # 編譯給實體板的韌體
```

`make` 不帶參數會列出全部指令。

> **鐵律：在你懷疑自己的程式碼之前，先跑 `make doctor`。**
> 嵌入式專案裡大約一半的「我的程式壞了」其實是「我的環境壞了」，
> 而這兩者對新手來說錯誤訊息長得一模一樣。`doctor` 用十秒鐘把它們分開。

---

## 4. 這個 repo 的檔案在哪、為什麼在那裡

```
zephyr-ec-pwrseq/
├── RUNBOOK.md              ← 你正在讀的這份
├── README.md               ← 對外的專案說明（英文）
├── LOG.md                  ← 工程日誌。現象→假設→驗證→根因→教訓
│
├── west.yml                ← 釘住 Zephyr 版本。「可重現」的來源
├── Makefile                ← 所有指令的正門
├── CMakeLists.txt / prj.conf
│
├── boards/                 ← 每塊板子一份 overlay
│   ├── blackpill_f411ce.overlay   （P1）真 GPIO
│   └── native_sim.overlay         （P3）gpio_emul，同構節點
│
├── dts/bindings/power/     ← 自訂 devicetree binding（P1）
│                             這裡定義「一條電源軌」有哪些屬性
│
├── src/                    ← 韌體
├── include/ec/             ← 對外標頭
│
├── tests/                  ← ztest 測試
│   └── smoke/              ← 管線測試：確認工具鏈本身沒壞
│
├── tools/
│   ├── bootstrap.sh        ← 一鍵建環境（R01 就是它的說明書）
│   └── doctor.sh           ← 環境自檢
│
├── docs/
│   ├── runbook/            ← 所有 runbook
│   ├── hardware/           ← BOM、接線圖、接線照片
│   └── img/                ← 架構圖、波形圖
│
└── captures/               ← 邏輯分析儀原始擷取檔（不要刪，這是證據）
```

### 為什麼 repo 的「上一層」也很重要

這個 repo 是它自己 west workspace 的 **manifest repo**。實際磁碟長這樣：

```
ec-ws/                      ← workspace 頂層
├── .west/                  ← west init 產生
├── zephyr-ec-pwrseq/       ← 這個 repo（也就是應用程式本身）
├── zephyr/                 ← west update 抓下來的，版本由 west.yml 決定
├── modules/                ← 同上
└── .venv/                  ← Python 虛擬環境，west 裝在裡面
```

**為什麼這樣做：** Zephyr 變成「這個專案的相依套件」，而不是反過來。
所以 `git clone` + `west init -l .` + `west update` 會得到**跟我量測時完全相同的那棵樹**。
這是 README 裡每一個時間數字能被別人驗證的前提。

---

## 5. 我在這個專案裡對自己的約束

這幾條是刻意的，不是隨便寫的。少了任何一條，這個 repo 就退回成「一個會動的 demo」——
能跑，但沒有任何一個數字經得起追問：

1. **時序參數一律進 Devicetree，不准寫死在 C。** 加一條軌只能改 DTS。
2. **改了 overlay 就一定要看 `make dts`**（`build/<board>/zephyr/zephyr.dts`）。
   你寫的東西和 build 真正用的東西是兩件事。
3. **每個等待都要有逾時。** `k_sem_take(..., K_FOREVER)` 在這個 repo 是禁用的——
   沒有逾時等於系統可以永遠卡在「一半通電」。
4. **量測數字一律由腳本產生**（`make evidence`），不准手動標、手動貼圖。
5. **每天寫 LOG.md。** 格式：現象 → 假設 → 驗證 → 根因 → 教訓。
6. **要講出口的版本號／日期／issue 狀態，講之前自己再查一次官方來源。**
   講錯一個可查證的事實，整條可信度就崩了。

---

## 6. 出事的時候

1. `make doctor` —— 先排除環境
2. [R99 疑難排解](docs/runbook/R99-troubleshooting.md) —— **用錯誤訊息當關鍵字搜尋這份文件**
3. 還是不行 → 把完整錯誤訊息貼進 `LOG.md`，標記 `[unsolved]`，先做別的
4. 解開了 → 回頭補完 LOG，並且問自己：
   **「這是我的問題，還是文件的問題？」** 如果是後者，標 `[upstream candidate]`——
   那是 P6 挑上游 PR 題目時的清單。
