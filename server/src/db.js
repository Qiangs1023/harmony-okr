import pg from 'pg';
import crypto from 'node:crypto';

const { Pool } = pg;

const pool = new Pool({
  host: process.env.PGHOST,
  port: Number(process.env.PGPORT || 5432),
  user: process.env.PGUSER,
  password: process.env.PGPASSWORD,
  database: process.env.PGDATABASE,
  max: 4,
  idleTimeoutMillis: 30000
});

pool.on('error', (err) => {
  console.error('[pg] idle client error:', err.message);
});

export function nowMs() {
  return Date.now();
}

export function newId(prefix) {
  return `${prefix}_${Date.now().toString(36)}_${crypto.randomBytes(5).toString('hex')}`;
}

export async function withTx(fn) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const out = await fn(client);
    await client.query('COMMIT');
    return out;
  } catch (e) {
    await client.query('ROLLBACK').catch(() => {});
    throw e;
  } finally {
    client.release();
  }
}

const LOG_SQL = 'INSERT INTO change_log (user_id, entity, entity_id, updated_at, deleted) VALUES ($1, $2, $3, $4, $5)';

export function logChange(client, userId, entity, entityId, updatedAt, deleted) {
  return client.query(LOG_SQL, [userId, entity, entityId, updatedAt, deleted ? 1 : 0]);
}

export { pool };
