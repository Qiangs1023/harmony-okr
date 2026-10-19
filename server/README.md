# OKR 后端 API

配套 `HarmonyOS应用后端数据库部署` 文档的自建同步服务。

## 接口

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/health` | 健康检查 |
| POST | `/api/auth/register` | 注册 → 返回 JWT |
| POST | `/api/auth/login` | 登录 → 返回 JWT |
| GET | `/api/sync?sinceSeq=N` | 增量拉取（基于 `change_log.seq`） |
| POST | `/api/sync` | 批量上推 + 删除同步 |

## 设计要点

- **冲突判定**：每张业务表带 `last_device`，同设备重复写入无条件接受（避免"同一台设备连续编辑被误判为冲突"）；跨设备才比较 `updated_at`，服务端版本胜出。
- **同步游标**：用 `change_log.seq`（BIGSERIAL）而非时间戳，避免同毫秒写入丢更新。
- **软删**：删除写 `deleted=1` 并记 change_log，拉取时过滤 `deleted=0`，避免删掉的数据被拉回客户端复活。
- **标签/项目主键**：`tag` 用 `name`、`project` 用 `id`，与其余实体不同，`applyUpsert` 里单独处理。

## 本地运行

需要先有 PostgreSQL：

```bash
docker network create okr-db_default
POSTGRES_DB=okr POSTGRES_USER=okr POSTGRES_PASSWORD=xxx docker run -d \
  --name okr-postgres --network okr-db_default \
  -e POSTGRES_DB -e POSTGRES_USER -e POSTGRES_PASSWORD \
  postgres:16-alpine
```

初始化 schema 见 `../../entry/../docs` 或直接执行建表 SQL（见部署文档）。

```bash
npm install
PGHOST=okr-postgres PGUSER=okr PGPASSWORD=xxx PGDATABASE=okr \
JWT_SECRET=$(openssl rand -hex 32) PORT=8088 node src/server.js
```

## 生产部署

见 `okr-api/docker-compose.yml`，服务器实际部署在 `/opt/okr-api/`，数据库在 `/opt/okr-db/`。

```bash
cd /opt/okr-api && docker compose up -d --build
/opt/okr-db/backup.sh     # 手动备份
```

> `.env` 含数据库密码与 JWT 密钥，已被 `.gitignore` 排除，禁止入库。
