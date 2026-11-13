-- ============================================================
-- 02 假說：加購到成交，是不是衝動購物？（多數人很快就下單）
-- 做法：每一筆成交，往回找「同一人 + 同一商品」最近一次的加購，算時間差
-- 結果檔：data/results/purchase_timing.csv
-- 結果：1 小時內 91.2% / 1-6 小時 4.9% / 6-24 小時 2.0% / 1-3 天 0.9% / 3 天以上 0.9%
--
-- 注意：計算單位是「成交事件」（events 中 event='transaction' 的每一列），
--       不是「人數」。一個人買多件商品會算多筆，所以總筆數（18,247）
--       會大於「總成交人數」（11,719）。
-- 過程：最初只看平均（2.69 小時），但平均會被極端值拉走，所以改成分區間看分布。
-- ============================================================
SELECT
    CASE
        WHEN diff_hours < 1  THEN '1小時內'
        WHEN diff_hours < 6  THEN '1-6小時'
        WHEN diff_hours < 24 THEN '6-24小時'
        WHEN diff_hours < 72 THEN '1-3天'
        ELSE '3天以上'
    END AS 時間區間,
    COUNT(*) AS 成交筆數,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS 佔比百分比   -- 視窗函式：算占全體的比例
FROM (
    SELECT (transaction_time - addtocart_time) / 1000.0 / 3600 AS diff_hours  -- 毫秒換算成小時
    FROM (
        SELECT
            t.timestamp AS transaction_time,
            (   -- 這筆成交之前，同一人、同一商品最近一次加購的時間
                SELECT MAX(a.timestamp)
                FROM events a
                WHERE a.visitorid = t.visitorid
                  AND a.itemid    = t.itemid
                  AND a.event     = 'addtocart'
                  AND a.timestamp <= t.timestamp
            ) AS addtocart_time
        FROM events t
        WHERE t.event = 'transaction'
    ) sub1
    WHERE addtocart_time IS NOT NULL   -- 排除「沒加購、直接結帳」的成交
) sub2
GROUP BY 時間區間
ORDER BY MIN(diff_hours);
