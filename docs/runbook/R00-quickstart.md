# R00 — 快速開始

> **給誰：** 已經有 Linux（或 WSL2 Ubuntu 24.04）的人。
> **要多久：** 約 20 分鐘，其中 15 分鐘是電腦在下載。
> **要什麼：** 網路 + 約 12 GB 可用磁碟空間
> （實測佔用 8.8 GB：workspace 6.5 GB + SDK 2.0 GB，其餘是編譯產物的餘裕）。
> **不需要任何硬體。**
>
> 電腦上什麼都還沒有？→ [R01 從零建置環境](R01-environment.md)（含 WSL2 安裝）

---

## 四個指令

```bash
mkdir -p ~/work/ec-ws && cd ~/work/ec-ws
git clone https://github.com/Jhongwe1/zephyr-ec-pwrseq
cd zephyr-ec-pwrseq
./tools/bootstrap.sh
```

`bootstrap.sh` 要跑 15–40 分鐘（下載 Zephyr 原始碼與 SDK）。
**中途會問一次 sudo 密碼**，之後不再需要你。

> **為什麼要先建 `ec-ws` 再 clone 進去？**
> 這個 repo 是它自己 west workspace 的 manifest repo——Zephyr 的版本由它決定。
> 所以 repo 的**上一層**會變成 workspace，Zephyr 會被下載到它旁邊。
> 直接 clone 到家目錄的話，Zephyr 會被倒進你的家目錄變成一團亂。

---

## 驗收

```bash
make doctor    # 環境自檢，應該全 PASS
make test      # 測試，應該 100% passed
make build     # 編譯 ARM 韌體，應該印出記憶體用量表
```

**`make test` 應該印出：**
```
INFO - 1 of 1 executed test configurations passed (100.00%), 0 built (not run),
       0 failed, 0 errored, with no warnings in 19.45 seconds.
```

**`make build` 應該印出：**
```
Memory region         Used Size  Region Size  %age Used
           FLASH:       27724 B       512 KB      5.29%
             RAM:        6720 B       128 KB      5.13%
```

三個都過 → 環境正確。

有任何一個沒過 → [R99 疑難排解](R99-troubleshooting.md)，**用錯誤訊息當關鍵字搜尋**。

---

## 看它跑起來

```bash
make run
```

```
*** Booting Zephyr OS build dccb09599635 ***
<inf> ec_main: zephyr-ec-pwrseq (P0 skeleton)
<inf> ec_main: board  : native_sim/native
<inf> ec_main: zephyr : 4.4.2
<inf> ec_main: cycle counter: 1000000 Hz (1000 ns per tick)
<inf> ec_main: skeleton up; sequencer lands in P1
```

Ctrl+C 結束。

---

## 接下來

| 我想… | 去哪 |
|---|---|
| 搞懂這個專案在幹嘛 | [README.md](../../README.md) |
| 知道每個決策的理由 | [R01 附錄 A](R01-environment.md#附錄-a這些版本是怎麼決定的) |
| 接硬體 | [R02 硬體](R02-hardware.md) |
| 出事了 | [R99 疑難排解](R99-troubleshooting.md) |
