# R03 — 日常開發迴圈

> **狀態：部分完成。** 沒有硬體的部分現在就能用；燒錄與除錯的部分 W02 板到貨後補完。

---

## 沒有硬體時（現在就能做，涵蓋本專案約六成的工作）

```bash
ecws                    # 啟用 venv + cd 到 repo
# ... 改程式 ...
make test               # 故障注入測試（native_sim）
make run                # 實際跑起來看 log
git add -p              # 分段檢查自己到底改了什麼
git commit              # 訊息寫「為什麼」，不是「改了什麼」
```

**為什麼 `git add -p` 而不是 `git add -A`：**
它會把你的變更一段一段秀出來要你確認。這強迫你在 commit 前**再讀一次自己的 diff**，
順手抓到忘了刪的 debug print 和不小心改到的東西。
它也自然會讓 commit 變小、變得有主題——而 commit 歷史是這個專案唯一無法事後偽造的東西。

---

## 改了 devicetree 之後（鐵律）

```bash
make dts
```

**你寫的東西 ≠ build 真正用的東西。** 中間隔著 overlay 檔名比對、`status` 屬性、
`compatible` 比對、binding 有沒有被找到。**只有 `build/<board>/zephyr/zephyr.dts` 是事實。**

這個習慣要從 W02 第一次寫 overlay 就養成。省下來的時間以小時計。

---

## commit 訊息的寫法

repo 目標是 30–80 個**看得出過程**的 commit。不要為湊數造假——真實開發本來就會產生這麼多。

```
feat: add ec,power-rail DT binding and sequencer skeleton
fix: DT_FOREACH_CHILD order was reversed, rails powered up backwards
wip: PG timeout fires but shutdown order is wrong
fix: power_down(i-1) skipped the failing rail's own EN
feat: add pre-EN PG check (F4) -- stuck-high PG was silently passing
test: add fault matrix F1 x 3 rails on native_sim
perf: measured t_PG 9.43ms vs calculated 12.0ms -- see LOG 2026-09-14
```

**`wip:` 和 `fix:` 是資產不是負債。** 一次 commit 全上傳、訊息寫 `Initial commit`，
在看的人眼裡等同「抄的」或「AI 生的」。

---

## 有硬體之後（W02 補完）

- [ ] `make flash` — 燒錄流程與常見失敗
- [ ] `make debug` — GDB 下中斷點、看暫存器。**電源時序是時序敏感的程式，沒有除錯器會瞎掉**
- [ ] UART console 怎麼接、怎麼開（`115200 8N1`，記得共地）
- [ ] 「改一行 → 看到結果」的最短路徑要壓到幾秒
