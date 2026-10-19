import http from 'node:http';
import { pool, withTx, nowMs, newId, logChange } from './db.js';
import { issueToken, verifyToken, hashPassword, verifyPassword } from './auth.js';

const PORT = Number(process.env.PORT || 8088);
const MAX_BODY = 5 * 1024 * 1024;
const PAGE_LIMIT = 5000;

// 实体顺序无关紧要；tag 与 project 的主键字段名与其余实体不同，由 applyUpsert 单独处理
const ENTITIES = [
  ['objective', 'objectives'],
  ['kr', 'krs'],
  ['idea', 'ideas'],
  ['project', 'projects'],
  ['tag', 'tags']
];

function send(res, code, obj) {
  const buf = Buffer.from(JSON.stringify(obj), 'utf8');
  res.writeHead(code, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': buf.length,
    'Cache-Control': 'no-store'
  });
  res.end(buf);
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    req.on('data', (c) => {
      size += c.length;
      if (size > MAX_BODY) {
        reject(new Error('PAYLOAD_TOO_LARGE'));
        req.destroy();
        return;
      }
      chunks.push(c);
    });
    req.on('end', () => {
      const raw = Buffer.concat(chunks).toString('utf8');
      if (!raw.trim()) return resolve({});
      try {
        const v = JSON.parse(raw);
        resolve(v && typeof v === 'object' && !Array.isArray(v) ? v : {});
      } catch {
        reject(new Error('INVALID_JSON'));
      }
    });
    req.on('error', reject);
  });
}

function str(v, max = 512) {
  return typeof v === 'string' ? v.slice(0, max) : '';
}

function num(v) {
  const n = typeof v === 'number' ? v : Number(v);
  return Number.isFinite(n) ? Math.trunc(n) : 0;
}

function bool01(v) {
  return v === true || v === 1 || v === '1' ? 1 : 0;
}

function strArr(v) {
  if (!Array.isArray(v)) return [];
  return v.filter((x) => typeof x === 'string').map((x) => x.slice(0, 64)).slice(0, 20);
}

function mapObjective(r) {
  return {
    id: r.id,
    title: r.title,
    period: r.period,
    note: r.note,
    projectId: r.project_id || '',
    createdAt: Number(r.created_at),
    updatedAt: Number(r.updated_at)
  };
}

function mapKr(r) {
  return {
    id: r.id,
    objectiveId: r.objective_id,
    title: r.title,
    targetValue: r.target_value,
    dueDate: Number(r.due_date),
    projectId: r.project_id || '',
    createdAt: Number(r.created_at),
    updatedAt: Number(r.updated_at)
  };
}

function mapIdea(r) {
  return {
    id: r.id,
    title: r.title,
    note: r.note,
    tags: Array.isArray(r.tags) ? r.tags : [],
    priority: Number(r.priority),
    dueDate: Number(r.due_date),
    krId: r.kr_id,
    projectId: r.project_id || '',
    done: Number(r.done) === 1,
    createdAt: Number(r.created_at),
    updatedAt: Number(r.updated_at)
  };
}

function mapProject(r) {
  return {
    id: r.id,
    title: r.title,
    note: r.note,
    colorIndex: Number(r.color_index),
    archived: Number(r.archived) === 1,
    createdAt: Number(r.created_at),
    updatedAt: Number(r.updated_at)
  };
}

function mapTag(r) {
  return { name: r.name, colorIndex: Number(r.color_index), sortIndex: Number(r.sort_index) };
}

function requireUser(req) {
  const header = req.headers['authorization'];
  if (typeof header !== 'string' || !header.startsWith('Bearer ')) return null;
  return verifyToken(header.slice(7).trim());
}

async function pull(userId, sinceSeq) {
  const { rows: changes } = await pool.query(
    'SELECT seq, entity, entity_id FROM change_log WHERE user_id = $1 AND seq > $2 ORDER BY seq ASC LIMIT $3',
    [userId, sinceSeq, PAGE_LIMIT]
  );
  const cursor = changes.length ? Number(changes[changes.length - 1].seq) : sinceSeq;
  const ids = { objective: new Set(), kr: new Set(), idea: new Set(), tag: new Set(), project: new Set() };
  for (const c of changes) {
    if (ids[c.entity]) ids[c.entity].add(c.entity_id);
  }

  const out = { cursor, hasMore: changes.length === PAGE_LIMIT, objectives: [], krs: [], ideas: [], tags: [], projects: [] };

  if (ids.objective.size) {
    const r = await pool.query(
      'SELECT id,title,period,note,project_id,created_at,updated_at FROM objective WHERE user_id=$1 AND deleted=0 AND id = ANY($2)',
      [userId, [...ids.objective]]
    );
    out.objectives = r.rows.map(mapObjective);
  }
  if (ids.kr.size) {
    const r = await pool.query(
      'SELECT id,objective_id,title,target_value,due_date,project_id,created_at,updated_at FROM kr WHERE user_id=$1 AND deleted=0 AND id = ANY($2)',
      [userId, [...ids.kr]]
    );
    out.krs = r.rows.map(mapKr);
  }
  if (ids.idea.size) {
    const r = await pool.query(
      'SELECT id,title,note,tags,priority,due_date,kr_id,project_id,done,created_at,updated_at FROM idea WHERE user_id=$1 AND deleted=0 AND id = ANY($2)',
      [userId, [...ids.idea]]
    );
    out.ideas = r.rows.map(mapIdea);
  }
  if (ids.project.size) {
    const r = await pool.query(
      'SELECT id,title,note,color_index,archived,created_at,updated_at FROM project WHERE user_id=$1 AND deleted=0 AND id = ANY($2)',
      [userId, [...ids.project]]
    );
    out.projects = r.rows.map(mapProject);
  }
  if (ids.tag.size) {
    const r = await pool.query(
      'SELECT name,color_index,sort_index FROM tag WHERE user_id=$1 AND name = ANY($2) ORDER BY sort_index',
      [userId, [...ids.tag]]
    );
    out.tags = r.rows.map(mapTag);
  }
  return out;
}

async function applyUpsert(client, userId, deviceId, entity, item) {
  // tag / project 的标识字段在协议上是 name / id，其余实体统一是 id
  const id = entity === 'tag' ? str(item.name, 64) : str(item.id, 64);
  if (!id) return null;

  const incoming = num(item.updatedAt);
  const created = num(item.createdAt) || nowMs();
  const stamp = Math.max(nowMs(), incoming + 1);

  if (entity === 'tag') {
    await client.query(
      `INSERT INTO tag (user_id,name,color_index,sort_index) VALUES ($1,$2,$3,$4)
       ON CONFLICT (user_id,name) DO UPDATE SET color_index=EXCLUDED.color_index,
         sort_index=EXCLUDED.sort_index`,
      [userId, id, num(item.colorIndex), num(item.sortIndex)]
    );
    await logChange(client, userId, entity, id, stamp, 0);
    return { conflict: false };
  }

  const existing = await client.query(
    `SELECT updated_at, deleted, last_device FROM ${entity} WHERE user_id=$1 AND id=$2`,
    [userId, id]
  );

  if (existing.rowCount > 0) {
    const sameDevice = existing.rows[0].last_device === deviceId;
    if (!sameDevice && Number(existing.rows[0].updated_at) > incoming) {
      return { conflict: true, entity, id };
    }
  }

  if (entity === 'objective') {
    await client.query(
      `INSERT INTO objective (id,user_id,title,period,note,project_id,created_at,updated_at,last_device,deleted)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,0)
       ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, period=EXCLUDED.period,
         note=EXCLUDED.note, project_id=EXCLUDED.project_id, updated_at=EXCLUDED.updated_at,
         last_device=EXCLUDED.last_device, deleted=0`,
      [id, userId, str(item.title), str(item.period, 64), str(item.note, 4000), str(item.projectId, 64),
        created, stamp, deviceId]
    );
  } else if (entity === 'kr') {
    await client.query(
      `INSERT INTO kr (id,user_id,objective_id,title,target_value,due_date,project_id,created_at,updated_at,last_device,deleted)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,0)
       ON CONFLICT (id) DO UPDATE SET objective_id=EXCLUDED.objective_id, title=EXCLUDED.title,
         target_value=EXCLUDED.target_value, due_date=EXCLUDED.due_date, project_id=EXCLUDED.project_id,
         updated_at=EXCLUDED.updated_at, last_device=EXCLUDED.last_device, deleted=0`,
      [id, userId, str(item.objectiveId, 64), str(item.title), str(item.targetValue, 128), num(item.dueDate),
        str(item.projectId, 64), created, stamp, deviceId]
    );
  } else if (entity === 'idea') {
    await client.query(
      `INSERT INTO idea (id,user_id,title,note,tags,priority,due_date,kr_id,project_id,done,created_at,updated_at,last_device,deleted)
       VALUES ($1,$2,$3,$4,$5::jsonb,$6,$7,$8,$9,$10,$11,$12,$13,0)
       ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, note=EXCLUDED.note, tags=EXCLUDED.tags,
         priority=EXCLUDED.priority, due_date=EXCLUDED.due_date, kr_id=EXCLUDED.kr_id,
         project_id=EXCLUDED.project_id, done=EXCLUDED.done, updated_at=EXCLUDED.updated_at,
         last_device=EXCLUDED.last_device, deleted=0`,
      [id, userId, str(item.title), str(item.note, 4000), JSON.stringify(strArr(item.tags)),
        Math.min(2, Math.max(0, num(item.priority))), num(item.dueDate), str(item.krId, 64),
        str(item.projectId, 64), bool01(item.done), created, stamp, deviceId]
    );
  } else if (entity === 'project') {
    await client.query(
      `INSERT INTO project (id,user_id,title,note,color_index,archived,created_at,updated_at,last_device,deleted)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,0)
       ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, note=EXCLUDED.note,
         color_index=EXCLUDED.color_index, archived=EXCLUDED.archived, updated_at=EXCLUDED.updated_at,
         last_device=EXCLUDED.last_device, deleted=0`,
      [id, userId, str(item.title), str(item.note, 4000), num(item.colorIndex), bool01(item.archived),
        created, stamp, deviceId]
    );
  }

  await logChange(client, userId, entity, id, stamp, 0);
  return { conflict: false };
}

async function applyDelete(client, userId, deviceId, entity, id) {
  const key = str(id, 64);
  if (!key) return;

  const cur = await client.query(
    `SELECT updated_at FROM ${entity} WHERE user_id=$1 AND ${entity === 'tag' ? 'name' : 'id'}=$2`,
    [userId, key]
  );
  const prev = cur.rowCount ? num(cur.rows[0].updated_at) : 0;
  const stamp = Math.max(nowMs(), prev + 1);

  if (entity === 'tag') {
    await client.query('DELETE FROM tag WHERE user_id=$1 AND name=$2', [userId, key]);
  } else {
    await client.query(
      `UPDATE ${entity} SET deleted=1, updated_at=$3, last_device=$4 WHERE user_id=$1 AND id=$2`,
      [userId, key, stamp, deviceId]
    );
  }
  await logChange(client, userId, entity, key, stamp, 1);
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  const path = url.pathname;
  const method = req.method || 'GET';

  if (method === 'GET' && path === '/health') {
    try {
      const r = await pool.query('SELECT 1 AS ok');
      return send(res, 200, { ok: r.rows[0].ok === 1, time: nowMs() });
    } catch (e) {
      return send(res, 500, { ok: false, error: e.message });
    }
  }

  if (method === 'POST' && path === '/api/auth/register') {
    let body;
    try { body = await readBody(req); } catch (e) { return send(res, 400, { error: e.message }); }
    const username = str(body.username, 64).trim();
    const password = str(body.password, 128);
    if (username.length < 3 || password.length < 6) {
      return send(res, 400, { error: 'username 至少 3 位, password 至少 6 位' });
    }
    try {
      const id = newId('u');
      const ts = nowMs();
      await pool.query(
        'INSERT INTO app_user (id,username,password_hash,created_at,updated_at) VALUES ($1,$2,$3,$4,$5)',
        [id, username, hashPassword(password), ts, ts]
      );
      return send(res, 200, { token: issueToken(id), userId: id, username });
    } catch (e) {
      if (e.code === '23505') return send(res, 409, { error: '用户名已存在' });
      return send(res, 500, { error: e.message });
    }
  }

  if (method === 'POST' && path === '/api/auth/login') {
    let body;
    try { body = await readBody(req); } catch (e) { return send(res, 400, { error: e.message }); }
    const username = str(body.username, 64).trim();
    const password = str(body.password, 128);
    const r = await pool.query(
      'SELECT id,username,password_hash FROM app_user WHERE username=$1', [username]
    );
    if (r.rowCount === 0 || !verifyPassword(password, r.rows[0].password_hash)) {
      return send(res, 401, { error: '用户名或密码错误' });
    }
    return send(res, 200, { token: issueToken(r.rows[0].id), userId: r.rows[0].id, username: r.rows[0].username });
  }

  if (path === '/api/sync' && (method === 'GET' || method === 'POST')) {
    const userId = requireUser(req);
    if (!userId) return send(res, 401, { error: '未授权' });

    try {
      if (method === 'GET') {
        const sinceSeq = num(url.searchParams.get('sinceSeq'));
        return send(res, 200, await pull(userId, sinceSeq));
      }

      const body = await readBody(req);
      const conflicts = [];
      const deviceId = str(body.deviceId, 64) || 'unknown-device';

      const result = await withTx(async (client) => {
        for (const [entity, key] of ENTITIES) {
          const list = Array.isArray(body[key]) ? body[key] : [];
          for (const item of list.slice(0, 2000)) {
            if (!item || typeof item !== 'object') continue;
            const r = await applyUpsert(client, userId, deviceId, entity, item);
            if (r && r.conflict) conflicts.push(r);
          }
        }

        const removed = body.removed && typeof body.removed === 'object' ? body.removed : {};
        for (const [entity, key] of ENTITIES) {
          const list = Array.isArray(removed[key]) ? removed[key] : [];
          for (const id of list.slice(0, 2000)) {
            await applyDelete(client, userId, deviceId, entity, id);
          }
        }

        const c = await client.query('SELECT max(seq) AS seq FROM change_log WHERE user_id=$1', [userId]);
        return Number(c.rows[0].seq || 0);
      });

      return send(res, 200, { cursor: result, conflicts });
    } catch (e) {
      if (e.message === 'INVALID_JSON') return send(res, 400, { error: 'INVALID_JSON' });
      if (e.message === 'PAYLOAD_TOO_LARGE') return send(res, 413, { error: 'PAYLOAD_TOO_LARGE' });
      console.error('[sync]', e.message);
      return send(res, 500, { error: e.message });
    }
  }

  return send(res, 404, { error: 'not found' });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`[okr-api] listening on 0.0.0.0:${PORT}`);
});

process.on('SIGTERM', () => server.close(() => process.exit(0)));
