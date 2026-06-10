CREATE DATABASE IF NOT EXISTS budget_system CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE budget_system;

-- 名簿マスタ
CREATE TABLE IF NOT EXISTS members (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    age INT,
    grade VARCHAR(50),
    role VARCHAR(50) DEFAULT '選手' -- '選手' or '指導者'
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
    transport_method VARCHAR(100),
    transport_cost INT DEFAULT 0,
    accommodation_cost INT DEFAULT 0,
    miscellaneous_cost INT DEFAULT 0,
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

-- 初期データの挿入
INSERT IGNORE INTO budget_types (id, name) VALUES (1, '選手強化費');
INSERT IGNORE INTO budget_types (id, name) VALUES (2, 'トップチーム活用事業');
INSERT IGNORE INTO budget_types (id, name) VALUES (3, 'ふるさと選手活動支援');

INSERT IGNORE INTO members (id, name, age, grade, role) VALUES 
(1, '長友　繁', 48, '', '選手'),
(2, '中村　里惟', 26, '', '選手'),
(3, '蛯原　智仁', 25, '', '選手'),
(4, '齋藤　豊光', NULL, '', '指導者');
