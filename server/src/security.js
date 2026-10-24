import crypto from 'node:crypto';
import jwt from 'jsonwebtoken';
import config from './config.js';

// ===== Mật khẩu: scrypt (KDF dựa bộ nhớ, mạnh hơn bcrypt) + salt ngẫu nhiên =====
const SCRYPT = { N: 16384, r: 8, p: 1, keylen: 64 };
const MAXMEM = 128 * SCRYPT.N * SCRYPT.r * SCRYPT.p + 8 * 1024 * 1024;

export function hashPassword(password) {
  const salt = crypto.randomBytes(16);
  const hash = crypto.scryptSync(password, salt, SCRYPT.keylen, {
    N: SCRYPT.N, r: SCRYPT.r, p: SCRYPT.p, maxmem: MAXMEM,
  });
  return [
    'scrypt', SCRYPT.N, SCRYPT.r, SCRYPT.p,
    salt.toString('base64'), hash.toString('base64'),
  ].join('$');
}

export function verifyPassword(password, stored) {
  try {
    const [algo, N, r, p, saltB64, hashB64] = String(stored).split('$');
    if (algo !== 'scrypt') return false;
    const salt = Buffer.from(saltB64, 'base64');
    const expected = Buffer.from(hashB64, 'base64');
    const actual = crypto.scryptSync(password, salt, expected.length, {
      N: Number(N), r: Number(r), p: Number(p), maxmem: MAXMEM,
    });
    return crypto.timingSafeEqual(actual, expected);
  } catch {
    return false;
  }
}

// ===== Access token (JWT) =====
export function signAccessToken(user) {
  return jwt.sign({ sub: user.id, email: user.email }, config.jwtSecret, {
    expiresIn: config.accessTokenTtlSec,
  });
}

export function verifyAccessToken(token) {
  return jwt.verify(token, config.jwtSecret);
}

// ===== Refresh token: chuỗi ngẫu nhiên, chỉ lưu SHA-256 trong DB =====
export function newRefreshTokenValue() {
  return crypto.randomBytes(48).toString('base64url');
}

export function hashToken(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}

export function randomId(prefix) {
  return `${prefix}_${crypto.randomBytes(9).toString('base64url')}`;
}

export function sha256Hex(buf) {
  return crypto.createHash('sha256').update(buf).digest('hex');
}
