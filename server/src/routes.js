import express from 'express';
import fs from 'node:fs';
import path from 'node:path';
import db, { publicUser, getUser, ensureConversation } from './db.js';
import { randomId, hashPassword, verifyPassword } from './security.js';
import { serverRoot } from './config.js';
import { validPassword, issueTokenPair } from './auth.js';
import { isOnline, roomPresenceList } from './socket.js';
import { APP_CATALOG } from './catalog.js';

/**
 * REST API của SoulMate.
 * Router này được gắn sau authMiddleware trong index.js nên mọi endpoint
 * đều yêu cầu Bearer access token. File chia theo nhóm nghiệp vụ:
 * catalog/upload, hồ sơ và bạn bè, hội thoại, feed/bình luận, phòng tiệc.
 */
const router = express.Router();

// ====================== CATALOG ======================
// Cache catalog như dữ liệu công khai, không gắn vào session riêng của một tài khoản.
function sendCatalog(res, data) {
  res.set('Cache-Control', 'public, max-age=300');
  res.json(data);
}

// Trả catalog cho client để nội dung và bảng giá chỉ được định nghĩa một lần ở backend.
router.get('/catalog', (req, res) => sendCatalog(res, APP_CATALOG));

// Chỉ trả danh mục quà phòng, không cần client phụ thuộc vào các giá trị hard-code.
router.get('/rooms/catalog', (req, res) =>
  sendCatalog(res, { gifts: APP_CATALOG.rooms.gifts }));

// Nội dung gói Xu là thông tin hiển thị; backend không bật mua khi chưa xác minh thanh toán.
router.get('/wallet/catalog', (req, res) => sendCatalog(res, APP_CATALOG.wallet));

// Gói VIP và trạng thái bật mua cũng đến từ server, không cho app tự suy diễn giá.
router.get('/vip/catalog', (req, res) => sendCatalog(res, APP_CATALOG.vip));

// Danh sách avatar/sở thích hợp lệ để UI hiển thị và backend kiểm tra khi lưu hồ sơ.
router.get('/profile/options', (req, res) => sendCatalog(res, APP_CATALOG.profile));

// Kiểm tra dữ liệu hồ sơ theo catalog của server; không tin danh sách
// avatar/sở thích/ảnh do client tự gửi lên.
function validateProfileOptions(req, res, next) {
  const { avatar, tags, age, gender, photos } = req.body || {};
  const avatarText = avatar === undefined ? null : String(avatar);
  // Avatar ảnh chỉ cho phép đường dẫn do endpoint upload của chính server trả về.
  const uploadedAvatar = avatarText != null && /^\/uploads\/[A-Za-z0-9._-]+$/.test(avatarText);
  if (avatarText !== null && !APP_CATALOG.profile.avatars.includes(avatarText) && !uploadedAvatar) {
    return res.status(400).json({ error: 'invalid_avatar', message: 'Avatar không hợp lệ' });
  }
  if (tags !== undefined && (!Array.isArray(tags) || tags.length > 20 ||
      tags.some((tag) => !APP_CATALOG.profile.interests.includes(String(tag))))) {
    return res.status(400).json({ error: 'invalid_interests', message: 'Sở thích không hợp lệ' });
  }
  if (age !== undefined && (!Number.isInteger(Number(age)) || Number(age) < 16 || Number(age) > 80)) {
    return res.status(400).json({ error: 'invalid_age', message: 'Tuổi cần trong khoảng 16-80' });
  }
  if (gender !== undefined && !GENDERS.includes(gender)) {
    return res.status(400).json({ error: 'invalid_gender', message: 'Giới tính không hợp lệ' });
  }
  if (photos !== undefined && (!Array.isArray(photos) || photos.length > 9 ||
      photos.some((photo) => typeof photo !== 'string' ||
        !/^\/uploads\/[A-Za-z0-9._-]+$/.test(photo)))) {
    return res.status(400).json({ error: 'invalid_photos', message: 'Danh sách ảnh không hợp lệ' });
  }
  next();
}


// ===== Upload ảnh (avatar / bài post / tin nhắn) =====
const uploadsDir = path.join(serverRoot, 'uploads');
fs.mkdirSync(uploadsDir, { recursive: true });


const parseJson = (s, fallback) => {
  try { return JSON.parse(s); } catch { return fallback; }
};
const GENDERS = ['male', 'female', 'other'];

// POST /api/upload { dataUrl: 'data:image/jpeg;base64,...' } -> { url }
router.post('/upload', (req, res) => {
  const m = /^data:image\/(jpeg|jpg|png|webp);base64,([A-Za-z0-9+/=]+)$/
    .exec(String(req.body?.dataUrl || ''));
  if (!m) {
    return res.status(400).json({ error: 'invalid_image',
      message: 'Ảnh không hợp lệ (chỉ jpeg/png/webp)' });
  }
  const buf = Buffer.from(m[2], 'base64');
  if (buf.length === 0 || buf.length > 5 * 1024 * 1024) {
    return res.status(413).json({ error: 'image_too_large',
      message: 'Ảnh tối đa 5MB' });
  }
  const ext = m[1] === 'jpg' ? 'jpg' : m[1];
  const name = `${randomId('img')}.${ext}`;
  fs.writeFileSync(path.join(uploadsDir, name), buf);
  res.status(201).json({ url: `/uploads/${name}` });
});


// ====================== HỒ SƠ / BẠN BÈ ======================
// Các route dưới đây chỉ thao tác trên dữ liệu của chính người đang đăng nhập,
// trừ hồ sơ công khai và tìm kiếm người dùng.

router.get('/me', (req, res) => {
  const u = getUser(req.userId);
  if (!u) return res.status(404).json({ error: 'not_found' });
  res.json({ user: publicUser(u) });
});

// Cập nhật hồ sơ: validateProfileOptions kiểm tra avatar/sở thích/tuổi/giới tính/ảnh
// trước khi ghi, sau đó chuẩn hoá lại lần nữa để tránh dữ liệu vượt giới hạn.
router.patch('/me', validateProfileOptions, (req, res) => {
  const u = getUser(req.userId);
  if (!u) return res.status(404).json({ error: 'not_found' });
  const b = req.body || {};

  const next = {
    name: b.name !== undefined ? String(b.name).trim() : u.name,
    // Giữ nguyên URL ảnh do server upload; avatar emoji vẫn bị giới hạn độ dài.
    avatar: b.avatar === undefined
      ? u.avatar
      : (/^\/uploads\/[A-Za-z0-9._-]+$/.test(String(b.avatar))
          ? String(b.avatar).slice(0, 500)
          : String(b.avatar).slice(0, 8)),
    age: b.age !== undefined ? Math.max(16, Math.min(80, Number(b.age) || 16)) : u.age,
    gender: b.gender !== undefined && GENDERS.includes(b.gender) ? b.gender : u.gender,
    bio: b.bio !== undefined ? String(b.bio).slice(0, 500) : u.bio,
    tags: b.tags !== undefined && Array.isArray(b.tags)
      ? JSON.stringify(b.tags.slice(0, 20).map(String)) : u.tags,
    photos: b.photos !== undefined && Array.isArray(b.photos)
      ? JSON.stringify(b.photos.slice(0, 9).map(String)) : u.photos,
  };
  if (next.name.length < 2 || next.name.length > 30) {
    return res.status(400).json({ error: 'invalid_name', message: 'Tên cần 2-30 ký tự' });
  }
  const profileCompleted = b.profileCompleted !== undefined
    ? (b.profileCompleted ? 1 : 0) : u.profile_completed;

  db.prepare(`
    UPDATE users SET name = ?, avatar = ?, age = ?, gender = ?, bio = ?, tags = ?, photos = ?, profile_completed = ?
    WHERE id = ?
  `).run(next.name, next.avatar, next.age, next.gender, next.bio, next.tags, next.photos,
        profileCompleted, u.id);

  res.json({ user: publicUser(getUser(u.id)) });
});

// Hồ sơ công khai (dùng khi hiện danh tính trong Soul Game)
router.get('/users/:id', (req, res) => {
  const u = getUser(req.params.id);
  if (!u) return res.status(404).json({ error: 'not_found' });
  const p = publicUser(u);
  res.json({
    user: { ...p, isOnline: isOnline(u.id) },
    isFriend: !!db.prepare(`
      SELECT 1 FROM friendships
      WHERE (user_a = ? AND user_b = ?) OR (user_a = ? AND user_b = ?)
    `).get(req.userId, u.id, u.id, req.userId),
  });
});

// Tìm kiếm người dùng (theo tên hoặc email)
router.get('/users', (req, res) => {
  const q = String(req.query.q || '').trim().slice(0, 50);
  if (!q) return res.json({ users: [] });
  const rows = db.prepare(`
    SELECT * FROM users WHERE id <> ? AND (name LIKE ? OR email LIKE ?)
    ORDER BY name LIMIT 20
  `).all(req.userId, `%${q}%`, `%${q}%`);
  res.json({
    users: rows.map((u) => ({ ...publicUser(u), isOnline: isOnline(u.id) })),
  });
});

// Danh sách bạn bè (từ Soul Game) + hội thoại tương ứng
router.get('/friends', (req, res) => {
  const rows = db.prepare(`
    SELECT u.*, f.created_at AS friends_since FROM friendships f
    JOIN users u ON u.id = CASE WHEN f.user_a = @me THEN f.user_b ELSE f.user_a END
    WHERE f.user_a = @me OR f.user_b = @me
    ORDER BY f.created_at DESC
  `).all({ me: req.userId });
  res.json({
    friends: rows.map((u) => ({
      ...publicUser(u),
      isOnline: isOnline(u.id),
      friendsSince: u.friends_since,
      conversationId: ensureConversation(req.userId, u.id).id,
    })),
  });
});

// Đổi mật khẩu (yêu cầu mật khẩu cũ; thu hồi mọi refresh token cũ)
router.post('/me/password', (req, res) => {
  const { currentPassword, newPassword } = req.body || {};
  if (typeof currentPassword !== 'string' || typeof newPassword !== 'string') {
    return res.status(400).json({ error: 'invalid_request', message: 'Thiếu mật khẩu' });
  }
  if (!validPassword(newPassword)) {
    return res.status(400).json({ error: 'weak_password',
      message: 'Mật khẩu mới cần 8+ ký tự, gồm chữ và số' });
  }
  const u = getUser(req.userId);
  if (!u || !verifyPassword(currentPassword, u.password_hash)) {
    return res.status(400).json({ error: 'wrong_password', message: 'Mật khẩu hiện tại không đúng' });
  }
  db.prepare('UPDATE users SET password_hash = ? WHERE id = ?')
    .run(hashPassword(newPassword), u.id);
  // Thu hồi toàn bộ phiên cũ -> mọi thiết bị phải đăng nhập lại, trừ phiên trả về ngay
  db.prepare('UPDATE refresh_tokens SET revoked = 1 WHERE user_id = ?').run(u.id);
  res.json(issueTokenPair(u.id));
});

// ====================== HỘI THOẠI / TIN NHẮN ======================

// Danh sách hội thoại kèm tin nhắn cuối và trạng thái online của đối phương.
// Subquery đếm riêng tin chưa đọc do đối phương gửi cho người đang đăng nhập.
router.get('/conversations', (req, res) => {
  const rows = db.prepare(`
    SELECT c.id, c.last_message, c.last_message_at,
      CASE WHEN c.user_a = @me THEN c.user_b ELSE c.user_a END AS partner_id,
      u.name AS partner_name, u.avatar AS partner_avatar,
      (SELECT COUNT(*) FROM messages m
        WHERE m.conversation_id = c.id AND m.sender_id <> @me AND m.is_read = 0) AS unread
    FROM conversations c
    JOIN users u ON u.id = CASE WHEN c.user_a = @me THEN c.user_b ELSE c.user_a END
    WHERE c.user_a = @me OR c.user_b = @me
    ORDER BY c.last_message_at DESC
  `).all({ me: req.userId });

  res.json({
    conversations: rows.map((r) => ({
      id: r.id,
      partnerId: r.partner_id,
      partnerName: r.partner_name,
      partnerAvatar: r.partner_avatar,
      lastMessage: r.last_message,
      lastMessageAt: r.last_message_at,
      unreadCount: r.unread,
      isOnline: isOnline(r.partner_id),
    })),
  });
});

// Mở hội thoại 1-1 với một user; nếu đã có thì trả lại id cũ.
router.post('/conversations/ensure', (req, res) => {
  const { partnerId } = req.body || {};
  if (!getUser(partnerId)) return res.status(404).json({ error: 'user_not_found' });
  const conv = ensureConversation(req.userId, partnerId);
  res.json({ conversationId: conv.id });
});

// Chỉ thành viên của hội thoại mới được đọc/ghi; người ngoài nhận 404
// để không lộ sự tồn tại của hội thoại.
function findConversationFor(req, res) {
  const c = db.prepare('SELECT * FROM conversations WHERE id = ?').get(req.params.id);
  if (!c || (c.user_a !== req.userId && c.user_b !== req.userId)) {
    res.status(404).json({ error: 'not_found' });
    return null;
  }
  return c;
}

// Đọc lịch sử theo cursor `before` (mới nhất trước), đồng thời đánh dấu đã đọc.
// `hasMore` báo còn tin cũ hơn để client cuộn tải tiếp.
router.get('/conversations/:id/messages', (req, res) => {
  const c = findConversationFor(req, res);
  if (!c) return;
  db.prepare('UPDATE messages SET is_read = 1 WHERE conversation_id = ? AND sender_id <> ?')
    .run(c.id, req.userId);
  const limit = Math.min(Number(req.query.limit) || 50, 100);
  const before = String(req.query.before || '');
  const rows = before
    ? db.prepare(`
        SELECT * FROM messages WHERE conversation_id = ? AND created_at < ?
        ORDER BY created_at DESC, rowid DESC LIMIT ?
      `).all(c.id, before, limit)
    : db.prepare(`
        SELECT * FROM messages WHERE conversation_id = ?
        ORDER BY created_at DESC, rowid DESC LIMIT ?
      `).all(c.id, limit);
  res.json({
    hasMore: rows.length === limit,
    messages: rows.reverse().map((m) => ({
      id: m.id, conversationId: m.conversation_id, senderId: m.sender_id,
      content: m.content, type: m.type, createdAt: m.created_at, isRead: !!m.is_read,
    })),
  });
});

// Gửi tin nhắn: chỉ thành viên hội thoại, ảnh phải là URL do /api/upload trả về.
// Tin được phát realtime cho cả người nhận và người gửi để thay tin optimistic.
router.post('/conversations/:id/messages', (req, res) => {
  const c = findConversationFor(req, res);
  if (!c) return;
  const content = String(req.body?.content || '').trim();
  if (!content || content.length > 2000) {
    return res.status(400).json({ error: 'invalid_content', message: 'Tin nhắn không hợp lệ' });
  }
  // Ảnh: chỉ chấp nhận URL đã upload qua /api/upload (chống chèn payload lạ)
  const type = req.body?.type === 'image' && content.startsWith('/uploads/')
    ? 'image' : 'text';
  const clientMessageId = typeof req.body?.clientMessageId === 'string'
    ? req.body.clientMessageId.slice(0, 64) : null;
  const id = randomId('m');
  const createdAt = new Date().toISOString();
  db.prepare(`
    INSERT INTO messages (id, conversation_id, sender_id, content, type, created_at)
    VALUES (?, ?, ?, ?, ?, ?)
  `).run(id, c.id, req.userId, content, type, createdAt);
  db.prepare('UPDATE conversations SET last_message = ?, last_message_at = ? WHERE id = ?')
    .run(content, createdAt, c.id);

  const partnerId = c.user_a === req.userId ? c.user_b : c.user_a;
  const message = {
    id, conversationId: c.id, senderId: req.userId,
    content, type, createdAt, isRead: false,
  };
  // Gửi realtime cho người nhận VÀ người gửi (người gửi dùng
  // clientMessageId để thay thế tin optimistic local)
  const payload = { conversationId: c.id, message, clientMessageId };
  emitToUserSafe(partnerId, 'chat:message', payload);
  emitToUserSafe(req.userId, 'chat:message', payload);

  res.status(201).json({ message });
});

// Sửa tin nhắn của chính mình
router.patch('/conversations/:id/messages/:mid', (req, res) => {
  const c = findConversationFor(req, res);
  if (!c) return;
  const m = db.prepare('SELECT * FROM messages WHERE id = ? AND conversation_id = ?')
    .get(req.params.mid, c.id);
  if (!m) return res.status(404).json({ error: 'not_found' });
  if (m.sender_id !== req.userId) {
    return res.status(403).json({ error: 'forbidden', message: 'Chỉ sửa được tin của mình' });
  }
  const content = String(req.body?.content || '').trim();
  if (!content || content.length > 2000) {
    return res.status(400).json({ error: 'invalid_content', message: 'Tin nhắn không hợp lệ' });
  }
  db.prepare('UPDATE messages SET content = ? WHERE id = ?').run(content, m.id);
  const partnerId = c.user_a === req.userId ? c.user_b : c.user_a;
  emitToUserSafe(partnerId, 'chat:message-edited', {
    conversationId: c.id, messageId: m.id, content,
  });
  res.json({
    message: {
      id: m.id, conversationId: c.id, senderId: m.sender_id,
      content, type: m.type, createdAt: m.created_at, isRead: !!m.is_read,
    },
  });
});

// Xóa tin nhắn của chính mình
router.delete('/conversations/:id/messages/:mid', (req, res) => {
  const c = findConversationFor(req, res);
  if (!c) return;
  const m = db.prepare('SELECT * FROM messages WHERE id = ? AND conversation_id = ?')
    .get(req.params.mid, c.id);
  if (!m) return res.status(404).json({ error: 'not_found' });
  if (m.sender_id !== req.userId) {
    return res.status(403).json({ error: 'forbidden', message: 'Chỉ xóa được tin của mình' });
  }
  db.prepare('DELETE FROM messages WHERE id = ?').run(m.id);
  const partnerId = c.user_a === req.userId ? c.user_b : c.user_a;
  emitToUserSafe(partnerId, 'chat:message-deleted', {
    conversationId: c.id, messageId: m.id,
  });
  res.json({ id: m.id });
});

// ====================== FEED ======================

// Gộp dữ liệu bài viết với số like/comment và trạng thái like của người xem.
// Bài repost lưu snapshot bài gốc dưới dạng JSON trong cột media.
function postWithStats(postId, me) {
  const p = db.prepare(`
    SELECT p.*, u.name AS user_name, u.avatar AS user_avatar,
      (SELECT COUNT(*) FROM post_likes l WHERE l.post_id = p.id) AS likes,
      (SELECT COUNT(*) FROM comments c WHERE c.post_id = p.id) AS comments,
      (SELECT EXISTS(SELECT 1 FROM post_likes l WHERE l.post_id = p.id AND l.user_id = @me)) AS liked_by_me
    FROM posts p JOIN users u ON u.id = p.user_id
    WHERE p.id = @id
  `).get({ id: postId, me });
  if (!p) return null;
  const content = p.content;
  const storedMedia = parseJson(p.media, []);
  let media = storedMedia;
  let originalPost = null;
  if (storedMedia.length === 1 && typeof storedMedia[0] === 'string') {
    try {
      const quote = JSON.parse(storedMedia[0]);
      if (quote && typeof quote.postId === 'string') {
        originalPost = quote;
        media = [];
      }
    } catch {
      // Ảnh cũ có thể là text/URL không phải JSON repost.
    }
  }
  return {
    id: p.id,
    userId: p.user_id,
    userName: p.user_name,
    userAvatar: p.user_avatar,
    content,
    media,
    originalPost,
    createdAt: p.created_at,
    likes: p.likes,
    comments: p.comments,
    shares: p.shares_count,
    likedByMe: !!p.liked_by_me,
  };
}

// Tải feed theo cursor `before` hoặc offset cho lần tải đầu.
// Cursor tránh bỏ sót bài khi bài mới realtime được chèn lên đầu danh sách.
router.get('/feed', (req, res) => {
  const limit = Math.min(Number(req.query.limit) || 30, 60);
  const before = String(req.query.before || '');
  const offset = Number(req.query.offset) || 0;
  // before = cursor theo created_at: bài mới realtime được thêm vào đầu danh sách
  // làm offset nhảy số (bỏ sót bài cũ); dùng cursor thì không bị.
  const ids = before
    ? db.prepare(`SELECT id FROM posts WHERE created_at <= ?
        ORDER BY created_at DESC, rowid DESC LIMIT ?`)
        .all(before, limit)
    : db.prepare('SELECT id FROM posts ORDER BY created_at DESC, rowid DESC LIMIT ? OFFSET ?')
        .all(limit, offset);
  res.json({ posts: ids.map((r) => postWithStats(r.id, req.userId)).filter(Boolean) });
});

// Đăng bài mới: cần nội dung hoặc ít nhất một media, tối đa 9 media.
router.post('/feed', (req, res) => {
  const content = String(req.body?.content || '').trim();
  const media = Array.isArray(req.body?.media) ? req.body.media.slice(0, 9).map(String) : [];
  if (!content && media.length === 0) {
    return res.status(400).json({ error: 'empty_post', message: 'Bài viết trống' });
  }
  if (content.length > 1000) {
    return res.status(400).json({ error: 'too_long', message: 'Nội dung tối đa 1000 ký tự' });
  }
  const id = randomId('p');
  db.prepare('INSERT INTO posts (id, user_id, content, media) VALUES (?, ?, ?, ?)')
    .run(id, req.userId, content, JSON.stringify(media));
  const post = postWithStats(id, req.userId);
  // Realtime: mọi thiết bị đang mở feed thấy bài mới ngay lập tức
  emitFeedSafe('feed:new', { post });
  res.status(201).json({ post });
});

// Sửa bài viết (chủ bài)
router.patch('/feed/:id', (req, res) => {
  const p = db.prepare('SELECT * FROM posts WHERE id = ?').get(req.params.id);
  if (!p) return res.status(404).json({ error: 'not_found' });
  if (p.user_id !== req.userId) {
    return res.status(403).json({ error: 'forbidden', message: 'Chỉ sửa được bài của mình' });
  }
  const b = req.body || {};
  const content = b.content !== undefined ? String(b.content).trim() : p.content;
  const media = b.media !== undefined && Array.isArray(b.media)
    ? JSON.stringify(b.media.slice(0, 9).map(String)) : p.media;
  if ((!content || content.length > 1000) && parseJson(media, []).length === 0) {
    return res.status(400).json({ error: 'empty_post', message: 'Bài viết trống' });
  }
  db.prepare('UPDATE posts SET content = ?, media = ? WHERE id = ?')
    .run(content, media, p.id);
  const post = postWithStats(p.id, req.userId);
  emitFeedSafe('feed:updated', { post });
  res.json({ post });
});

// Xóa bài viết (chủ bài)
router.delete('/feed/:id', (req, res) => {
  const p = db.prepare('SELECT * FROM posts WHERE id = ?').get(req.params.id);
  if (!p) return res.status(404).json({ error: 'not_found' });
  if (p.user_id !== req.userId) {
    return res.status(403).json({ error: 'forbidden', message: 'Chỉ xóa được bài của mình' });
  }
  db.prepare('DELETE FROM posts WHERE id = ?').run(p.id);
  emitFeedSafe('feed:deleted', { postId: p.id });
  res.json({ id: p.id });
});

// Like/unlike là toggle theo cặp (post_id, user_id) nên bấm lại sẽ bỏ like.
// likedByMe chỉ trả cho người gọi; socket chỉ phát số like cho người khác.
router.post('/feed/:id/like', (req, res) => {
  const post = db.prepare('SELECT id FROM posts WHERE id = ?').get(req.params.id);
  if (!post) return res.status(404).json({ error: 'not_found' });
  const exists = db.prepare('SELECT 1 FROM post_likes WHERE post_id = ? AND user_id = ?')
    .get(post.id, req.userId);
  if (exists) db.prepare('DELETE FROM post_likes WHERE post_id = ? AND user_id = ?')
    .run(post.id, req.userId);
  else db.prepare('INSERT OR IGNORE INTO post_likes (post_id, user_id) VALUES (?, ?)')
    .run(post.id, req.userId);
  const p = postWithStats(post.id, req.userId);
  // likedByMe là trạng thái riêng từng người (chỉ người bấm tự đổi) —
  // broadcast chỉ gửi số like để các thiết bị khác đồng bộ.
  emitFeedSafe('feed:stats', { postId: post.id, likes: p.likes });
  res.json({ likes: p.likes, likedByMe: p.likedByMe });
});

// Repost tạo post mới; share ngoài chỉ tăng counter sau xác nhận từ native share sheet.
router.post('/feed/:id/share', (req, res) => {
  const original = postWithStats(req.params.id, req.userId);
  if (!original) return res.status(404).json({ error: 'not_found' });

  const repostContent = String(req.body?.repostContent || '').trim().slice(0, 280);
  let repost = null;
  if (req.body?.repostContent !== undefined) {
    // Tạo bài mới cho người chia sẻ, giữ thông tin bài gốc để app render dạng repost.
    const id = randomId('p');
    const createdAt = new Date().toISOString();
    const caption = repostContent || '';
    const quote = JSON.stringify({
      postId: original.id,
      userId: original.userId,
      userName: original.userName,
      userAvatar: original.userAvatar,
      content: original.content,
      media: original.media,
    });
    db.prepare(`INSERT INTO posts (id, user_id, content, media, created_at)
      VALUES (?, ?, ?, ?, ?)`).run(id, req.userId, caption, JSON.stringify([quote]), createdAt);
    repost = postWithStats(id, req.userId);
    emitFeedSafe('feed:new', { post: repost });
  }

  // Repost tăng bộ đếm tại server; share ngoài chỉ được ghi khi app đã mở
  // thành công bảng chia sẻ của hệ điều hành và gọi lại endpoint với confirmed=true.
  if (req.body?.confirmed === true || repost != null) {
    db.prepare('UPDATE posts SET shares_count = shares_count + 1 WHERE id = ?')
      .run(original.id);
  }
  const shares = postWithStats(original.id, req.userId).shares;
  if (req.body?.confirmed === true || repost != null) {
    emitFeedSafe('feed:stats', { postId: original.id, shares });
  }
  res.json({ shares, repost });
});

// ====================== BÌNH LUẬN ======================

// Đọc lại một bình luận kèm tên/avatar để trả REST và phát socket cùng schema.
function commentWithAuthor(commentId, postId) {
  const row = db.prepare(`
    SELECT c.id, c.post_id, c.user_id, c.content, c.created_at,
      u.name AS user_name, u.avatar AS user_avatar
    FROM comments c JOIN users u ON u.id = c.user_id
    WHERE c.id = ? AND c.post_id = ?
  `).get(commentId, postId);
  if (!row) return null;
  return {
    id: row.id,
    postId: row.post_id,
    userId: row.user_id,
    userName: row.user_name,
    userAvatar: row.user_avatar,
    content: row.content,
    createdAt: row.created_at,
  };
}

function emitCommentSafe(event, payload) {
  try { getIO()?.emit(event, payload); } catch { /* socket chưa khởi tạo */ }
}

// Trả toàn bộ bình luận của bài theo thứ tự thời gian tăng dần.
router.get('/feed/:id/comments', (req, res) => {
  const rows = db.prepare(`
    SELECT c.id, c.content, c.created_at, u.id AS user_id, u.name, u.avatar
    FROM comments c JOIN users u ON u.id = c.user_id
    WHERE c.post_id = ? ORDER BY c.created_at ASC, c.rowid ASC
  `).all(req.params.id);
  res.json({
    comments: rows.map((r) => ({
      id: r.id, postId: req.params.id, userId: r.user_id,
      userName: r.name, userAvatar: r.avatar,
      content: r.content, createdAt: r.created_at,
    })),
  });
});

// Persist bình luận rồi broadcast trọn nội dung để người đang mở sheet thấy ngay.
router.post('/feed/:id/comments', (req, res) => {
  const post = db.prepare('SELECT id FROM posts WHERE id = ?').get(req.params.id);
  if (!post) return res.status(404).json({ error: 'not_found' });
  const content = String(req.body?.content || '').trim();
  if (!content || content.length > 500) {
    return res.status(400).json({ error: 'invalid_content', message: 'Bình luận không hợp lệ' });
  }
  const id = randomId('cm');
  const createdAt = new Date().toISOString();
  db.prepare('INSERT INTO comments (id, post_id, user_id, content, created_at) VALUES (?, ?, ?, ?, ?)')
    .run(id, post.id, req.userId, content, createdAt);
  const p = postWithStats(post.id, req.userId);
  const comment = commentWithAuthor(id, post.id);
  emitFeedSafe('feed:stats', { postId: post.id, comments: p.comments });
  emitCommentSafe('feed:comment:new', { comment });
  res.status(201).json({ comment });
});

// Sửa bình luận (chủ bình luận)
router.patch('/feed/:id/comments/:cid', (req, res) => {
  const c = db.prepare('SELECT * FROM comments WHERE id = ? AND post_id = ?')
    .get(req.params.cid, req.params.id);
  if (!c) return res.status(404).json({ error: 'not_found' });
  if (c.user_id !== req.userId) {
    return res.status(403).json({ error: 'forbidden', message: 'Chỉ sửa được bình luận của mình' });
  }
  const content = String(req.body?.content || '').trim();
  if (!content || content.length > 500) {
    return res.status(400).json({ error: 'invalid_content', message: 'Bình luận không hợp lệ' });
  }
  db.prepare('UPDATE comments SET content = ? WHERE id = ?').run(content, c.id);
  const updated = commentWithAuthor(c.id, c.post_id);
  emitCommentSafe('feed:comment:updated', { comment: updated });
  res.json({ comment: updated });
});

// Xóa bình luận (chủ bình luận hoặc chủ bài)
router.delete('/feed/:id/comments/:cid', (req, res) => {
  const c = db.prepare('SELECT * FROM comments WHERE id = ? AND post_id = ?')
    .get(req.params.cid, req.params.id);
  if (!c) return res.status(404).json({ error: 'not_found' });
  const post = db.prepare('SELECT user_id FROM posts WHERE id = ?').get(req.params.id);
  if (c.user_id !== req.userId && post?.user_id !== req.userId) {
    return res.status(403).json({ error: 'forbidden', message: 'Không có quyền xóa' });
  }
  db.prepare('DELETE FROM comments WHERE id = ?').run(c.id);
  emitCommentSafe('feed:comment:deleted', { postId: c.post_id, commentId: c.id });
  const count = db.prepare('SELECT COUNT(*) AS count FROM comments WHERE post_id = ?')
    .get(c.post_id).count;
  emitFeedSafe('feed:stats', { postId: c.post_id, comments: count });
  res.json({ id: c.id, comments: count });
});

// ====================== PHÒNG TIỆC ======================

// Danh sách phòng kèm số thành viên đang online (lấy từ bộ nhớ socket).
router.get('/rooms', (req, res) => {
  const rows = db.prepare(`
    SELECT r.*, u.name AS host_name, u.avatar AS host_avatar
    FROM rooms r JOIN users u ON u.id = r.host_id ORDER BY r.rowid
  `).all();
  res.json({
    rooms: rows.map((r) => {
      const members = roomPresenceList(r.id);
      return {
        id: r.id,
        name: r.name,
        hostName: r.host_name,
        hostAvatar: r.host_avatar,
        memberCount: members.length,
        memberAvatars: members.map((m) => m.avatar),
        backgroundEmoji: r.background_emoji,
        topic: r.topic,
      };
    }),
  });
});

// Tạo phòng mới; người tạo trở thành host. Tên 2-40 ký tự, chủ đề tối đa 80.
router.post('/rooms', (req, res) => {
  const b = req.body || {};
  const name = String(b.name || '').trim();
  const topic = String(b.topic || '').trim().slice(0, 80);
  const emoji = String(b.backgroundEmoji || '🎉').slice(0, 8);
  if (name.length < 2 || name.length > 40) {
    return res.status(400).json({ error: 'invalid_name', message: 'Tên phòng 2-40 ký tự' });
  }
  const u = getUser(req.userId);
  const id = randomId('r');
  db.prepare('INSERT INTO rooms (id, name, host_id, topic, background_emoji) VALUES (?, ?, ?, ?, ?)')
    .run(id, name, u.id, topic, emoji);
  res.status(201).json({
    room: {
      id, name, hostName: u.name, hostAvatar: u.avatar,
      memberCount: 0, memberAvatars: [], backgroundEmoji: emoji, topic,
    },
  });
});

// Lấy 100 tin gần nhất của phòng rồi đảo lại để client hiển thị từ cũ đến mới.
router.get('/rooms/:id/messages', (req, res) => {
  const room = db.prepare('SELECT id FROM rooms WHERE id = ?').get(req.params.id);
  if (!room) return res.status(404).json({ error: 'not_found' });
  const rows = db.prepare(`
    SELECT rm.*, u.name AS sender_name, u.avatar AS sender_avatar
    FROM room_messages rm JOIN users u ON u.id = rm.sender_id
    WHERE rm.room_id = ? ORDER BY rm.created_at DESC, rm.rowid DESC LIMIT 100
  `).all(room.id).reverse();
  res.json({
    messages: rows.map((m) => ({
      id: m.id, roomId: m.room_id, senderId: m.sender_id,
      senderName: m.sender_name, senderAvatar: m.sender_avatar,
      content: m.content, createdAt: m.created_at,
    })),
  });
});

// Gửi tin vào phòng qua REST (dự phòng khi socket chưa nối) và phát realtime cho phòng.
router.post('/rooms/:id/messages', (req, res) => {
  const room = db.prepare('SELECT id FROM rooms WHERE id = ?').get(req.params.id);
  if (!room) return res.status(404).json({ error: 'not_found' });
  const content = String(req.body?.content || '').trim();
  if (!content || content.length > 2000) {
    return res.status(400).json({ error: 'invalid_content', message: 'Tin nhắn không hợp lệ' });
  }
  const u = getUser(req.userId);
  const id = randomId('rm');
  const createdAt = new Date().toISOString();
  db.prepare('INSERT INTO room_messages (id, room_id, sender_id, content, created_at) VALUES (?, ?, ?, ?, ?)')
    .run(id, room.id, u.id, content, createdAt);
  const message = {
    id, roomId: room.id, senderId: u.id, senderName: u.name,
    senderAvatar: u.avatar, content, createdAt,
  };
  emitToRoomSafe(room.id, 'room:message', { roomId: room.id, message });
  res.status(201).json({ message });
});

// Tránh vòng import: socket.js không import routes.js, nên import trễ ở đây an toàn
import { emitToUser as _emitToUser, getIO } from './socket.js';
function emitToUserSafe(userId, event, payload) {
  try { _emitToUser(userId, event, payload); } catch { /* socket chưa khởi tạo */ }
}
function emitToRoomSafe(roomId, event, payload) {
  try { getIO()?.to(`room:${roomId}`).emit(event, payload); } catch { /* ignore */ }
}
function emitFeedSafe(event, payload) {
  try { getIO()?.emit(event, payload); } catch { /* socket chưa khởi tạo */ }
}

export default router;
