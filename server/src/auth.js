import express from 'express';
import rateLimit from 'express-rate-limit';
import db, { publicUser, getUser, getUserByEmail } from './db.js';
import {
  hashPassword, verifyPassword, signAccessToken, verifyAccessToken,
  newRefreshTokenValue, hashToken, randomId,
} from './security.js';
import config from './config.js';

// ===== middleware xác thực Bearer token =====
// Mọi API nghiệp vụ đều đi qua đây; chỉ cần verify chữ ký JWT và gắn userId
// vào request, phần phân quyền chi tiết do từng route xử lý.
export function authMiddleware(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) return res.status(401).json({ error: 'unauthorized' });
  try {
    const payload = verifyAccessToken(token);
    req.userId = payload.sub;
    next();
  } catch {
    return res.status(401).json({ error: 'invalid_token' });
  }
}

// ===== helper phát hành token =====
// Access token ngắn hạn ký JWT; refresh token dài hạn chỉ lưu hash trong DB.
// familyId giữ nguyên khi xoay token để phát hiện token cũ bị dùng lại.
export function issueTokenPair(userId, familyId) {
  const user = getUser(userId);
  const accessToken = signAccessToken(user);
  const refreshToken = newRefreshTokenValue();
  const family = familyId || randomId('fam');
  db.prepare(`
    INSERT INTO refresh_tokens (id, user_id, token_hash, family_id, expires_at)
    VALUES (?, ?, ?, ?, ?)
  `).run(randomId('rt'), userId, hashToken(refreshToken), family,
        Date.now() + config.refreshTokenTtlSec * 1000);
  return {
    accessToken,
    refreshToken,
    expiresInSec: config.accessTokenTtlSec,
    refreshTokenExpiresAt: new Date(Date.now() + config.refreshTokenTtlSec * 1000).toISOString(),
  };
}

// Thu hồi toàn bộ refresh token cùng một chuỗi phiên (family).
// Dùng khi phát hiện token đã xoay bị dùng lại — coi như phiên bị đánh cắp.
function revokeFamily(familyId) {
  db.prepare('UPDATE refresh_tokens SET revoked = 1 WHERE family_id = ?').run(familyId);
}

// ===== validation =====
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
export function validPassword(p) {
  return typeof p === 'string' && p.length >= 8 && p.length <= 128 &&
    /[A-Za-z]/.test(p) && /[0-9]/.test(p);
}

// ===== rate limit: chống dò mật khẩu =====
// Khóa theo IP + email: vẫn chặn mạnh 1 tài khoản, nhưng không chặn
// các email khác nhau (đăng ký/đăng nhập song song vẫn bình thường).
const ipOf = (req) => String(req.socket.remoteAddress || 'unknown');
const emailOf = (req) => String(req.body?.email || '').trim().toLowerCase();

const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 15,
  keyGenerator: (req) => `${ipOf(req)}|${emailOf(req)}`,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'too_many_requests' },
});

const registerLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 15,
  keyGenerator: (req) => `${ipOf(req)}|${emailOf(req)}`,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'too_many_requests' },
});

const router = express.Router();

// ===== Đăng ký =====
router.post('/register', registerLimiter, (req, res) => {
  const { email, password, name } = req.body || {};
  if (typeof email !== 'string' || !EMAIL_RE.test(email.trim().toLowerCase())) {
    return res.status(400).json({ error: 'invalid_email', message: 'Email không hợp lệ' });
  }
  if (!validPassword(password)) {
    return res.status(400).json({
      error: 'weak_password',
      message: 'Mật khẩu cần 8+ ký tự, gồm chữ và số',
    });
  }
  const cleanName = String(name || '').trim();
  if (cleanName.length < 2 || cleanName.length > 30) {
    return res.status(400).json({ error: 'invalid_name', message: 'Tên cần 2-30 ký tự' });
  }
  const normalizedEmail = email.trim().toLowerCase();
  if (getUserByEmail(normalizedEmail)) {
    return res.status(409).json({ error: 'email_taken', message: 'Email đã được đăng ký' });
  }

  const id = randomId('u');
  const avatars = ['🦊', '🐱', '🐰', '🐻', '🐼', '🐯', '🦁', '🐸', '🐵', '🐶'];
  const avatar = avatars[Math.floor(Math.random() * avatars.length)];
  db.prepare(`
    INSERT INTO users (id, email, password_hash, name, avatar, profile_completed)
    VALUES (?, ?, ?, ?, ?, 0)
  `).run(id, normalizedEmail, hashPassword(password), cleanName, avatar);

  const tokens = issueTokenPair(id);
  const user = publicUser(getUser(id));
  res.status(201).json({ user, ...tokens });
});

// ===== Đăng nhập =====
router.post('/login', loginLimiter, (req, res) => {
  const { email, password } = req.body || {};
  if (typeof email !== 'string' || typeof password !== 'string') {
    return res.status(400).json({ error: 'invalid_request', message: 'Thiếu email hoặc mật khẩu' });
  }
  const user = getUserByEmail(email.trim().toLowerCase());
  if (!user) {
    // cùng thời gian trả lời như khi sai mật khẩu (tránh dò email)
    hashPassword(password);
    return res.status(401).json({ error: 'bad_credentials', message: 'Email hoặc mật khẩu không đúng' });
  }

  // Khóa tạm sau nhiều lần sai liên tiếp, tránh dò mật khẩu qua API.
  const now = Date.now();
  if (user.locked_until && user.locked_until > now) {
    const mins = Math.ceil((user.locked_until - now) / 60000);
    return res.status(423).json({
      error: 'locked',
      message: `Tài khoản tạm khóa ${mins} phút do nhập sai nhiều lần`,
    });
  }

  // Sai mật khẩu: tăng bộ đếm; đủ 5 lần thì khóa 15 phút.
  if (!verifyPassword(password, user.password_hash)) {
    const attempts = user.failed_attempts + 1;
    const patch = { failed_attempts: attempts, locked_until: null };
    if (attempts >= 5) patch.locked_until = now + 15 * 60 * 1000;
    db.prepare('UPDATE users SET failed_attempts = ?, locked_until = ? WHERE id = ?')
      .run(patch.failed_attempts, patch.locked_until, user.id);
    return res.status(401).json({ error: 'bad_credentials', message: 'Email hoặc mật khẩu không đúng' });
  }

  db.prepare('UPDATE users SET failed_attempts = 0, locked_until = NULL WHERE id = ?').run(user.id);
  const tokens = issueTokenPair(user.id);
  res.json({ user: publicUser(getUser(user.id)), ...tokens });
});

// ===== Làm mới access token (xoay refresh, phát hiện bị đánh cắp) =====
router.post('/refresh', (req, res) => {
  const { refreshToken } = req.body || {};
  if (typeof refreshToken !== 'string' || !refreshToken) {
    return res.status(400).json({ error: 'invalid_request' });
  }
  const row = db.prepare('SELECT * FROM refresh_tokens WHERE token_hash = ?')
    .get(hashToken(refreshToken));
  if (!row) return res.status(401).json({ error: 'invalid_refresh' });

  if (row.revoked) {
    // Token đã bị dùng lại -> có dấu hiệu đánh cắp -> thu hồi cả gia đình
    revokeFamily(row.family_id);
    return res.status(401).json({ error: 'refresh_reuse_detected' });
  }
  if (row.expires_at < Date.now()) {
    return res.status(401).json({ error: 'refresh_expired' });
  }

  // Xoay token: token cũ bị thu hồi ngay, token mới nằm cùng family.
  // Nếu token cũ xuất hiện lại lần nữa, nhánh row.revoked phía trên sẽ khóa cả family.
  db.prepare('UPDATE refresh_tokens SET revoked = 1 WHERE id = ?').run(row.id);
  const tokens = issueTokenPair(row.user_id, row.family_id);
  const user = publicUser(getUser(row.user_id));
  res.json({ user, ...tokens });
});

// ===== Đăng xuất (thu hồi refresh token) =====
// Client vẫn phải xóa token cục bộ; server thu hồi refresh để không gia hạn được nữa.
router.post('/logout', (req, res) => {
  const { refreshToken } = req.body || {};
  if (typeof refreshToken === 'string' && refreshToken) {
    db.prepare('UPDATE refresh_tokens SET revoked = 1 WHERE token_hash = ?')
      .run(hashToken(refreshToken));
  }
  res.status(204).end();
});

export default router;
