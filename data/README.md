# 資料說明

## 原始資料（到kaggle頁下載）

來源：[Retailrocket recommender system dataset（Kaggle）](https://www.kaggle.com/datasets/retailrocket/ecommerce-dataset)

使用的四張表：

| 表 | 一列代表 |
|----|---------|
| `events` | 一次行為事件（view / addtocart / transaction） |
| `category_tree` | 一個分類與其上層分類 |
| `item_properties_part1`、`item_properties_part2` | 某商品在某時間點的某一項屬性 |

匯入 SQLite 的方式（二選一）：

- 用圖形工具（例如 DB Browser for SQLite）：檔案 → 匯入 → 從 CSV 匯入成資料表，分別匯入 4 個 CSV。
- 用命令列：`sqlite3 retailrocket.db` 之後，`.mode csv` → `.import events.csv events`（其他表同理）。

匯入後請執行 `sql/00_setup_indexes.sql`。

## 彙總結果（`results/`）

這些是 SQL 查詢輸出的彙總表，沒有個人層級資料，也是 Excel 與 Tableau 的輸入。

| 檔案 | 來源 SQL | 說明 |
|------|---------|------|
| `purchase_timing.csv` | `02_impulse_purchase_timing.sql` | 加購到成交的時間分布 |
| `category_conversion.csv` | `03_category_conversion.sql` | 各分類加購轉成交率（已套用加購人數 >= 30） |
| `addtocart_count_vs_purchase.csv` | `04_addtocart_count_vs_purchase.sql`（C 段） | 有效加購次數 vs 成交率 |
| `view_concentration.csv` | `05_view_concentration.sql`（A 段） | 瀏覽集中度前 60 名商品 |

> `purchase_timing.csv` 的計數欄位叫「成交筆數」：單位是成交事件，不是人數，所以總和會大於總成交人數（11,719）。
