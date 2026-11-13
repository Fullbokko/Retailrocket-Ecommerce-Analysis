-- ============================================================
-- 03 假說：不同商品分類，「加購後真的成交」的比例差很多
-- 結果檔：data/results/category_conversion.csv（共 463 個分類，已套用 HAVING >= 30）
--
-- 重要：dashboard 的 Top 10 在 Tableau 裡又加了「加購人數 > 50」的篩選，
--       因為小樣本會出現 100%（例如 categoryid 640 只有 33 人），那是雜訊不是洞察。
--       套用 >50 後第一名是 categoryid 814（56 人加購、42 人成交，75.0%）。
--
-- 為什麼用 CTE 去重配對：
--   最初版本把「分類總加購次數」除以「分類總結帳次數」，出現 117.2% —— 不可能超過 100%。
--   原因是有人跳過加購直接結帳，分子不是分母的子集，所以那不是真正的漏斗轉換率。
--   修正：先取「同一人 + 同一商品」的不重複配對，再用 LEFT JOIN 確保成交配對一定來自加購配對。
-- ============================================================
WITH addtocart_pairs AS (
    SELECT DISTINCT visitorid, itemid FROM events WHERE event = 'addtocart'
),
transaction_pairs AS (
    SELECT DISTINCT visitorid, itemid FROM events WHERE event = 'transaction'
),
item_conversion AS (
    SELECT
        a.itemid,
        COUNT(DISTINCT a.visitorid) AS 加購人數,
        COUNT(DISTINCT t.visitorid) AS 轉換人數
    FROM addtocart_pairs a
    LEFT JOIN transaction_pairs t
           ON t.visitorid = a.visitorid AND t.itemid = a.itemid
    GROUP BY a.itemid
)
SELECT
    ct.categoryid,
    SUM(ic.加購人數) AS 該分類加購人數,
    SUM(ic.轉換人數) AS 該分類轉換人數,
    ROUND(SUM(ic.轉換人數) * 100.0 / NULLIF(SUM(ic.加購人數), 0), 1) AS 加購轉結帳率百分比  -- NULLIF 防止除以 0
FROM item_conversion ic
JOIN (  -- 商品屬性分成兩張表，先疊起來再取 categoryid
    SELECT itemid, value FROM item_properties_part1 WHERE property = 'categoryid'
    UNION ALL
    SELECT itemid, value FROM item_properties_part2 WHERE property = 'categoryid'
) AS ip ON ip.itemid = ic.itemid
JOIN category_tree ct ON ct.categoryid = CAST(ip.value AS INTEGER)
GROUP BY ct.categoryid
HAVING SUM(ic.加購人數) >= 30      -- 樣本太少的分類先濾掉（dashboard 另外再用 >50）
ORDER BY 加購轉結帳率百分比 DESC;
