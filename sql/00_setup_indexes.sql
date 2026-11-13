-- ============================================================
-- 00 建立索引（先跑這份，後面的查詢才跑得動）
-- 為什麼：events 有 275 萬筆、item_properties 合計約 2,000 萬筆。
--         沒有索引時，單一查詢可能要跑數小時；SQLite 對這種量級本來就吃力。
-- ============================================================

-- 商品屬性表：用 itemid 找屬性（資料檢查、串分類時用）
CREATE INDEX IF NOT EXISTS idx_ip1_itemid ON item_properties_part1(itemid);
CREATE INDEX IF NOT EXISTS idx_ip2_itemid ON item_properties_part2(itemid);

-- 商品屬性表：先用 property（例如 'categoryid'）過濾，再用 itemid 串接
CREATE INDEX IF NOT EXISTS idx_ip1_property ON item_properties_part1(property, itemid);

-- events：依商品 + 行為類型統計
CREATE INDEX IF NOT EXISTS idx_events_itemid_event ON events(itemid, event);

-- events：依行為類型 + 訪客算不重複人數（KPI 用）
CREATE INDEX IF NOT EXISTS idx_events_event_visitorid ON events(event, visitorid);
