CREATE DATABASE IF NOT EXISTS budget_system CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE budget_system;

-- ============================================================
-- 注意: このスクリプトは毎回起動時に実行される（spring.sql.init.mode=always）。
--       テーブルは IF NOT EXISTS で「無ければ作る」だけにし、DROP はしない。
--       これにより入力したデータは再起動しても保持される（年度集計の前提）。
--       マスタ（補助金区分）だけ INSERT IGNORE で投入する。
-- ============================================================

-- 名簿マスタ
CREATE TABLE IF NOT EXISTS members (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    age INT,
    grade VARCHAR(50),
    role VARCHAR(50) DEFAULT '選手', -- '選手' or '指導者'
    departure_point VARCHAR(200)
);

-- 予算種別マスタ
CREATE TABLE IF NOT EXISTS budget_types (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT
);

-- 事業（プロジェクト）情報
CREATE TABLE IF NOT EXISTS projects (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    budget_type_id INT,
    target_category VARCHAR(100), -- '成年男子', '少年男子' など
    event_date DATE NOT NULL,
    location_venue VARCHAR(200),
    location_accommodation VARCHAR(200),
    schedule_content TEXT, -- 日程及び内容
    project_outcome TEXT, -- 事業の成果
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (budget_type_id) REFERENCES budget_types(id)
);

-- 事業参加者
CREATE TABLE IF NOT EXISTS project_participants (
    id INT AUTO_INCREMENT PRIMARY KEY,
    project_id INT NOT NULL,
    member_id INT NOT NULL,
    is_accommodated BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
    FOREIGN KEY (member_id) REFERENCES members(id)
);

-- 経費情報（個人ごと）
CREATE TABLE IF NOT EXISTS expenses (
    id INT AUTO_INCREMENT PRIMARY KEY,
    project_participant_id INT NOT NULL,
    expense_date DATE, -- 期日 (2-6の各行の期日)
    transport_method VARCHAR(100), -- 交通手段 (航空機・バス, 電車・車)
    transport_route VARCHAR(200), -- 区間
    transport_distance_km INT, -- 距離(km)
    transport_cost INT DEFAULT 0, -- 交通費
    accommodation_cost INT DEFAULT 0, -- 宿泊費
    miscellaneous_cost INT DEFAULT 0, -- 雑費
    receipt_date DATE, -- 受領日
    FOREIGN KEY (project_participant_id) REFERENCES project_participants(id) ON DELETE CASCADE
);

-- 経費情報（事業全体）
CREATE TABLE IF NOT EXISTS project_summary_expenses (
    id INT AUTO_INCREMENT PRIMARY KEY,
    project_id INT NOT NULL,
    rental_cost INT DEFAULT 0, -- 借用料
    supplies_cost INT DEFAULT 0, -- 需用費
    parking_cost INT DEFAULT 0, -- 駐車料
    compensation_cost INT DEFAULT 0, -- 報償費
    service_cost INT DEFAULT 0, -- 役務費
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
);

-- 補助金区分マスタ（アプリ動作に必須。既にあれば無視）
INSERT IGNORE INTO budget_types (id, name) VALUES (1, '選手強化費');
INSERT IGNORE INTO budget_types (id, name) VALUES (2, 'トップチーム活用事業');
INSERT IGNORE INTO budget_types (id, name) VALUES (3, 'ふるさと選手活動支援');

-- 学習型距離マスタ（出発地と目的地の組み合わせを記憶）
CREATE TABLE IF NOT EXISTS route_master (
    id INT AUTO_INCREMENT PRIMARY KEY,
    departure VARCHAR(200) NOT NULL,
    destination VARCHAR(200) NOT NULL,
    distance_km INT NOT NULL,
    UNIQUE KEY (departure, destination)
);

-- 操作ユーザーマスタ
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    phone_number VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- システム設定（active_user_id など）
CREATE TABLE IF NOT EXISTS system_settings (
    setting_key VARCHAR(100) PRIMARY KEY,
    setting_value VARCHAR(255) NOT NULL
);

-- 初期ユーザー登録（id固定なし・氏名+電話番号が未登録の場合のみ）
INSERT INTO users (name, phone_number)
SELECT '齋藤 和明', '090-5288-9928'
WHERE NOT EXISTS (
    SELECT 1 FROM users
    WHERE name = '齋藤 和明'
      AND phone_number = '090-5288-9928'
);

-- active_user_id の初期設定（未設定の場合のみ・既存値は維持）
INSERT INTO system_settings (setting_key, setting_value)
SELECT 'active_user_id', CAST(id AS CHAR)
FROM users
WHERE name = '齋藤 和明'
  AND phone_number = '090-5288-9928'
ORDER BY id
LIMIT 1
ON DUPLICATE KEY UPDATE setting_value = setting_value;

-- 過去データの交通手段マイグレーション（旧複合値 → 新単体値）
UPDATE expenses SET transport_method = '電車'  WHERE transport_method = '電車・車';
UPDATE expenses SET transport_method = '航空機' WHERE transport_method = '航空機・バス';

-- Cycle 8: 新規カラム追加（IF NOT EXISTS で安全に追加）
ALTER TABLE projects ADD COLUMN IF NOT EXISTS accommodation_nights INT DEFAULT 0;
ALTER TABLE project_summary_expenses ADD COLUMN IF NOT EXISTS travel_misc_cost INT DEFAULT 0;
ALTER TABLE project_summary_expenses ADD COLUMN IF NOT EXISTS travel_misc_days INT DEFAULT 0;

-- Cycle 12B: 予算管理（内示額）マスタ。決算額は保存せず、既存事業データから都度集計する。
CREATE TABLE IF NOT EXISTS budget_allocations (
    id INT AUTO_INCREMENT PRIMARY KEY,
    fiscal_year INT NOT NULL,
    budget_type_id INT NOT NULL,
    target_category VARCHAR(100) NOT NULL,
    allocated_amount BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_budget_allocations_year_type_category (fiscal_year, budget_type_id, target_category),
    FOREIGN KEY (budget_type_id) REFERENCES budget_types(id)
);
