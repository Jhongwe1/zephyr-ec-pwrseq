# R01 — 從一台什麼都沒有的 Windows 11，到測試全綠

> **這份文件的承諾：**
> 照著做，你會從一台什麼都沒裝的 Windows 11 電腦，走到終端機印出
> `1 of 1 executed test configurations passed (100.00%)`。
> 中間**不需要問任何人，也不需要任何硬體**。
>
> **要多久：** 60–90 分鐘。其中約 40 分鐘是電腦自己在下載，你可以去做別的事。
> **要什麼：** 一台 Windows 11 電腦 + 網路 + 約 **12 GB 可用磁碟空間**
> （實測佔用 8.8 GB：workspace 6.5 GB + Zephyr SDK 2.0 GB，其餘留給編譯產物）。
> **不需要：** 開發板、燒錄器、邏輯分析儀。那些是 [R02](R02-hardware.md) 的事。

---

## 目錄

- [0. 先看懂這張圖（2 分鐘，會省你三小時）](#0-先看懂這張圖)
- [1. 裝 WSL2 Ubuntu 24.04](#1-裝-wsl2-ubuntu-2404)
- [2. 第一次進 Ubuntu](#2-第一次進-ubuntu)
- [3. 取得程式碼](#3-取得程式碼)
- [4. 一鍵建置環境](#4-一鍵建置環境)
- [5. 三道驗收關卡](#5-三道驗收關卡)
- [6. 每天開工的固定動作](#6-每天開工的固定動作)
- [附錄 A：這些版本是怎麼決定的](#附錄-a這些版本是怎麼決定的)
- [附錄 B：完整指令速查](#附錄-b完整指令速查)

---

## 0. 先看懂這張圖

**（花 2 分鐘看懂這節，可以省下之後三小時的困惑。）**

你的電腦是 Windows，但這個專案的工具鏈是 Linux 的。所以我們用 **WSL2**——
它是微軟官方的功能，會在你的 Windows 裡跑一個**真的 Linux 核心**。
不是模擬器、不是虛擬機軟體，開機不用等，檔案兩邊都看得到。

```
┌─ Windows 11 ───────────────────────────────────────────────┐
│                                                             │
│   PulseView + Zadig      ← 邏輯分析儀（P4 才用到）          │
│   STM32CubeProgrammer    ← 燒錄備援（板到貨才用到）          │
│                                                             │
│   ┌─ WSL2：Ubuntu 24.04 ───────────────────────────────┐   │
│   │                                                     │   │
│   │   west + Zephyr 4.4.2 + Zephyr SDK 1.0.1            │   │
│   │   編譯（ARM 韌體 與 native_sim）、跑測試             │   │
│   │                                                     │   │
│   │   ~/work/ec-ws/            ← 全部東西都在這裡        │   │
│   │                                                     │   │
│   └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### 為什麼一定要 Linux，不能直接在 Windows 上編？

因為 **`native_sim` 只能在 Linux 上跑**。

`native_sim` 是 Zephyr 的一個「假板子」——它把韌體編譯成一支**普通的 Linux 執行檔**，
把 GPIO 換成軟體模擬的假 GPIO。這代表：

> **你可以在完全沒有硬體的情況下，跑完整的故障注入測試，而且跑在 GitHub CI 上。**

這是這個專案能自動化驗證的地基。沒有它，故障注入只能靠手動按按鈕做一次，
既不可重現、也沒有人能在自己的機器上驗證。**所以這一步沒得商量。**

### 三個之後一定會咬到你的觀念

| 觀念 | 說明 |
|---|---|
| **程式碼要放在 Linux 裡（`~/`），不要放在 `/mnt/c/`** | `/mnt/c/` 是從 Linux 存取 Windows 硬碟的橋接層，很慢。Zephyr 一次 build 有上百個檔案，放 `/mnt/c/` 會慢好幾倍。這個專案會 build 幾百次。`make doctor` 會檢查並警告你。 |
| **每開一個新終端機，都要先啟用 Python 虛擬環境** | 沒做的話 `west` 會找不到。第 6 節有一行 alias 幫你解決。 |
| **從 Windows 編輯 Linux 裡的檔案會弄掉「可執行」權限** | 用 VS Code 的 WSL 模式編輯就不會有這個問題（第 6 節）。`make doctor` 也會檢查。 |

---

## 1. 裝 WSL2 Ubuntu 24.04

### 1.1 先確認你有沒有裝過

按 **開始鍵** → 打 `powershell` → 在「Windows PowerShell」上按右鍵 → **以系統管理員身分執行**。

貼上這行，按 Enter：

```powershell
wsl --list --verbose
```

**你應該看到兩種情況之一：**

**情況 A —— 已經裝好了：**
```
  NAME            STATE           VERSION
* Ubuntu-24.04    Stopped         2
```
`VERSION` 是 `2`、`NAME` 有 `Ubuntu-24.04` → **跳到第 2 節**。

**情況 B —— 還沒裝：**
```
Windows 子系統 Linux 版沒有已安裝的發行版。
```
→ 繼續往下。

### 1.2 安裝

在同一個**系統管理員** PowerShell 裡：

```powershell
wsl --install -d Ubuntu-24.04
```

**這一步會下載約 500 MB，需要 5–15 分鐘。**

**你應該看到：**
```
正在安裝: Ubuntu 24.04 LTS
已安裝 Ubuntu 24.04 LTS。
要求的操作是成功的。變更將在下次重新啟動系統後生效。
```

### 1.3 重新開機

**必須真的重開機**，不是登出。

> ⚠️ **一定要用 24.04（或更新），不要用 22.04。**
> Zephyr 4.4 要求 CMake ≥ 3.28，而 Ubuntu 22.04 內建的只有 3.22。
> 硬要用 22.04 的話你會撞到 `CMake 3.28.0 or higher is required`，
> 然後花一個晚上在跟套件庫搏鬥。**這是本週最常見的坑，繞過它。**

---

## 2. 第一次進 Ubuntu

重開機後，按 **開始鍵** → 打 `Ubuntu` → 開啟 **Ubuntu 24.04**。

第一次開會要你設定帳號：

```
Enter new UNIX username: <打一個小寫英文帳號，例如 key>
New password: <打密碼，畫面不會顯示任何東西，這是正常的>
Retype new password: <再打一次>
```

> 💡 **密碼打了畫面沒反應是正常的**，Linux 不會顯示 `*`。照打就好。
> **這個密碼要記住**，之後安裝套件（`sudo`）會用到。

**你應該看到：**
```
Installation successful!
key@YOUR-PC:~$
```

看到 `$` 提示字元就成功了。

### 2.1 確認版本對

貼上這三行：

```bash
lsb_release -ds
cmake --version | head -1
python3 --version
```

**你應該看到類似：**
```
Ubuntu 24.04.4 LTS
cmake version 3.28.3
Python 3.12.3
```

**驗收標準：** Ubuntu 是 **24.04 以上**、CMake **≥ 3.28**、Python **≥ 3.12**。
（`cmake` 說找不到指令沒關係，第 4 節會裝。Ubuntu 版本才是關鍵。）

---

## 3. 取得程式碼

在 Ubuntu 終端機裡貼上：

```bash
mkdir -p ~/work/ec-ws
cd ~/work/ec-ws
git clone https://github.com/Jhongwe1/zephyr-ec-pwrseq
cd zephyr-ec-pwrseq
```

**你應該看到：**
```
Cloning into 'zephyr-ec-pwrseq'...
remote: Enumerating objects: ...
Receiving objects: 100% ...
```

### 為什麼要先 `mkdir ec-ws` 再 clone 進去？

這不是強迫症，是這個專案的架構決定的。

這個 repo 是它自己 west workspace 的 **manifest repo**——意思是
「Zephyr 的版本由這個 repo 說了算」。所以 repo 的**上一層目錄**會變成 workspace，
Zephyr 會被下載到它旁邊：

```
~/work/ec-ws/               ← workspace（就是你剛 mkdir 的那層）
├── zephyr-ec-pwrseq/       ← 這個 repo
├── zephyr/                 ← 待會 bootstrap 會抓下來
├── modules/                ← 同上
└── .venv/                  ← Python 虛擬環境
```

如果你直接 clone 到 `~/`，Zephyr 就會被倒進你的家目錄，變成一團亂。

> **`ec-ws` 這個名字可以改**，叫什麼都行。腳本是用「repo 的上一層」算出來的，不是寫死的。

---

## 4. 一鍵建置環境

```bash
./tools/bootstrap.sh
```

**這一步要 15–40 分鐘**，大部分時間在下載 Zephyr 原始碼（約 5 GB）和 SDK。
**中途會問你 Ubuntu 密碼**（安裝系統套件用），打第 2 節設的那個。

打完密碼之後就可以去做別的事了。它不會再問你任何問題。

**你應該看到（節錄）：**
```
zephyr-ec-pwrseq bootstrap
    repo      : /home/key/work/ec-ws/zephyr-ec-pwrseq
    workspace : /home/key/work/ec-ws

==> [1/7] Checking host prerequisites
    OK  cmake 3.28.3 (need >= 3.28.0)
    OK  python3 3.12.3 (need >= 3.12.0)
==> [2/7] Installing OS packages (official Zephyr Getting Started list)
    OK  apt packages installed
==> [3/7] Creating Python venv and installing west
    OK  west West version: v1.5.0
==> [4/7] Initialising the west workspace
    OK  workspace initialised
==> [5/7] Fetching Zephyr + modules (this is the slow one)
    OK  zephyr tree fetched
    OK  west zephyr-export (CMake package registry)
==> [6/7] Installing Zephyr's Python dependencies
    OK  python dependencies installed
==> [7/7] Installing the Zephyr SDK (ARM cross toolchain)
    OK  Zephyr SDK installed

Bootstrap complete.
```

### 它到底做了什麼（不是黑盒子）

| 步驟 | 做什麼 | 為什麼 |
|:--:|---|---|
| 1 | 檢查 cmake / python 版本 | 這兩個版本不對的話，錯誤會在很後面才爆出來，而且訊息看不懂。先檢查省很多時間 |
| 2 | 裝系統套件 | Zephyr 官方 Getting Started 的清單，一字不改 |
| 3 | 建 Python 虛擬環境、裝 `west` | Ubuntu 24.04 禁止直接 `pip install` 到系統 Python（PEP 668），一定要虛擬環境 |
| 4 | `west init -l` | 宣告「這個 repo 是 manifest repo」 |
| 5 | `west update` | 依 `west.yml` 抓 Zephyr v4.4.2 + 全部 modules |
| 6 | `west packages pip --install` | 裝 Zephyr 的 Python 相依 |
| 7 | `west sdk install -t arm-zephyr-eabi` | 只裝 ARM 交叉編譯器（`native_sim` 用系統自帶的 gcc） |

> 🔴 **注意第 6 步：** 網路上很多教學還在寫 `pip install -r requirements.txt`。
> **那是舊流程，照做會裝出一個壞掉的環境。** 現在的正確指令是 `west packages pip --install`。

> 💡 **這個腳本可以重複執行。** 已經做完的步驟會自動跳過（顯示 `--  ... (already done)`）。
> 環境怪怪的時候，重跑它是安全的。

---

## 5. 三道驗收關卡

**不要跳過。每一關驗證不同的東西，任何一關過不了都不要往下走**——
否則你之後會分不清是工具鏈壞了還是自己的程式寫錯了。

### 關卡 1：環境自檢

```bash
cd ~/work/ec-ws/zephyr-ec-pwrseq
make doctor
```

**你應該看到（全部 PASS）：**
```
Host
  PASS  OS is Linux (6.6.87.2-microsoft-standard-WSL2)
  PASS  running under WSL2
  PASS  repo is on the Linux filesystem (fast builds)
  PASS  cmake present
  ...
Workspace
  PASS  west workspace initialised
  PASS  zephyr tree present (v4.4.2)
  PASS  zephyr tree matches the pin in west.yml (v4.4.2)
  PASS  Zephyr SDK has arm-zephyr-eabi (needed for the real board)
Repository
  PASS  shell scripts have Unix line endings
  PASS  git identity: Your Name <you@example.com>

Summary
  Everything checks out.  Next: make test
```

**有 FAIL 怎麼辦：** 每個 FAIL 下面都有一行 `->` 告訴你怎麼修。修完再跑一次。

> `git identity` 那行如果 FAIL，照它給的指令設定。**這不是裝飾**——
> P6 要送 PR 到 Zephyr 主線時，DCO 規定 `Signed-off-by` 必須跟 commit 作者完全一致、
> 而且要用**真名**。到那時候才發現設錯，就得改寫整段 git 歷史。

### 關卡 2：測試（不需要硬體）

```bash
make test
```

**這一步約 20–60 秒。你應該看到：**
```
INFO    - 1 of 1 executed test configurations passed (100.00%), 0 built (not run),
          0 failed, 0 errored, with no warnings in 19.45 seconds.
```

**這一關證明了：** 編譯器、Zephyr、`native_sim`、ztest 測試框架、twister 測試執行器
**整條鏈路都是通的**。這是整個專案自動化驗證的地基。

### 關卡 3：編譯給真板子的韌體（不需要板子）

```bash
make build
```

**你應該看到：**
```
Memory region         Used Size  Region Size  %age Used
           FLASH:       27724 B       512 KB      5.29%
             RAM:        6720 B       128 KB      5.13%
Generating files from .../zephyr.elf for board: blackpill_f411ce/stm32f411xe
```

**這一關證明了：** ARM 交叉編譯器能產出真的 ARM 韌體。
`512 KB` FLASH / `128 KB` RAM 也順便確認了板子型號選對了（F411**CE** 就是這個容量）。

### 順手看一下它跑起來長什麼樣

```bash
make run
```

**你應該看到：**
```
*** Booting Zephyr OS build dccb09599635 ***
<inf> ec_main: zephyr-ec-pwrseq (P0 skeleton)
<inf> ec_main: board  : native_sim/native
<inf> ec_main: zephyr : 4.4.2
<inf> ec_main: cycle counter: 1000000 Hz (1000 ns per tick)
<inf> ec_main: skeleton up; sequencer lands in P1
```

按 **Ctrl+C** 結束。

> 那行 `cycle counter` 不是裝飾。它是這個專案之後**每一個時間數字的解析度上限**。
> `native_sim` 上是 1 MHz（1 µs），真板子上會是約 100 MHz（約 10 ns）。
> P4 要拿韌體自己記的時間戳跟邏輯分析儀量到的時間互相驗證，
> 這個數字對不對，決定那個比對有沒有意義。

---

### ✅ 三關都過 = R01 完成

你現在的狀態：

- [x] WSL2 Ubuntu 24.04
- [x] Zephyr 4.4.2（版本由 `west.yml` 釘死）
- [x] Zephyr SDK 1.0.1，含 ARM 交叉編譯器
- [x] 本 repo 可編譯（ARM + native_sim）、測試全綠
- [ ] 實體板燒錄 → 板子到貨後看 [R02](R02-hardware.md)

---

## 6. 每天開工的固定動作

### 6.1 設一個 alias（做一次就好）

每開一個新終端機都要啟用虛擬環境，很煩。設個捷徑：

```bash
echo "alias ecws='source ~/work/ec-ws/.venv/bin/activate && cd ~/work/ec-ws/zephyr-ec-pwrseq'" >> ~/.bashrc
source ~/.bashrc
```

之後每次開工就打：

```bash
ecws
```

> 💡 其實這個專案的 `Makefile` 會自己去 `.venv` 裡找 `west`，
> 所以**忘了啟用虛擬環境，`make` 還是會動**。這是刻意設計的——
> 「忘記 source venv」是新手第一個月最常見的卡關原因，
> 與其寫在文件裡叫人記住，不如讓工具直接容錯。

### 6.2 用 VS Code 編輯（建議）

在 Windows 裝 [VS Code](https://code.visualstudio.com/)，裝 **WSL** 擴充套件，然後在 Ubuntu 終端機裡：

```bash
ecws
code .
```

VS Code 會用 WSL 模式打開，**檔案權限、換行符號都會是正確的 Linux 語意**。

> ⚠️ **不要**用 Windows 的記事本或編輯器直接去改 `\\wsl.localhost\...` 底下的 `.sh` 檔案。
> 那樣會把「可執行」權限弄掉，然後你會看到 `Permission denied`——
> 一個跟真正原因完全對不起來的錯誤訊息。
> （`make doctor` 會抓到這件事，`.gitattributes` 會擋掉換行符號的部分。）

### 6.3 一天的循環

```bash
ecws
make doctor          # 只在覺得怪的時候跑
# ... 寫程式 ...
make test            # 改邏輯之後
make build           # 要燒板子之前
git add -p           # 分段檢查自己改了什麼
git commit           # 訊息寫「為什麼」，不是「改了什麼」
```

---

## 附錄 A：這些版本是怎麼決定的

> 三個月後的你會問「當初為什麼選這個」。寫在這裡，省得重新想一次。
> 版本選擇是會被追問的那類決定，答案應該在檔案裡，不是在記憶裡。

### A.1 為什麼 Zephyr 釘在 v4.4.2

- **4.4 是對的大版本：** 4.4.0（2026-04）是第一個支援 Zephyr SDK 1.0 的版本。
- **為什麼是 `.2` 不是 `.0`：** `4.4.1`、`4.4.2` 是同一條 4.4 維護分支上的
  修補版本——**只修 bug，不改 API**。取最新的修補版沒有成本，卻白拿一堆修正。
  而且被問到「為什麼你停在 `.0`，`.2` 都出了」時，你不會答不出來。
- **為什麼要釘：** README 裡每一個時間數字，都是在某一棵特定的 Zephyr 樹上量出來的。
  不釘版本的話，別人 clone 下來拿到的是另一棵樹，「可重現」就從事實退化成宣稱。
  順便，CI 也不會因為上游主線動了而莫名其妙變紅。
- **什麼時候該動這個釘子：** 只在**次版本**（4.5、4.6…）出來時重新評估，因為那些可能改 API。
  改的時候要單獨一個 commit，訊息裡寫清楚理由，而且 `make test` 跟 `make build` 都要保持綠的。

### A.2 為什麼用 `--narrow -o=--depth=1` 抓原始碼

完整的 Zephyr git 歷史約 2.5 GB、20–40 分鐘。淺層抓取小十倍、快十倍，
而**編譯完全不需要歷史紀錄**。

代價是沒有 git 歷史可查。P6 要做上游貢獻、需要 `git blame` 或 `git log` 時，再補回來就好：

```bash
cd ~/work/ec-ws/zephyr && git fetch --unshallow
```

> 這個取捨也有副作用：淺層抓取**不會抓 tag**，所以 `git describe` 會說
> `No names found`。`make doctor` 因此改成比對 `zephyr/VERSION` 檔案來確認版本，
> 而不是用 `git describe`。這個坑我踩過，記在 `LOG.md` 2026-08-12。

### A.3 為什麼只裝 ARM 一種交叉編譯器

Zephyr SDK 支援十幾種架構，全裝要好幾 GB。這個專案只需要兩種編譯目標：

| 目標 | 用什麼編 |
|---|---|
| `blackpill_f411ce`（真板子） | `arm-zephyr-eabi`（SDK 提供） |
| `native_sim`（模擬器） | **系統自帶的 gcc**（Ubuntu 已經有了） |

所以 `-t arm-zephyr-eabi` 就夠。之後要換板子（例如 RP2040 也是 ARM，一樣夠用；
若換 RISC-V 或 Xtensa）再裝那一種即可。

### A.4 為什麼 workspace 放 `~/work/ec-ws` 而不是 `/mnt/c/...`

`/mnt/c/` 是 WSL 存取 Windows 檔案系統的橋接層，每個檔案操作都要跨越一層轉譯。
Zephyr 一次乾淨編譯會碰上千個檔案；放在 `/mnt/c/` 會慢好幾倍。
這個專案會編譯幾百次，累積起來是好幾個小時。

`make doctor` 會偵測並警告，但不會擋你——如果你有別的理由要放那裡，那是你的決定。

---

## 附錄 B：完整指令速查

```bash
# ── 從零開始（整段可貼）
mkdir -p ~/work/ec-ws && cd ~/work/ec-ws
git clone https://github.com/Jhongwe1/zephyr-ec-pwrseq
cd zephyr-ec-pwrseq
./tools/bootstrap.sh
make doctor && make test && make build

# ── 每天
ecws                       # alias：啟用 venv + cd 到 repo
make                       # 列出所有指令
make doctor                # 環境自檢
make test                  # 故障注入測試（native_sim）
make build                 # 編譯韌體
make run                   # 在 native_sim 上跑起來
make dts                   # 看 devicetree 展開後的真實結果
make clean                 # 清掉編譯產物

# ── 換板子（時序表在 DTS，所以板子是可換的）
make build BOARD=blackpill_f401cc
make build BOARD=native_sim

# ── west 原生指令（Makefile 只是包裝，底下是這些）
source ~/work/ec-ws/.venv/bin/activate
west build -p always -b blackpill_f411ce -d build/blackpill_f411ce .
west twister -T tests/ -p native_sim --inline-logs
west update --narrow -o=--depth=1        # west.yml 改過之後
```

---

**下一步：** 板子到貨了 → [R02 硬體接線](R02-hardware.md)。
還沒到 → 直接進 P1 的時序引擎，那部分完全不需要硬體。
