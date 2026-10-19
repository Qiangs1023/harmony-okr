-- 周记（对齐页）：每周一句话
-- 与其他业务表一致：软删除 + last_device + change_log
CREATE TABLE IF NOT EXISTS review (
  id           TEXT PRIMARY KEY,
  user_id      TEXT NOT NULL,
  objective_id TEXT NOT NULL DEFAULT '',
  week_key     TEXT NOT NULL DEFAULT '',
  text         TEXT NOT NULL DEFAULT '',
  created_at   BIGINT NOT NULL,
  updated_at   BIGINT NOT NULL,
  last_device  TEXT NOT NULL DEFAULT '',
  deleted      SMALLINT NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS review_user_idx ON review (user_id, deleted);

-- 老用户补齐 change_log 里已有的游标语义无需处理：新行首次推送即产生日志
