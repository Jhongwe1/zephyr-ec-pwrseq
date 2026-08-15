# dts/bindings/power/

自訂 devicetree binding。**這個目錄是整個專案的核心設計所在**——
「時序是資料，不是程式碼」這句話，成立與否全看這裡的兩個檔案。

P1 會在這裡放兩個檔案：

| 檔案 | 描述 |
|---|---|
| `ec,power-sequencer.yaml` | 父節點。子節點是 `ec,power-rail`，**出現順序即上電順序** |
| `ec,power-rail.yaml` | 一條電源軌：`rail-name` / `enable-gpios` / `pg-gpios` / `ramp-delay-us` / `pg-timeout-ms` / `pg-debounce-us` / `off-delay-us` |

---

## 為什麼 binding 要先於任何時序程式碼

binding 是**介面的定義**，不是實作。先把「一條電源軌有哪些屬性、每個屬性是什麼意思」
講清楚，時序引擎才有東西可以泛用地展開。反過來先寫 C 再補 DTS，
最後一定會變成「DTS 只是把寫死的常數搬個位置」，失去全部意義。

binding 的 `description` 欄位要**認真寫**——它不是註解，它是這個專案對外承諾的介面契約。
例如 `pg-gpios` 的描述裡必須寫明：

> MUST have a defined idle level (external pull-down) so that a disconnected PG
> reads inactive — "signal missing" and "signal inactive" must be the same thing.

---

## 這裡藏著一個會被戳的假設

「DTS 子節點順序 = 上電順序」依賴 `DT_FOREACH_CHILD` 系列巨集**照子節點在最終
devicetree 中出現的順序展開**。

這個假設沒有寫在任何規格裡，所以要有兩層防禦：

1. 啟動時把展開出來的 rail 名單依序印進 log／trace，**第一條測試就是驗證這個順序符合預期**
2. 要更保險的話，binding 可以加一個明確的 `seq` 整數屬性，初始化時檢查
   「陣列順序 == seq 順序」，不一致直接 `__ASSERT`

選順序式是因為它讓 DTS 自我描述，但明確索引是更防呆的變體——**這是可以討論的取捨**。

**重點不是這個假設有沒有保證，而是它被明確標示出來、而且在執行期真的被檢查。**
沒有被檢查的假設，跟沒有這個假設是兩件不同的事。
