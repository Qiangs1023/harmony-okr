import crypto from 'node:crypto';

const SECRET = process.env.JWT_SECRET || '';
const TTL_MS = 1000 * 60 * 60 * 24 * 30;

function b64u(buf) {
  return Buffer.from(buf).toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function b64uDecode(str) {
  return Buffer.from(str.replace(/-/g, '+').replace(/_/g, '/'), 'base64').toString();
}

function sign(data) {
  return b64u(crypto.createHmac('sha256', SECRET).update(data).digest());
}

export function issueToken(userId) {
  const header = b64u(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const payload = b64u(JSON.stringify({ uid: userId, exp: Date.now() + TTL_MS }));
  const body = `${header}.${payload}`;
  return `${body}.${sign(body)}`;
}

export function verifyToken(token) {
  if (!token || typeof token !== 'string') return null;
  const parts = token.split('.');
  if (parts.length !== 3) return null;
  const body = `${parts[0]}.${parts[1]}`;
  const expected = sign(body);
  const a = Buffer.from(expected);
  const b = Buffer.from(parts[2]);
  if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) return null;
  try {
    const payload = JSON.parse(b64uDecode(parts[1]));
    if (!payload || typeof payload.uid !== 'string') return null;
    if (typeof payload.exp === 'number' && payload.exp < Date.now()) return null;
    return payload.uid;
  } catch {
    return null;
  }
}

export function hashPassword(password) {
  const salt = crypto.randomBytes(16).toString('hex');
  const hash = crypto.scryptSync(password, salt, 32).toString('hex');
  return `scrypt$${salt}$${hash}`;
}

export function verifyPassword(password, stored) {
  if (typeof stored !== 'string') return false;
  const parts = stored.split('$');
  if (parts.length !== 3 || parts[0] !== 'scrypt') return false;
  const salt = parts[1];
  const expect = parts[2];
  const actual = crypto.scryptSync(password, salt, 32).toString('hex');
  const a = Buffer.from(actual);
  const b = Buffer.from(expect);
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}
