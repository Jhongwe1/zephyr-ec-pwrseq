# LOG

工程日誌。每天 5 分鐘，格式固定：**現象 → 假設 → 驗證 → 根因 → 教訓**。

**這份檔案不是給別人看的，是給三個月後的我看的。** 它同時是面試時
「你怎麼 debug？」這一題的素材庫——那一題問的不是結果，是**你怎麼縮小範圍**。

標記：
- `[decision]` 做了一個之後會被問「為什麼」的決定
- `[upstream candidate]` 這個坑可能是官方文件／程式碼的問題，不是我的問題（W09 選 PR 題目時回來看）
- `[unsolved]` 還沒解，先繞過

---

## 2026-08-11（二）— 起跑

**✍️ 這一則要用你自己的話重寫。** 下面是根據計畫整理的骨架，
不要照抄——面試講的是你的理由，不是別人的理由。

我選了「Zephyr 筆電 EC 電源時序狀態機」這一題，理由是：

1. 它是我評估過的題目裡，**唯一會產生物理波形**的。2026 年 README 和架構圖
   幾秒鐘就能生出來，但帶時間標尺的邏輯分析儀擷取生不出來。
2. 它同時能打到**第三方背書**（Zephyr 走 GitHub PR + DCO，沒有 CLA 等待期）
   和**物理量測**兩種完全不同的信任來源。
3. 台灣 NB 廠量產在用的 ITE IT8XXX2 與 Nuvoton NPCX，在 Zephyr 主線就有
   in-tree SoC port。我練的東西可以遷移，不是玩具。

**我知道它會怎麼死（六種死法裡我最可能中的兩種）：**

- **死法 1：停在 T4。** README 漂亮、架構圖精緻、話術流暢，但**沒有一張自己量的波形**。
  寫 README 有即時成就感而且 AI 幫得上忙；接線、量波形、寫量測腳本痛苦緩慢又沒回饋——
  **這正是它們值錢的原因**。防法：W06 結束時手上沒有一張自己量的波形，就停掉所有其他工作。
- **死法 5：基本功被排擠。** 專案做到很深，結果線上測驗 45 分鐘兩題 C 沒寫完。
  **關卡 1 過不了，專案連被提到的機會都沒有。** 防法：每週 7 小時基本功不可挪用。

---

## 2026-08-12（三）— 環境建置一次到底

今天把 P0 做完了。原計畫是分散在週三～週日，實際一天做完，因為 WSL2 Ubuntu 24.04
已經裝好，省掉了最花時間的一步。

**結果：**

| 驗收 | 結果 |
|---|---|
| Smoke 1：ARM 工具鏈編 blinky | ✅ `blackpill_f411ce/stm32f411xe`，FLASH 17776 B / 512 KB |
| Smoke 2：`native_sim` 跑 hello_world | ✅ `Hello World! native_sim/native` |
| 本 repo 編譯（兩個目標） | ✅ ARM 27728 B / 512 KB；native_sim 可執行 |
| 本 repo 測試（twister） | ✅ 1/1 passed |
| Smoke 3：實體板燒錄 | ⬜ **板未到貨**，順延 W02（依計畫，不算失敗） |

環境版本：Ubuntu 24.04.4 / CMake 3.28.3 / Python 3.12.3 / DTC 1.7.0 /
west v1.5.0 / Zephyr **4.4.2** / Zephyr SDK **1.0.1**。
磁碟佔用：workspace 6.5 GB + SDK 2.0 GB = 8.8 GB。

---

### `[decision]` Zephyr 釘 v4.4.2，不是計畫寫的 v4.4.0

查 tag 列表時發現 4.4 這條線上已經有 `v4.4.1`、`v4.4.2`。

**決定取 v4.4.2。** 理由：patch release 只修 bug 不改 API，取最新的沒有成本，
卻白拿一堆修正；而且「為什麼你停在 `.0`，`.2` 都出了」是我答不出來會很難看的問題。
計畫裡所有關於「Zephyr 4.4」的說法（第一個支援 SDK 1.0 的版本等）全部仍然成立。

**什麼時候該再動這個釘子：** 只在**次版本**（4.5、4.6…）出來時重新評估，因為那些可能改 API。
改的時候要單獨一個 commit，理由寫在 message 裡，`make test` 跟 `make build` 都要保持綠的。

---

### `[decision]` workspace 放在 WSL 的 `~/work/ec-ws`，不放 `/mnt/c/`

`/mnt/c/` 是 WSL 存取 Windows 檔案系統的橋接層，每個檔案操作都要跨一層轉譯。
Zephyr 一次乾淨編譯要碰上千個檔案，放那裡會慢好幾倍。13 週幾百次編譯，
累積起來是好幾個小時。

副作用：**用 Windows 端的編輯器改 WSL 裡的檔案，會弄掉「可執行」權限**（今天實際踩到，見下）。
解法是用 VS Code 的 WSL 模式編輯。`make doctor` 兩件事都會檢查。

---

### `[decision]` repo 做成 west manifest repo（不是把專案丟進 zephyrproject 裡）

計畫本來是先建 `~/zephyrproject` 標準工作區，之後再改成 manifest repo。
直接一步到位比較好，因為：

1. **可重現性從第一個 commit 就成立**：`git clone` + `west init -l .` + `west update`
   會得到跟我量測時完全相同的那棵樹。這是 README 裡每個時間數字能被別人驗證的前提。
2. runbook 只有**一條路徑**，不會有「舊做法」和「新做法」兩套說明。
3. CI 用的是跟開發機一模一樣的初始化流程。

---

### 🐛 `grep -q` 在 `pipefail` 腳本裡會把自己的結果反過來

**今天最值得記的一個。**

- **現象：** `make doctor` 回報 `WARN arm-zephyr-eabi toolchain not found`，
  但是 `make build` 明明成功編出了 ARM 韌體。**兩件事不可能同時為真。**

- **假設：**
  1. SDK 其實沒裝好，ARM build 是用別的編譯器過的
  2. `west sdk list` 的輸出格式跟我 grep 的字串對不上
  3. 檢查的邏輯本身有問題

- **先驗哪個：** 選 (2)，因為最便宜——直接把 `west sdk list` 的原始輸出印出來看就好，
  三十秒。驗 (1) 要去翻 build log 找編譯器路徑，慢得多。

- **驗證：** 輸出裡明明白白有
  ```
  gnu-installed-toolchains:
    - arm-zephyr-eabi
  ```
  字串完全對得上。→ **排除 (1) 和 (2)，只剩 (3)。**

- **根因：** 檢查寫成 `west sdk list | grep -q 'arm-zephyr-eabi'`。
  `grep -q` **找到第一個符合就立刻結束並關閉管線**，上游的 `west` 收到 `SIGPIPE` 死掉，
  而腳本開頭有 `set -o pipefail`，於是整條管線被判定為失敗。
  **結果就是：工具鏈存在的時候，檢查回報它不存在。**

- **解法：** 先接到變數再比對，不要用管線。
  ```bash
  SDK_LIST="$(west sdk list 2>/dev/null || true)"
  case "$SDK_LIST" in *arm-zephyr-eabi*) ... ;; esac
  ```
  同一支腳本裡的 CRLF 檢查也中了同一招，而且方向更糟——那邊是**真的有 CRLF 時反而檢查不出來**。
  `bootstrap.sh` 判斷「SDK 是否已安裝」也中招，所以它每次重跑都會重新下載一次 SDK。
  **一個 bug，三個現場。**

- **教訓：**
  1. **兩件互相矛盾的事實同時出現時，先懷疑「觀測工具」，不要先懷疑「被觀測的東西」。**
     這次是我的檢查腳本在說謊，不是環境有問題。
  2. `... | grep -q` 在有 `pipefail` 的腳本裡是不安全的。這個 bug 在沒有 `pipefail`
     的 shell 裡完全正常，所以隨手測試永遠測不出來。
  3. **一個會說謊的自檢工具，比沒有自檢工具更糟**——它會讓你去修根本沒壞的東西。

---

### 淺層 clone 沒有 tag，所以 `git describe` 驗不了版本

- **現象：** `make doctor` 說 `zephyr tree is at 'dccb0959', west.yml pins 'v4.4.2'`，
  但 `zephyr/VERSION` 明明寫著 4.4.2。
- **根因：** 為了省時間用了 `west update --narrow -o=--depth=1`（6.5 GB / 十幾分鐘，
  完整歷史是 2.5 GB 的 git 物件 + 更久）。**淺層抓取不會抓 tag ref**，
  所以 `git describe --tags` 回 `No names found`，程式退回用 commit SHA 去比對 `v4.4.2`，
  當然對不上。
- **解法：** 改成比對 `zephyr/VERSION` 檔案——它是從 tag 產生的，而且淺層 clone 裡也有。
- **教訓：** 為了速度做的取捨（淺層 clone）會在**跟速度無關的地方**冒出來（版本驗證）。
  取捨要記下來，不然三個月後看到這個錯誤會以為是環境壞了。
  真的需要完整歷史時（W09/W10 做上游貢獻要 `git blame`）：
  `cd ~/work/ec-ws/zephyr && git fetch --unshallow`。

---

### 從 Windows 寫入 WSL 的檔案會掉掉可執行權限

- **現象：** 明明 `chmod +x` 過的 `tools/doctor.sh`，改完內容之後變成 `Permission denied`。
- **根因：** 從 Windows 端（`\\wsl.localhost\...`）寫入時，Windows 檔案系統沒有 Unix
  執行位元的概念，寫入會把 mode 重設成 644。
- **解法：** `chmod +x tools/*.sh`；並且用 `git update-index --chmod=+x` 讓 git 記住，
  否則別人 clone 下來一樣不能執行。長期解法是改用 VS Code 的 WSL 模式編輯。
- **教訓：** 這個錯誤訊息（`Permission denied`）跟真正的原因（跨檔案系統寫入）
  一點關係都看不出來。**這種「訊息和原因對不起來」的坑，就是最該寫進 runbook 的東西。**
  已經加進 `doctor.sh` 的檢查項與 R99。

---

### `[decision]` BOM 少了一樣東西：USB 轉 TTL 串口模組

整理採購清單時發現原 BOM 沒有這個，而**沒有它 W02 會卡住**：

1. 便宜的 ST-Link V2 克隆版**沒有虛擬序列埠（VCP）**，只能燒錄不能看 log。
   沒有 log 就沒有 `printk`、沒有各軌的 `t_PG` 輸出，程式跑起來是個黑盒子。
2. 更關鍵的是**架構上的理由**：W06 的主圖（Profile B）要把 **UART1_TX（PA9）
   接到邏輯分析儀的第 7 通道**，讓 PulseView 把韌體 log 解碼出來、疊在波形同一條時間軸上。
   這代表 console **必須是硬體 UART**，不能用板子自己的 USB CDC——
   USB CDC 沒有可以夾探棒的實體訊號線。

所以它不是「方便的話買一下」，是**設計上必要**。已加進採購清單並註明理由。

---

### `[decision]` 燒錄路線：先走 Windows 端，usbipd 之後再說

WSL2 預設看不到 USB 裝置。兩條路：
- **(a)** `usbipd-win` 把 ST-Link 掛進 WSL，`west flash` 直通
- **(b)** WSL 負責編譯，Windows 端用 STM32CubeProgrammer 燒錄

**先走 (b)。** 理由：`usbipd` 是**可以延後的複雜度**。這一階段的目標是
「程式碼能編、能燒、會動」，不是「建出完美的工具鏈」。卡住了再回頭弄 (a)。

---

### 📌 給未來的自己：兩邊的 cycle counter 差 100 倍

`native_sim` 開機印出 `cycle counter: 1000000 Hz (1000 ns per tick)`，
也就是 **1 µs 解析度**。真板子上 STM32F411 會是約 100 MHz（約 10 ns）。

**W08 拿韌體時間戳跟邏輯分析儀（4 MHz → 250 ns）互相驗證的時候，這件事會變得很重要：**
在 `native_sim` 上，韌體側的解析度（1 µs）比儀器側（250 ns）**還粗**；
在真板子上則反過來（10 ns 遠細於 250 ns）。
**所以交叉驗證只有在真板子上做才有意義**，在 native_sim 上做那張比對表會得到誤導性的結論。

現在寫下來，免得 W08 的我對著一張對不上的表困惑兩小時。

---

## 待辦（滾動）

- [ ] **架構圖要自己畫**（手畫拍照或 draw.io 都可以，醜沒關係）→ `docs/img/architecture.*`
      README 目前用的是 ASCII 圖。自己畫的那張才是「這是真人做的」訊號。
- [ ] 板到貨 → Smoke 3（ST-Link 燒 blinky，PC13 閃）
- [ ] 板到貨先確認 KEY 鍵是不是真的在 PA0（板卡改版偶有差異）
- [ ] `[decision]` W06 要決定 log 用 deferred 還是 immediate 模式——
      會影響 UART log 與波形能不能對齊。理由已寫在 `prj.conf` 的 TODO
- [ ] W07 把 CI 的 container tag 釘死（目前是 `latest`，跟釘 Zephyr 的紀律不一致）
- [ ] W07 用 `name-allowlist` 精簡 west.yml 的 module 匯入，加快 CI
