-- ============================================================
-- 07 補查：categoryid 640 為何轉換率 100%？會不會是剛上架的新品效應？
-- 假設：640 是新品類別 → 結果：不是。
--       640 底下的商品最早在 2015-05-14、05-17 就出現，不是後期才上架。
--       （640 的 33 位加購者本身就太少，所以 dashboard 用「加購人數 > 50」濾掉它。）
-- ============================================================

-- 上層分類（結果：parentid = 55）
SELECT categoryid, parentid FROM category_tree WHERE categoryid = 640;

-- 640 底下的商品第一次出現在 events 的時間
WITH items_in_640 AS (
    SELECT itemid FROM item_properties_part1
    WHERE property = 'categoryid' AND CAST(value AS INTEGER) = 640
    UNION
    SELECT itemid FROM item_properties_part2
    WHERE property = 'categoryid' AND CAST(value AS INTEGER) = 640
)
SELECT
    e.itemid,
    MIN(e.timestamp) AS 最早出現時間戳記,
    datetime(MIN(e.timestamp) / 1000, 'unixepoch') AS 最早出現日期
FROM events e
JOIN items_in_640 i ON i.itemid = e.itemid
GROUP BY e.itemid
ORDER BY 最早出現時間戳記;
