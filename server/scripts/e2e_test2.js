// Smoke test vòng 2: node scripts/e2e_test2.js (server đang chạy)
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';
import { io } from 'socket.io-client';

const BASE = 'https://localhost:3000';
let passed = 0, failed = 0;
const ok = (cond, name) => {
  if (cond) { passed++; console.log('  ✓', name); }
  else { failed++; console.log('  ✗', name); }
};
const wait = (ms) => new Promise((r) => setTimeout(r, ms));
const waitEvent = (s, e, t = 4000) => new Promise((resolve, reject) => {
  const to = setTimeout(() => reject(new Error(`timeout ${e}`)), t);
  s.once(e, (d) => { clearTimeout(to); resolve(d); });
});

async function call(method, path, { token, body } = {}) {
  const res = await fetch(BASE + path, {
    method,
    headers: {
      'content-type': 'application/json',
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  let data = null;
  try { data = await res.json(); } catch { /* empty */ }
  return { status: res.status, data };
}

async function register(name) {
  const email = `${name.toLowerCase()}_${Date.now()}@test.app`;
  const r = await call('POST', '/api/auth/register', {
    body: { email, password: 'MatKhau123', name },
  });
  return { email, access: r.data.accessToken, refresh: r.data.refreshToken, user: r.data.user };
}

// 1KB ảnh PNG hợp lệ (1x1 pixel)
const TINY_PNG =
  'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

async function main() {
  const A = await register('Alice');
  const B = await register('Bob');
  ok(!!A.access && !!B.access, 'đăng ký 2 tài khoản test');

  console.log('== Upload ảnh ==');
  const up = await call('POST', '/api/upload', { token: A.access, body: { dataUrl: TINY_PNG } });
  ok(up.status === 201 && up.data.url?.startsWith('/uploads/'), 'upload ảnh -> url');
  const imgUrl = up.data.url;
  const raw = await fetch(BASE + imgUrl);
  ok(raw.status === 200 && raw.headers.get('content-type')?.includes('image'), 'GET ảnh tĩnh hoạt động');
  const badUp = await call('POST', '/api/upload', { token: A.access, body: { dataUrl: 'data:text/plain;base64,aGk=' } });
  ok(badUp.status === 400, 'từ chối file không phải ảnh');

  console.log('== Tìm kiếm + trang cá nhân ==');
  const search = await call('GET', `/api/users?q=${B.user.name}`, { token: A.access });
  ok(search.status === 200 && search.data.users.some((u) => u.email === B.email), 'tìm thấy Bob qua tên');
  const emptySearch = await call('GET', '/api/users?q=', { token: A.access });
  ok(emptySearch.data.users.length === 0, 'q rỗng -> []');
  const pub = await call('GET', `/api/users/${B.user.id}`, { token: A.access });
  ok(pub.status === 200 && pub.data.user.email === B.email && pub.data.isFriend === false, 'hồ sơ công khai + isFriend');

  console.log('== Đổi mật khẩu ==');
  const wrongOld = await call('POST', '/api/me/password', { token: A.access, body: { currentPassword: 'sai123456', newPassword: 'MoiKhau123' } });
  ok(wrongOld.status === 400, 'sai mật khẩu cũ -> 400');
  const weak = await call('POST', '/api/me/password', { token: A.access, body: { currentPassword: 'MatKhau123', newPassword: 'abc' } });
  ok(weak.status === 400, 'mật khẩu mới yếu -> 400');
  const change = await call('POST', '/api/me/password', { token: A.access, body: { currentPassword: 'MatKhau123', newPassword: 'MoiKhau123' } });
  ok(change.status === 200 && change.data.accessToken, 'đổi mk -> token mới');
  const oldRefresh = await call('POST', '/api/auth/refresh', { body: { refreshToken: A.refresh } });
  ok(oldRefresh.status === 401, 'refresh token cũ bị thu hồi (bắt buộc đăng nhập lại ở thiết bị khác)');
  const loginNew = await call('POST', '/api/auth/login', { body: { email: A.email, password: 'MoiKhau123' } });
  ok(loginNew.status === 200, 'đăng nhập bằng mật khẩu mới');
  A.access = loginNew.data.accessToken;
  A.refresh = loginNew.data.refreshToken;

  console.log('== Tạo phòng ==');
  const roomsBefore = (await call('GET', '/api/rooms', { token: A.access })).data.rooms.length;
  const newRoom = await call('POST', '/api/rooms', { token: A.access, body: { name: 'Phòng test 🎵', topic: 'Test thôi', backgroundEmoji: '🎵' } });
  ok(newRoom.status === 201 && newRoom.data.room.id, 'tạo phòng mới');
  const rooms = await call('GET', '/api/rooms', { token: A.access });
  ok(rooms.data.rooms.length === roomsBefore + 1, 'danh sách phòng tăng đúng 1');

  console.log('== Bài viết: sửa/xóa + phân trang ==');
  const post = await call('POST', '/api/feed', { token: A.access, body: { content: 'Bài gốc', media: [imgUrl] } });
  const pid = post.data.post.id;
  ok(post.data.post.media[0] === imgUrl, 'bài viết có ảnh URL thật');
  const editPost = await call('PATCH', `/api/feed/${pid}`, { token: A.access, body: { content: 'Bài đã sửa' } });
  ok(editPost.status === 200 && editPost.data.post.content === 'Bài đã sửa', 'sửa bài viết');
  const editByB = await call('PATCH', `/api/feed/${pid}`, { token: B.access, body: { content: 'Hack' } });
  ok(editByB.status === 403, 'người khác không sửa được bài');
  const delByB = await call('DELETE', `/api/feed/${pid}`, { token: B.access });
  ok(delByB.status === 403, 'người khác không xóa được bài');
  const page1 = await call('GET', '/api/feed?limit=2', { token: A.access });
  const page2 = await call('GET', `/api/feed?limit=2&offset=2`, { token: A.access });
  ok(page1.data.posts.length === 2 && page2.data.posts.length === 2 &&
     page1.data.posts[0].id !== page2.data.posts[0].id, 'phân trang feed (offset)');

  console.log('== Bình luận: sửa/xóa ==');
  const cm = await call('POST', `/api/feed/${pid}/comments`, { token: A.access, body: { content: 'Cần sửa' } });
  const cid = cm.data.comment.id;
  const editCm = await call('PATCH', `/api/feed/${pid}/comments/${cid}`, { token: A.access, body: { content: 'Đã sửa cm' } });
  ok(editCm.status === 200 && editCm.data.comment.content === 'Đã sửa cm', 'sửa bình luận');
  const editCmByB = await call('PATCH', `/api/feed/${pid}/comments/${cid}`, { token: B.access, body: { content: 'x' } });
  ok(editCmByB.status === 403, 'người khác không sửa được bình luận');
  const delCm = await call('DELETE', `/api/feed/${pid}/comments/${cid}`, { token: A.access });
  ok(delCm.status === 200, 'xóa bình luận');
  const delPost = await call('DELETE', `/api/feed/${pid}`, { token: A.access });
  ok(delPost.status === 200, 'xóa bài viết');

  console.log('== Tin nhắn: phân trang + sửa/xóa + typing ==');
  const ensure = await call('POST', '/api/conversations/ensure', { token: A.access, body: { partnerId: B.user.id } });
  const convId = ensure.data.conversationId;
  for (let i = 1; i <= 5; i++) {
    await call('POST', `/api/conversations/${convId}/messages`, { token: A.access, body: { content: `tin ${i}` } });
  }
  const all = await call('GET', `/api/conversations/${convId}/messages?limit=3`, { token: A.access });
  ok(all.data.messages.length === 3 && all.data.hasMore === true, 'phân trang tin nhắn (limit + hasMore)');
  const older = await call('GET', `/api/conversations/${convId}/messages?limit=10&before=${encodeURIComponent(all.data.messages[0].createdAt)}`, { token: A.access });
  ok(older.data.messages.length === 2 && older.data.hasMore === false, 'phân trang tin nhắn (before)');
  const firstMsg = (await call('GET', `/api/conversations/${convId}/messages`, { token: A.access })).data.messages[0];
  const editMsg = await call('PATCH', `/api/conversations/${convId}/messages/${firstMsg.id}`, { token: A.access, body: { content: 'tin đã sửa' } });
  ok(editMsg.status === 200 && editMsg.data.message.content === 'tin đã sửa', 'sửa tin nhắn');
  const delMsg = await call('DELETE', `/api/conversations/${convId}/messages/${firstMsg.id}`, { token: A.access });
  ok(delMsg.status === 200, 'xóa tin nhắn');

  console.log('== Ảnh trong chat ==');
  const imageMessage = await call('POST', `/api/conversations/${convId}/messages`, {
    token: A.access, body: { content: imgUrl, type: 'image' },
  });
  ok(imageMessage.status === 201 && imageMessage.data.message.type === 'image',
    'API trả đúng type=image ngay sau khi gửi ảnh');
  const imageHistory = await call('GET', `/api/conversations/${convId}/messages`, { token: B.access });
  ok(imageHistory.status === 200 && imageHistory.data.messages.some(
    (m) => m.id === imageMessage.data.message.id && m.type === 'image'),
    'người nhận tải lịch sử với type=image, không phải URL dạng text');
  const imageEvent = await call('GET', `/api/conversations/${convId}/messages`, { token: B.access });
  const uploadedImage = await fetch(BASE + imgUrl);
  ok(imageEvent.data.messages.find((m) => m.id === imageMessage.data.message.id)?.content === imgUrl &&
    uploadedImage.status === 200 && uploadedImage.headers.get('content-type')?.startsWith('image/'),
    'URL ảnh đã lưu trả ảnh tĩnh ngay, không cần chờ cache hoặc tải lại hội thoại');

  console.log('== Bạn bè qua Soul Game + typing relay ==');
  const sA = io(BASE, { transports: ['websocket'], rejectUnauthorized: false, auth: { token: A.access } });
  const sB = io(BASE, { transports: ['websocket'], rejectUnauthorized: false, auth: { token: B.access } });
  await Promise.all([waitEvent(sA, 'connect'), waitEvent(sB, 'connect')]);
  sB.emit('soul:queue', { mode: 'text' });
  sA.emit('soul:queue', { mode: 'text' });
  const [mA, mB] = await Promise.all([waitEvent(sA, 'soul:matched'), waitEvent(sB, 'soul:matched')]);
  ok(mA.sessionId === mB.sessionId && mA.mode === 'text', 'ghép text mode');
  const revealA = waitEvent(sA, 'soul:revealed');
  const revealB = waitEvent(sB, 'soul:revealed');
  sA.emit('soul:reveal', { sessionId: mA.sessionId });
  const [rvA] = await Promise.all([revealA, revealB]);
  ok(!!rvA.conversationId, 'reveal -> kết bạn + hội thoại');

  const friends = await call('GET', '/api/friends', { token: A.access });
  ok(friends.data.friends.some((f) => f.email === B.email && f.conversationId), 'danh sách bạn bè có Bob + conversationId');

  const typingGot = waitEvent(sB, 'chat:typing');
  sA.emit('chat:typing', { conversationId: rvA.conversationId });
  const typing = await typingGot;
  ok(typing.conversationId === rvA.conversationId, 'relay "đang gõ" 1-1');

  // Voice mode không ghép nhầm với text mode
  const queuedV = waitEvent(sB, 'soul:queued');
  sB.emit('soul:queue', { mode: 'voice' });
  await queuedV;
  ok(true, 'voice mode vào hàng đợi riêng');
  const mAVoice = waitEvent(sA, 'soul:matched');
  sA.emit('soul:queue', { mode: 'text' });
  const unmatched = await Promise.race([mAVoice.then(() => 'matched'), wait(1200).then(() => 'waiting')]);
  ok(unmatched === 'waiting', 'voice không ghép với text');

  sA.disconnect();
  sB.disconnect();

  console.log(`\n>>> ${passed} passed, ${failed} failed`);
  process.exit(failed ? 1 : 0);
}

main().catch((e) => { console.error('LỖI:', e); process.exit(1); });
