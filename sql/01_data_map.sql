-- ============================================================
-- 01 資料地圖：拿到資料庫先做的五項基礎檢查
--   ① 有哪些表  ② 每張表一列代表什麼  ③ 時間範圍  ④ 資料乾不乾淨  ⑤ 表與表怎麼串
-- ============================================================

-- ① 有哪些表（結果：events / category_tree / item_properties_part1 / item_properties_part2）
SELECT name FROM sqlite_master WHERE type = 'table';

-- 各表欄位結構（PRAGMA 是 SQLite 專用，查「表的說明書」而不是表裡的資料）
-- events：timestamp / visitorid / event / itemid / transactionid
PRAGMA table_info(events);
PRAGMA table_info(category_tree);          -- categoryid / parentid（自我參照的樹狀結構）
PRAGMA table_info(item_properties_part1);  -- timestamp / itemid / property / value（長格式：一個屬性一列）
PRAGMA table_info(item_properties_part2);

-- 各表筆數（UNION ALL：把多個查詢的結果一列一列疊起來）
-- 結果：events 2,756,101 / category_tree 1,669 / part1 10,999,999 / part2 9,275,903
SELECT 'events' AS tbl, COUNT(*) AS cnt FROM events
UNION ALL
SELECT 'category_tree', COUNT(*) FROM category_tree
UNION ALL
SELECT 'item_properties_part1', COUNT(*) FROM item_properties_part1
UNION ALL
SELECT 'item_properties_part2', COUNT(*) FROM item_properties_part2;

-- ② 每張表一列代表什麼（grain，依 Kaggle 資料說明）
--   events：一列 = 一次行為事件（view / addtocart / transaction）
--   item_properties：一列 = 某商品在某時間點的某一項屬性

-- ③ 時間範圍（毫秒 timestamp）
-- 結果：1430622004384 ~ 1442545187788，約 2015-05-03 ~ 2015-09-18，共 4.5 個月
-- 影響：只有 4.5 個月，不能做季節性 / 年度比較，也看不出長期回購
SELECT MIN(timestamp), MAX(timestamp) FROM events;

-- ④ 資料乾不乾淨：events 裡有多少商品在屬性表完全查不到（幽靈商品）
-- 結果：235,061 種商品中有 49,815 種查不到屬性（約 21.2%）
-- 影響：往後凡是用到「分類」的分析，都會排除這 21.2% 的商品（報告中要揭露）
SELECT COUNT(DISTINCT e.itemid) AS 查不到屬性的商品數
FROM events e
WHERE NOT EXISTS (
    SELECT 1 FROM item_properties_part1 p WHERE p.itemid = e.itemid
    UNION
    SELECT 1 FROM item_properties_part2 p WHERE p.itemid = e.itemid
);

-- ⑤ 表與表怎麼串：events.itemid → item_properties（property='categoryid'）→ category_tree
-- 注意：value 欄位是 TEXT，categoryid 是 INTEGER，要 CAST 才串得起來
-- 結果：串接成功（例：itemid 460429 → categoryid 1338 → parentid 1278）
SELECT ip.itemid, ip.value AS categoryid_as_text, ct.categoryid, ct.parentid
FROM item_properties_part1 ip
JOIN category_tree ct ON ct.categoryid = CAST(ip.value AS INTEGER)
WHERE ip.property = 'categoryid'
LIMIT 5;
