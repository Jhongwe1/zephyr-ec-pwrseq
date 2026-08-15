# R99 — 疑難排解

> **用法：把你看到的錯誤訊息當關鍵字，在這一頁按 Ctrl+F 搜尋。**
>
> 這份文件是**錯誤訊息的索引**，不是教學。每一條的格式固定：
> 你會看到什麼 → 真正的原因 → 怎麼修 → 為什麼會這樣。
>
> **找不到你的錯誤？** 那是這份文件的缺口。解決之後請把它補進來——
> 對三個月後的你來說，「我以前解過但忘了怎麼解」比「沒解過」更浪費時間。

---

## 第一步永遠是這個

```bash
make doctor
```

嵌入式專案裡大約一半的「我的程式壞了」其實是「我的環境壞了」，
而這兩者對還不熟的人來說，錯誤訊息長得一模一樣。
`doctor` 用十秒鐘把它們分開。**先跑它，再讀你的程式碼。**

---

## 環境建置

### `CMake 3.28.0 or higher is required. You are running version 3.22.1`

**原因：** 你在 Ubuntu 22.04（或更舊）上。22.04 內建的 CMake 只有 3.22，Zephyr 4.4 要 3.28。

**解法：** 換 Ubuntu 24.04。**不要**去跟 Kitware 套件庫搏鬥升級 CMake。

```powershell
# Windows PowerShell（系統管理員）
wsl --install -d Ubuntu-24.04
```

**為什麼：** 官方支援基準就是 24.04。硬要在 22.04 上湊，你會接著撞到 Python 3.10
（要 3.12）、然後是別的。**這不是一個坑，是一串坑。** 換系統 15 分鐘，硬撐要一個晚上。

---

### `west: command not found`

**原因：** Python 虛擬環境沒啟用。`west` 裝在 `~/work/ec-ws/.venv/` 裡，不在系統 PATH。

**解法：**
```bash
source ~/work/ec-ws/.venv/bin/activate
```
或用 [R01 §6.1](R01-environment.md#61-設一個-alias做一次就好) 設的 `ecws` alias。

**為什麼你不常撞到這個：** 這個專案的 `Makefile` 會自己去 `.venv/bin/` 找 `west`，
所以 `make test` / `make build` 忘了 source 也會動。只有直接打 `west ...` 才會踩到。
這是刻意的容錯——「忘記 source venv」是新手第一個月最常見的卡關原因。

---

### `error: externally-managed-environment`

**你會看到：**
```
× This environment is externally managed
╰─> To install Python packages system-wide, try apt install ...
```

**原因：** 你在 Ubuntu 24.04 上直接 `pip install`。24.04 起套用 PEP 668，
禁止 pip 動到系統 Python，避免搞爛系統套件。

**解法：** 用虛擬環境，也就是 `bootstrap.sh` 已經幫你做的事。
**不要**加 `--break-system-packages`——那個參數名稱就是在警告你。

---

### `west packages pip --install` 找不到指令 / 網路教學叫我用 requirements.txt

**原因：** 你看到的是**過時的教學**。

**解法：** 現在的正確流程是：
```bash
west packages pip --install
west sdk install -t arm-zephyr-eabi
```

**為什麼要特別講：** 舊流程 `pip install -r zephyr/scripts/requirements.txt` 在很多
部落格與 AI 生成的教學裡還在流傳。照做會裝出一個**看起來裝好了、但缺東西**的環境，
而缺的東西要到很後面才會爆。

---

## 執行與權限

### `/usr/bin/env: 'bash\r': No such file or directory`

**或是：** `bad interpreter: No such file or directory`（但檔案明明存在）

**原因：** 檔案是 CRLF（Windows）換行。Linux 把 `\r` 當成直譯器路徑的一部分，
於是它去找一個叫 `bash\r` 的程式。**`\r` 是看不見的**，所以錯誤訊息看起來毫無道理。

**解法：**
```bash
sed -i 's/\r$//' tools/*.sh
```

**為什麼不會再發生：** repo 裡的 `.gitattributes` 已經強制這些檔案用 LF。
只有「用 Windows 編輯器直接改 `\\wsl.localhost\...` 底下的檔案」才會重新引入。
→ 用 VS Code 的 WSL 模式改（[R01 §6.2](R01-environment.md#62-用-vs-code-編輯建議)）。

---

### `./tools/doctor.sh: Permission denied`

**原因：** 可執行權限掉了。最常見的成因跟上一條一樣：**從 Windows 那邊寫入了這個檔案**。
Windows 檔案系統沒有 Unix 的執行位元，寫入時會被重設成 644。

**解法：**
```bash
chmod +x tools/*.sh
```

要讓 git 記住（否則別人 clone 下來還是不能執行）：
```bash
git update-index --chmod=+x tools/doctor.sh
```

**為什麼 `make doctor` 抓得到：** 它會檢查 `tools/*.sh` 的執行位元。這條檢查就是為了這個坑加的。

---

## west / 版本

### `fatal: No names found, cannot describe anything`

**原因：** Zephyr 是用 `--narrow -o=--depth=1` 淺層抓下來的，**沒有抓 tag**，
所以 `git describe` 找不到任何 tag 可以描述。

**這通常不是問題。** 編譯完全不需要 tag。

**要判斷版本對不對，看這個檔案：**
```bash
cat ~/work/ec-ws/zephyr/VERSION
```
```
VERSION_MAJOR = 4
VERSION_MINOR = 4
PATCHLEVEL = 2
```

**真的需要完整歷史時**（P6 做上游貢獻要 `git blame`）：
```bash
cd ~/work/ec-ws/zephyr && git fetch --unshallow
```

**為什麼要記這條：** `make doctor` 一開始就是用 `git describe` 檢查版本的，
結果在淺層 clone 上永遠回報「版本不符」。已改成比對 `VERSION` 檔案。
→ `LOG.md` 2026-08-12。

---

### `make doctor` 說找不到 arm-zephyr-eabi，但 `make build` 明明編得過

**原因（這是我自己寫的 bug，值得記住）：** 檢查寫成了

```bash
west sdk list | grep -q 'arm-zephyr-eabi'      # ❌ 有 bug
```

在 `set -o pipefail` 的腳本裡，這行是壞的：
`grep -q` **找到第一個符合就立刻結束並關閉管線**，上游的 `west` 因此收到 `SIGPIPE` 死掉，
而 `pipefail` 會把整條管線的結果判定為失敗——
**所以工具鏈「存在」的時候，檢查反而回報「不存在」。**

**解法：先接到變數再比對，不要用管線。**
```bash
SDK_LIST="$(west sdk list 2>/dev/null || true)"
case "$SDK_LIST" in
    *arm-zephyr-eabi*) echo found ;;
esac
```

**為什麼值得記：** 這個 bug 在**沒有** `pipefail` 的 shell 裡完全正常，
所以隨手測試不會發現。凡是 `... | grep -q` 出現在 `pipefail` 腳本裡，都該用這個眼光看一次。

---

### `west update` 跑很久 / 好像卡住了

**這是正常的。** 即使用了淺層抓取也要 15–40 分鐘，會下載約 6.5 GB。

**怎麼確認它真的在動：** 開另一個終端機
```bash
du -sh ~/work/ec-ws
```
數字有在長就是正常的。

---

## 編譯

### 我改了 overlay，但好像沒有作用

**這是這個專案最重要的除錯習慣。**

**先看 build 真正用到的 devicetree**（不是你寫的那份）：
```bash
make dts
```
或直接看 `build/<board>/zephyr/zephyr.dts`。

**你寫的東西 ≠ build 用的東西。** 中間隔著 overlay 檔名比對、`status` 屬性、
`compatible` 比對、binding 檔有沒有被找到。**只有 `zephyr.dts` 是事實。**

**常見成因：**

| 成因 | 檢查方式 |
|---|---|
| overlay 檔名不對 | 必須是 `boards/<board_name>.overlay`，board name 要跟 `make build` 用的完全一致 |
| 沒有重新產生 build 設定 | `make rebuild`（帶 `-p always`），或 `make clean` |
| 節點 `status` 不是 `"okay"` | 在 `zephyr.dts` 裡搜尋你的節點看它的 status |
| binding 找不到 | `compatible` 字串要跟 `dts/bindings/` 底下 yaml 的檔名一致 |

---

### 編出來的 FLASH 容量不對（例如只有 256 KB）

**原因：** 板子選錯了。F411**CE** 是 512 KB / 128 KB；F401**CC** 是 256 KB / 64 KB。

**確認方式：** 編譯結尾那張表
```
Memory region         Used Size  Region Size  %age Used
           FLASH:       27724 B       512 KB      5.29%
             RAM:        6720 B       128 KB      5.13%
```
`512 KB` / `128 KB` = F411CE ✓

**如果你買到的真的是 F401：** 不是問題，改一個參數就好——
時序表在 devicetree，程式碼不用動。
```bash
make build BOARD=blackpill_f401cc
```

---

## 測試

### twister 說 `0 test configurations selected`

**原因：** 它沒找到測試。

**檢查：**
1. `tests/<name>/testcase.yaml` 存在嗎
2. `platform_allow` 有沒有包含你指定的 `-p` 平台
3. 你是不是在 repo 根目錄跑的

```bash
cd ~/work/ec-ws/zephyr-ec-pwrseq
make test
```

---

### 測試偶爾過偶爾不過

**先假設是你的測試有問題，不是 flaky。**

`tests/smoke` 的時間檢查刻意用了 ±20% 的寬鬆容差，理由寫在該檔案的註解裡：
它要抓的是「時脈設定錯了一個數量級」，不是量測精度。
**守著地基的測試如果會 flaky，人就會養成重跑的習慣，那它就等於不存在了。**

---

## 硬體（板子到貨後才會用到）

> 這一段在實際接上硬體之後補完。目前先放已知的坑。

### `west flash` 找不到 ST-Link（WSL 看不到 USB）

**原因：** WSL2 預設看不到 USB 裝置。

**兩條路，先走 (b)：**

**(b) 燒錄放 Windows 端做**（建議先用這個）
在 Windows 裝 STM32CubeProgrammer，燒 `build/blackpill_f411ce/zephyr/zephyr.hex`。
WSL 負責編譯，Windows 負責燒錄。

**(a) 把 USB 掛進 WSL**（之後有空再弄）
```powershell
winget install usbipd
usbipd list
usbipd bind   --busid <ID>
usbipd attach --wsl --busid <ID>
```

**為什麼建議先走 (b)：** `usbipd` 是**可以延後的複雜度**。
第一週的目標是「程式碼能編、能燒、會動」，不是「建出完美的工具鏈」。

---

### 邏輯分析儀量到的波形全是雜訊

**第一嫌疑犯永遠是接地。**

- LA 的 GND **至少接兩條**到麵包板的地軌，而且要短
- 先量一個**已知的方波**（例如 blinky 的 LED 腳）驗證儀器跟接線本身沒問題，
  再去量你真正想看的訊號

**不要**用 24 MHz 取樣，用 4 MHz。理由見 [R05 量測](R05-measurement.md)。

---

## 怎麼自己查一個沒見過的錯誤

1. **完整讀錯誤訊息。** 真正的原因通常在第一行，不是最後一行。
2. **判斷是哪一層壞了：**

   | 症狀 | 大概是哪一層 |
   |---|---|
   | CMake / west / Python 的錯 | 環境 → `make doctor` |
   | devicetree 相關的錯 | DTS → `make dts` |
   | 編譯器的錯（undefined reference…） | 程式碼 |
   | 編得過但行為不對 | 邏輯或硬體 |

3. **查文件只查 `latest`：** <https://docs.zephyrproject.org/latest/>
   **不要**看舊版、也不要看 nRF Connect SDK 的版本——API 會不一樣。
4. **不要從頭讀規格書。** 只讀你的程式碼實際踩到的那一節。
5. **把錯誤訊息與解法記進 `LOG.md`。** 然後問自己：
   **「這是我的問題，還是文件的問題？」**
   是後者就標 `[upstream candidate]`——那是 P6 選上游 PR 題目的清單。
