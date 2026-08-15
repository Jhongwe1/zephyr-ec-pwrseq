# boards/

每塊板子一份 devicetree overlay。

| 檔案 | 用途 | 何時 |
|---|---|:--:|
| `blackpill_f411ce.overlay` | 實體板：真 GPIO | P1 |
| `native_sim.overlay` | 模擬：**同構節點**接 `gpio_emul` | P3 |

**兩份 overlay 的節點結構必須一模一樣，只有 GPIO 來源不同。**
這是「同一支時序引擎能同時跑在真板子與 CI 上」的全部祕密——
一行 C 都不用改。

---

## ⚠️ 檔名必須完全等於 board 名稱

Zephyr 是用檔名去比對的：`boards/<board_name>.overlay`。
名字差一個字，overlay 就會被**靜默忽略**——不會報錯，只是你的節點不見了。

**所以鐵律是：改完 overlay 一定要看展開結果。**

```bash
make dts        # 等同 cat build/<board>/zephyr/zephyr.dts
```

你寫的東西 ≠ build 真正用的東西。**只有 `zephyr.dts` 是事實。**
