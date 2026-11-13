-- ============================================================
-- 05 假說：瀏覽集中在少數人身上的商品，可能是「觸及不足」（其實有需求，只是沒人看到）
-- 結論：不成立。對齊分母後，沒有發現需求不足的證據。（未放進 dashboard 主論點）
-- 結果檔：data/results/view_concentration.csv（人均瀏覽數前 60 名）
-- ============================================================

-- ---------- A. 找出「瀏覽集中」的商品，再看它們的轉換率 ----------
-- 篩選條件：總瀏覽 >= 30 且不重複訪客 >= 5。
--   （第一版只有前者，結果被「只有 1 個訪客狂看」的商品佔滿，那是極端值，所以加訪客下限）
-- 第二層只對第一層的商品計算轉換率（效能考量，少掃很多資料）
WITH view_concentration AS (
    SELECT
        itemid,
        COUNT(*) AS 總瀏覽次數,
        COUNT(DISTINCT visitorid) AS 不重複訪客數,
        ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT visitorid), 2) AS 平均每人瀏覽次數
    FROM events
    WHERE event = 'view'
    GROUP BY itemid
    HAVING COUNT(*) >= 30 AND COUNT(DISTINCT visitorid) >= 5
),
item_conversion AS (
    SELECT
        itemid,
        COUNT(DISTINCT CASE WHEN event = 'addtocart'   THEN visitorid END) AS 加購人數,
        COUNT(DISTINCT CASE WHEN event = 'transaction' THEN visitorid END) AS 成交人數
    FROM events
    WHERE itemid IN (SELECT itemid FROM view_concentration)
    GROUP BY itemid
)
SELECT
    vc.itemid, vc.總瀏覽次數, vc.不重複訪客數, vc.平均每人瀏覽次數,
    ic.加購人數, ic.成交人數,
    ROUND(ic.成交人數 * 100.0 / vc.不重複訪客數, 2) AS 瀏覽轉成交率百分比
FROM view_concentration vc
JOIN item_conversion ic ON ic.itemid = vc.itemid
ORDER BY vc.平均每人瀏覽次數 DESC
LIMIT 60;     -- 先看 20 筆、再放寬到 60 筆確認結論穩定

-- ---------- B. 分母對齊後的比較 ----------
-- 最初把「瀏覽轉成交率」拿去跟「加購轉成交率」（30~48%）比，得出這批商品轉換率很低 —— 分母不同，不能比。
-- 這段把兩個商品群放在同一個口徑下比較（口徑：每個商品的不重複瀏覽人數加總，同一人看多個商品會重複計入，
-- 所以數字會跟全站 KPI 的 0.83% 不同，兩者不能互相比較）
-- 結果：符合條件的商品群 1.29%（19,453 個商品），其他商品 0.61%（215,385 個商品）
--       → 沒有證據顯示這批商品需求不足。另外單一商品只有約 5~13 位訪客，
--         零成交本來就是預期內的結果，不能解讀成「沒人想買」。
WITH item_stats AS (
    SELECT
        itemid,
        SUM(CASE WHEN event = 'view' THEN 1 ELSE 0 END) AS 總瀏覽次數,
        COUNT(DISTINCT CASE WHEN event = 'view'        THEN visitorid END) AS 瀏覽人數,
        COUNT(DISTINCT CASE WHEN event = 'transaction' THEN visitorid END) AS 成交人數
    FROM events
    GROUP BY itemid
)
SELECT
    CASE WHEN 總瀏覽次數 >= 30 AND 瀏覽人數 >= 5
         THEN '符合假說篩選條件的商品' ELSE '其他商品' END AS 商品群,
    COUNT(*) AS 商品數,
    SUM(瀏覽人數) AS 總瀏覽人數,
    SUM(成交人數) AS 總成交人數,
    ROUND(SUM(成交人數) * 100.0 / SUM(瀏覽人數), 2) AS 瀏覽轉成交率
FROM item_stats
WHERE 瀏覽人數 > 0
GROUP BY 商品群;
