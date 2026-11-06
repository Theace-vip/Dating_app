// db.js — Lớp truy cập SQLite (node:sqlite, không cần driver ngoài).
//
// Nhiệm vụ: tạo bảng nếu chưa có (users, tokens, friendships,
// conversations, messages, posts, comments, rooms...), seed 2 tài khoản
// demo, và các helper dùng chung: publicUser, getUser, ensureConversation,
// addFriendship. Mọi route/socket đều đọc ghi qua file này.

import fs from 'node:fs';
import path from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import { serverRoot } from './config.js';
import { hashPassword, randomId } from './security.js';

// Database nằm trong server/data (không commit lên Git).
// WAL cho phép đọc/ghi song song tốt hơn và không chặn khi server đang chạy.
const dataDir = path.join(serverRoot, 'data');
fs.mkdirSync(dataDir, { recursive: true });

// Kết nối tới file SQLite trong backend/data; mở đồng bộ cho đơn giản.
const db = new DatabaseSync(path.join(dataDir, 'soulmate.db'));

db.exec('PRAGMA journal_mode = WAL;');
// Bật khóa ngoại để xóa user/bài/phòng sẽ dọn luôn dữ liệu liên quan.
db.exec('PRAGMA foreign_keys = ON;');

// Schema chia thành 4 nhóm bảng, kèm index tối ưu truy vấn theo thời gian:
// 1. users + refresh_tokens: tài khoản, mật khẩu hash và phiên đăng nhập.
// 2. friendships + conversations + messages: bạn bè và chat 1-1.
// 3. posts + post_likes + comments: bảng tin, like và bình luận.
// 4. rooms + room_messages: phòng nhóm và tin nhắn phòng.
db.exec(`
CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL COLLATE NOCASE UNIQUE,
  password_hash TEXT NOT NULL,
  name TEXT NOT NULL,
  avatar TEXT NOT NULL DEFAULT '🙂',
  gender TEXT NOT NULL DEFAULT 'other',
  age INTEGER NOT NULL DEFAULT 18,
  bio TEXT NOT NULL DEFAULT '',
  tags TEXT NOT NULL DEFAULT '[]',
  photos TEXT NOT NULL DEFAULT '[]',
  coins INTEGER NOT NULL DEFAULT 100,
  diamonds INTEGER NOT NULL DEFAULT 10,
  is_vip INTEGER NOT NULL DEFAULT 0,
  profile_completed INTEGER NOT NULL DEFAULT 0,
  failed_attempts INTEGER NOT NULL DEFAULT 0,
  locked_until INTEGER,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE TABLE IF NOT EXISTS refresh_tokens (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL UNIQUE,
  family_id TEXT NOT NULL,
  expires_at INTEGER NOT NULL,
  revoked INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE INDEX IF NOT EXISTS idx_refresh_user ON refresh_tokens(user_id);

CREATE TABLE IF NOT EXISTS friendships (
  user_a TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  user_b TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  PRIMARY KEY (user_a, user_b)
);

CREATE TABLE IF NOT EXISTS conversations (
  id TEXT PRIMARY KEY,
  user_a TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  user_b TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  last_message TEXT NOT NULL DEFAULT '',
  last_message_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  UNIQUE (user_a, user_b)
);

CREATE TABLE IF NOT EXISTS messages (
  id TEXT PRIMARY KEY,
  conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  sender_id TEXT NOT NULL REFERENCES users(id),
  content TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'text',
  is_read INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE INDEX IF NOT EXISTS idx_messages_conv ON messages(conversation_id, created_at);

CREATE TABLE IF NOT EXISTS posts (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  content TEXT NOT NULL DEFAULT '',
  media TEXT NOT NULL DEFAULT '[]',
  shares_count INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE INDEX IF NOT EXISTS idx_posts_created ON posts(created_at);

CREATE TABLE IF NOT EXISTS post_likes (
  post_id TEXT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  PRIMARY KEY (post_id, user_id)
);

CREATE TABLE IF NOT EXISTS comments (
  id TEXT PRIMARY KEY,
  post_id TEXT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE INDEX IF NOT EXISTS idx_comments_post ON comments(post_id, created_at);

CREATE TABLE IF NOT EXISTS rooms (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  host_id TEXT NOT NULL REFERENCES users(id),
  topic TEXT NOT NULL DEFAULT '',
  background_emoji TEXT DEFAULT '🎉',
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE TABLE IF NOT EXISTS room_messages (
  id TEXT PRIMARY KEY,
  room_id TEXT NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  sender_id TEXT NOT NULL REFERENCES users(id),
  content TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE INDEX IF NOT EXISTS idx_room_messages ON room_messages(room_id, created_at);
`);

// ===== Tạo tài khoản demo (chỉ chạy khi DB trống) =====
// Chỉ tạo tài khoản đăng nhập thử. Mọi nội dung do người dùng tạo (bài viết,
// bình luận, phòng, tin nhắn) KHÔNG được tạo sẵn: app chỉ hiển thị dữ liệu có
// thật trong database, không có nội dung mẫu.
function seed() {
  const { n } = db.prepare('SELECT COUNT(*) AS n FROM users').get();
  if (n > 0) return;

  // Hai tài khoản demo dùng chung mật khẩu, đủ để thử chat/gọi/Soul Game.
  const demoPwd = hashPassword('Demo@1234');
  const users = [
    {
      id: 'u_demo1', email: 'demo1@soulmate.app', name: 'Minh Anh',
      avatar: '🐱', gender: 'female', age: 21,
      bio: 'Thích nghe nhạc và đi café ☕', tags: JSON.stringify(['Âm nhạc', 'Du lịch']),
      photos: JSON.stringify(['🌄', '☕']), is_vip: 1, coins: 2500, diamonds: 120,
    },
    {
      id: 'u_demo2', email: 'demo2@soulmate.app', name: 'Tuấn',
      avatar: '🐻', gender: 'male', age: 23,
      bio: 'Nhiếp ảnh gia nghiệp dư 📸', tags: JSON.stringify(['Nhiếp ảnh', 'Du lịch']),
      photos: JSON.stringify(['🏔️', '🌅']), is_vip: 0, coins: 300, diamonds: 5,
    },
  ];
  const insertUser = db.prepare(`
    INSERT INTO users (id, email, password_hash, name, avatar, gender, age, bio, tags, photos, coins, diamonds, is_vip, profile_completed)
    VALUES (@id, @email, @pwd, @name, @avatar, @gender, @age, @bio, @tags, @photos, @coins, @diamonds, @is_vip, 1)
  `);
  for (const u of users) insertUser.run({ ...u, pwd: demoPwd });
  console.log('[db] Đã tạo tài khoản demo: demo1@soulmate.app / demo2@soulmate.app (mật khẩu Demo@1234)');
  console.log('[db] Không tạo sẵn bài viết/bình luận/phòng — nội dung chỉ đến từ người dùng thật.');
}

seed();

// Chỉ trả các trường an toàn cho client; không bao giờ lộ password_hash,
// failed_attempts hay locked_until.
export function publicUser(u) {
  if (!u) return null;
  return {
    id: u.id,
    email: u.email,
    name: u.name,
    avatar: u.avatar,
    gender: u.gender,
    age: u.age,
    bio: u.bio,
    tags: JSON.parse(u.tags || '[]'),
    photos: JSON.parse(u.photos || '[]'),
    coins: u.coins,
    diamonds: u.diamonds,
    isVip: !!u.is_vip,
    profileCompleted: !!u.profile_completed,
    createdAt: u.created_at,
  };
}

// Helper tra cứu user; dùng nội bộ server nên trả đầy đủ cột.
export function getUser(id) {
  return db.prepare('SELECT * FROM users WHERE id = ?').get(id);
}

// Tra user theo email, phục vụ đăng nhập/đăng ký.
export function getUserByEmail(email) {
  return db.prepare('SELECT * FROM users WHERE email = ?').get(email);
}

/** Tạo (hoặc lấy) hội thoại giữa 2 user — thứ tự cặp được sắp để tránh trùng.
 *  Nhờ sắp xếp user_a < user_b, cặp (A,B) và (B,A) luôn trỏ về cùng một row. */
export function ensureConversation(userA, userB) {
  const [a, b] = [userA, userB].sort();
  let row = db.prepare('SELECT * FROM conversations WHERE user_a = ? AND user_b = ?').get(a, b);
  if (!row) {
    const id = randomId('c');
    db.prepare('INSERT INTO conversations (id, user_a, user_b) VALUES (?, ?, ?)').run(id, a, b);
    row = db.prepare('SELECT * FROM conversations WHERE id = ?').get(id);
  }
  return row;
}

/** Thêm bạn (idempotent) */
export function addFriendship(userA, userB) {
  const [a, b] = [userA, userB].sort();
  db.prepare('INSERT OR IGNORE INTO friendships (user_a, user_b) VALUES (?, ?)').run(a, b);
}

export default db;
