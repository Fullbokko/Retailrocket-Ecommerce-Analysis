-- ============================================================
-- 04 假說：同一人對同一商品「加購越多次」，成交率怎麼變？
-- 這份有三段，對應分析中「被推翻 → 修正」的過程：
--   A. 用原始加購次數算（得到「先升後降」）
--   B. 檢查重複加購的時間間隔（發現過半是 1 分鐘內的重複點擊）
--   C. 排除 60 秒內重複點擊後重算（得到「持續上升」）← dashboard 用這個
-- ============================================================

-- ---------- A. 原始加購次數 vs 成交率（修正前的版本，保留作對照）----------
-- 結果：1 次 29.9% → 2 次 38.5% → 3 次 47.6% → 4 次 38.8%（看起來先升後降）
WITH pair_stats AS (
    SELECT
        visitorid,
        itemid,
        SUM(CASE WHEN event = 'addtocart'   THEN 1 ELSE 0 END) AS 加購次數,
        MAX(CASE WHEN event = 'transaction' THEN 1 ELSE 0 END) AS 是否成交   -- 這組人-商品最後有沒有成交（0/1）
    FROM events
    WHERE event IN ('addtocart', 'transaction')
    GROUP BY visitorid, itemid
    HAVING 加購次數 > 0
)
SELECT
    加購次數,
    COUNT(*) AS 配對數,
    SUM(是否成交) AS 成交配對數,
    ROUND(SUM(是否成交) * 100.0 / COUNT(*), 1) AS 成交率百分比
FROM pair_stats
GROUP BY 加購次數
ORDER BY 加購次數;

-- ---------- B. 重複加購的時間間隔：是真的猶豫，還是手滑連點？ ----------
-- 結果：10 秒內 3,111 筆 / 10 秒-1 分鐘 875 筆 / 1 分鐘-1 小時 1,651 筆 / 1 小時以上 1,670 筆
--       → 共 7,307 筆重複加購，其中 54.6% 發生在 1 分鐘內，較像操作習慣，不像重新考慮
WITH addtocart_sequence AS (
    SELECT
        visitorid,
        itemid,
        timestamp,
        LAG(timestamp) OVER (            -- LAG：往前抓一格 = 同一人同一商品的「上一次加購時間」
            PARTITION BY visitorid, itemid
            ORDER BY timestamp
        ) AS 上一次加購時間
    FROM events
    WHERE event = 'addtocart'
)
SELECT
    CASE
        WHEN (timestamp - 上一次加購時間) / 1000.0 < 10   THEN 'A. 10秒內'
        WHEN (timestamp - 上一次加購時間) / 1000.0 < 60   THEN 'B. 10秒-1分鐘'
        WHEN (timestamp - 上一次加購時間) / 1000.0 < 3600 THEN 'C. 1分鐘-1小時'
        ELSE 'D. 1小時以上'
    END AS 間隔區間,
    COUNT(*) AS 次數
FROM addtocart_sequence
WHERE 上一次加購時間 IS NOT NULL         -- 第一次加購前面沒有「上一次」，不算重複
GROUP BY 間隔區間
ORDER BY 間隔區間;

-- ---------- C. 有效加購次數（60 秒內的重複點擊只算一次）vs 成交率 ----------
-- 結果檔：data/results/addtocart_count_vs_purchase.csv
-- 結果：1 次 29.4% → 2 次 58.9% → 3 次 64.4% → 4 次 65.8% → 5 次 72.2%
--       「先升後降」消失，變成持續上升。
-- 60 秒門檻的依據：B 段顯示過半重複加購落在 1 分鐘內。
-- 樣本提醒：1~4 次的配對數分別為 59,307 / 2,338 / 267 / 73，5 次以上樣本很小，只能當參考。
WITH addtocart_with_prev AS (
    SELECT
        visitorid, itemid, timestamp,
        LAG(timestamp) OVER (PARTITION BY visitorid, itemid ORDER BY timestamp) AS 上一次加購時間
    FROM events
    WHERE event = 'addtocart'
),
addtocart_flagged AS (
    SELECT
        visitorid,
        itemid,
        CASE
            WHEN 上一次加購時間 IS NULL THEN 1                               -- 第一次加購一定算有效
            WHEN (timestamp - 上一次加購時間) / 1000.0 >= 60 THEN 1         -- 距上次 >= 60 秒才算新的有效加購
            ELSE 0                                                           -- 60 秒內視為重複點擊
        END AS 是否算新的有效加購
    FROM addtocart_with_prev
),
pair_effective_counts AS (
    SELECT visitorid, itemid, SUM(是否算新的有效加購) AS 有效加購次數   -- 用 SUM 加總 0/1 = 計數
    FROM addtocart_flagged
    GROUP BY visitorid, itemid
),
pair_transaction AS (
    SELECT DISTINCT visitorid, itemid FROM events WHERE event = 'transaction'
)
SELECT
    pe.有效加購次數,
    COUNT(*) AS 配對數,
    SUM(CASE WHEN pt.itemid IS NOT NULL THEN 1 ELSE 0 END) AS 成交配對數,
    ROUND(SUM(CASE WHEN pt.itemid IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS 成交率百分比
FROM pair_effective_counts pe
LEFT JOIN pair_transaction pt
       ON pt.visitorid = pe.visitorid AND pt.itemid = pe.itemid
GROUP BY pe.有效加購次數
ORDER BY pe.有效加購次數;
