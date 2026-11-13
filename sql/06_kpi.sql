-- ============================================================
-- 06 Dashboard 的 KPI 卡片
-- 為什麼用這三個：資料裡的價格與數量是加密過的，沒有金額 / 訂單量，
--                 所以改用行為型指標（規模 + 效率）。
-- 口徑：全部是「不重複訪客」（visitorid）
-- ============================================================

-- 1. 總瀏覽人數（規模）。結果：1,404,179
SELECT COUNT(DISTINCT visitorid) AS 總瀏覽人數
FROM events WHERE event = 'view';

-- 2. 總成交人數（結果）。結果：11,719
SELECT COUNT(DISTINCT visitorid) AS 總成交人數
FROM events WHERE event = 'transaction';

-- 3. 整體轉換率 = 成交人數 / 瀏覽人數（效率）。結果：0.83%
SELECT ROUND(
    COUNT(DISTINCT CASE WHEN event = 'transaction' THEN visitorid END) * 100.0
  / COUNT(DISTINCT CASE WHEN event = 'view'        THEN visitorid END), 2
) AS 整體轉換率
FROM events;
