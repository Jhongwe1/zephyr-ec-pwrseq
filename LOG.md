# LOG

工程日誌。每天 5 分鐘，格式固定：**現象 → 假設 → 驗證 → 根因 → 教訓**。

**這份檔案的第一讀者是三個月後的我。** 它記的不是「修好了什麼」——那個 commit 會記住——
而是**當時怎麼縮小範圍**：試過哪些假設、為什麼先驗那一個、哪一個是錯的。
推理過程沒被寫下來就會消失，然後同一個坑會再踩一次。

標記：
- `[decision]` 一個之後需要能講出理由的決定
- `[upstream candidate]` 這個坑可能是上游文件／程式碼的問題，不是我的問題（P6 選 PR 題目時回來看）
- `[unsolved]` 還沒解，先繞過

---

## 2026-08-11（二）— 起跑

**為什麼是「Zephyr 筆電 EC 電源時序狀態機」這個題目**——寫在第一天，
免得之後為了合理化已經做出來的東西而改口：

1. **它的主要產出是物理量測。** 這一題最後要拿出來的是帶時間標尺的邏輯分析儀擷取，
   一個只有在「線真的接起來、板子真的跑起來」之後才存在的東西。
2. **它有兩條互相獨立的驗證路徑**：`native_sim` 上的自動化故障注入（可重現、零硬體），
   以及實板上的物理量測。兩邊對不上的時候，**那個差值本身就是要解釋的現象**——
   這是單靠模擬或單靠實測都拿不到的資訊。
3. **它可以遷移。** 台灣 NB 廠量產在用的 ITE IT8XXX2 與 Nuvoton NPCX，
   在 Zephyr 主線就有 in-tree SoC port；時序表在 devicetree 的話，換板子只換 overlay。

**我知道這個題目最可能從哪裡爛掉：**

- **停在「寫得很好但沒量過」。** 寫文件有即時回饋；接線、量波形、寫量測腳本
  痛苦緩慢又沒回饋——**這正是後者才有資訊量的原因**。
  防線：在 P4 拿到第一張自己量的波形之前，README 裡所有時序數字都只是宣稱；
  真的排擠到了，寧可砍自動化測試也要先把線接起來。
- **時序參數偷偷回到 C 裡。** 只要有一次「先寫死、等一下再搬進 DTS」，
  「加一條軌不改一行 C」就不再是真的，而是一句沒有兌現的宣稱。
  防線：P1 的第一個測試就是驗證 DT 展開出來的 rail 順序符合預期。

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
| Smoke 3：實體板燒錄 | ⬜ **板未到貨**，順延到到貨後（依計畫，不算失敗） |

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
Zephyr 一次乾淨編譯要碰上千個檔案，放那裡會慢好幾倍。這個專案會編譯幾百次，
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
  真的需要完整歷史時（P6 做上游貢獻要 `git blame`）：
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

整理採購清單時發現原 BOM 沒有這個，而**沒有它，板子到貨那天就會卡住**：

1. 便宜的 ST-Link V2 克隆版**沒有虛擬序列埠（VCP）**，只能燒錄不能看 log。
   沒有 log 就沒有 `printk`、沒有各軌的 `t_PG` 輸出，程式跑起來是個黑盒子。
2. 更關鍵的是**架構上的理由**：P4 的主圖（Profile B）要把 **UART1_TX（PA9）
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

**P4 拿韌體時間戳跟邏輯分析儀（4 MHz → 250 ns）互相驗證的時候，這件事會變得很重要：**
在 `native_sim` 上，韌體側的解析度（1 µs）比儀器側（250 ns）**還粗**；
在真板子上則反過來（10 ns 遠細於 250 ns）。
**所以交叉驗證只有在真板子上做才有意義**，在 native_sim 上做那張比對表會得到誤導性的結論。

現在寫下來，免得 P4 的我對著一張對不上的表困惑兩小時。

---

### 🐛 第一次 CI 是紅的：`exit code 127`

推上 GitHub 後第一次 CI 跑完：`build-and-test` **全綠**（兩個目標都編過、
warnings-as-errors、twister 通過），但 `lint` **紅了**。

- **現象：** `shellcheck` 這一步 `Process completed with exit code 127`。
- **關鍵在於認得 127 這個數字：** shell 的 **127 = command not found**。
  （126 = 找到了但不能執行；1 = 程式自己回報失敗。）
  **所以這不是「我的腳本有問題」，是「shellcheck 這個程式不存在」。**
  如果沒認出 127，很容易一頭栽進去看 `tools/*.sh` 哪裡寫錯——那會白花一小時。
- **根因：** 我把 lint 放在 Zephyr 官方 CI 容器裡跑。那個容器有 `clang-format`
  （所以那一步是綠的），但**沒有 `shellcheck`**。我當初假設了「lint 工具都在同一個容器裡」，
  沒有驗證過。
- **解法：** 把 lint 拆成兩個 job：
  - `format` 留在 Zephyr 容器裡——**這是刻意的**，容器裡的 clang-format
    正是 Zephyr `.clang-format` 寫作時對應的版本，才不會因為版本差異跟上游吵架
  - `shellcheck` 改跑在乾淨的 ubuntu runner，而且先 `command -v` 檢查、
    沒有才 `apt-get install`（GitHub 的 runner image 有附，但那是 image 的性質、不是承諾）
- **順手修掉：** `actions/checkout@v4` / `upload-artifact@v4` 會噴 Node 20 已棄用的警告。
  查證後兩者的最新主版本都是 **v7**（moving tag 確認存在才改，沒有用猜的）。
- **教訓：**
  1. **exit code 是有語意的，先讀它再讀 log。** 127 直接把「環境問題」跟「程式問題」分開了——
     跟 `make doctor` 想做的事一模一樣。
  2. **本機全綠不等於 CI 會綠。** 我本機是 `apt install` 過 shellcheck 才跑的，
     而 CI 的容器是另一個世界。這正是 CI 存在的價值：它抓的就是「在我電腦上是好的」。
  3. **一個 job 混兩種工具，紅了看不出是誰的錯。** 拆開之後 job 名稱本身就是診斷。

---

## 待辦（滾動）

- [ ] **架構圖要自己畫**（手畫拍照或 draw.io 都可以，醜沒關係）→ `docs/img/architecture.*`
      README 目前用的是 ASCII 圖。自己畫的那張才是「這是真人做的」訊號。
- [ ] 板到貨 → Smoke 3（ST-Link 燒 blinky，PC13 閃）
- [ ] 板到貨先確認 KEY 鍵是不是真的在 PA0（板卡改版偶有差異）
- [ ] `[decision]` P4 之前要決定 log 用 deferred 還是 immediate 模式——
      會影響 UART log 與波形能不能對齊。理由已寫在 `prj.conf` 的 TODO
- [ ] P3 把 CI 的 container tag 釘死（目前是 `latest`，跟釘 Zephyr 的紀律不一致）
- [ ] P3 用 `name-allowlist` 精簡 west.yml 的 module 匯入，加快 CI
