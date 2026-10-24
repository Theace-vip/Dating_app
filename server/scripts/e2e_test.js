// Smoke test E2E: node scripts/e2e_test.js  (server phải đang chạy)
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

const BASE = 'https://localhost:3000';
let passed = 0, failed = 0;

function ok(cond, name) {
  if (cond) { passed++; console.log('  ✓', name); }
  else { failed++; console.log('  ✗', name); }
}

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
  try { data = await res.json(); } catch { /* 204 */ }
  return { status: res.status, data };
}

async function main() {
  console.log('== Health ==');
  const h = await call('GET', '/health');
  ok(h.status === 200 && h.data.ok, 'GET /health');

  console.log('== Auth ==');
  const email = `test_${Date.now()}@test.app`;
  const reg = await call('POST', '/api/auth/register', {
    body: { email, password: 'MatKhau123', name: 'Người Test' },
  });
  ok(reg.status === 201 && reg.data.accessToken && reg.data.user.profileCompleted === false,
    'register trả token + user (chưa hoàn thành hồ sơ)');
  const access = reg.data.accessToken;
  let refresh = reg.data.refreshToken;

  const bad = await call('POST', '/api/auth/login', { body: { email, password: 'sai123456' } });
  ok(bad.status === 401, 'sai mật khẩu -> 401');

  const login = await call('POST', '/api/auth/login', { body: { email, password: 'MatKhau123' } });
  ok(login.status === 200, 'đăng nhập đúng -> 200');
  refresh = login.data.refreshToken;
  const access2 = login.data.accessToken;

  const r1 = await call('POST', '/api/auth/refresh', { body: { refreshToken: refresh } });
  ok(r1.status === 200 && r1.data.refreshToken !== refresh, 'refresh xoay token mới');
  const reuse = await call('POST', '/api/auth/refresh', { body: { refreshToken: refresh } });
  ok(reuse.status === 401, 'dùng lại refresh cũ -> 401 (phát hiện đánh cắp)');
  refresh = r1.data.refreshToken;

  const meBad = await call('GET', '/api/me');
  ok(meBad.status === 401, 'không token -> 401');

  console.log('== Profile ==');
  const me = await call('GET', '/api/me', { token: access2 });
  ok(me.status === 200 && me.data.user.email === email, 'GET /api/me');
  const patch = await call('PATCH', '/api/me', {
    token: access2,
    body: { name: 'Test Đẹp Trai', age: 25, gender: 'male', bio: 'Xin chào', tags: ['Game'], profileCompleted: true },
  });
  ok(patch.status === 200 && patch.data.user.profileCompleted === true && patch.data.user.age === 25,
    'PATCH /api/me cập nhật + hoàn thành hồ sơ');

  console.log('== Feed ==');
  const feed = await call('GET', '/api/feed', { token: access2 });
  ok(feed.status === 200 && feed.data.posts.length >= 3, 'GET /api/feed có bài seed');
  const pid = feed.data.posts[0].id;
  const like = await call('POST', `/api/feed/${pid}/like`, { token: access2 });
  ok(like.status === 200 && like.data.likedByMe === true, 'like bài viết');
  const unlike = await call('POST', `/api/feed/${pid}/like`, { token: access2 });
  ok(unlike.status === 200 && unlike.data.likedByMe === false, 'unlike bài viết');
  const newPost = await call('POST', '/api/feed', { token: access2, body: { content: 'Bài test 🚀', media: ['🚀'] } });
  ok(newPost.status === 201 && newPost.data.post.likes === 0, 'tạo bài viết');
  const cm = await call('POST', `/api/feed/${newPost.data.post.id}/comments`, { token: access2, body: { content: 'Bình luận test' } });
  ok(cm.status === 201, 'bình luận');
  const cms = await call('GET', `/api/feed/${newPost.data.post.id}/comments`, { token: access2 });
  ok(cms.status === 200 && cms.data.comments.length === 1, 'lấy danh sách bình luận');
  // Chỉ đếm share ngoài sau khi bảng chia sẻ hệ điều hành báo mở thành công.
  const unconfirmedShare = await call('POST', `/api/feed/${newPost.data.post.id}/share`, { token: access2 });
  ok(unconfirmedShare.status === 200 && unconfirmedShare.data.shares === 0,
    'share chưa xác nhận không làm tăng bộ đếm');
  const share = await call('POST', `/api/feed/${newPost.data.post.id}/share`, {
    token: access2, body: { confirmed: true },
  });
  ok(share.status === 200 && share.data.shares === 1, 'chia sẻ xác nhận thành công');

  console.log('== Conversations ==');
  const ensure = await call('POST', '/api/conversations/ensure', { token: access2, body: { partnerId: 'u_demo1' } });
  ok(ensure.status === 200 && ensure.data.conversationId, 'tạo hội thoại với demo1');
  const convId = ensure.data.conversationId;
  const send = await call('POST', `/api/conversations/${convId}/messages`, { token: access2, body: { content: 'Xin chào demo!' } });
  ok(send.status === 201 && send.data.message.content === 'Xin chào demo!', 'gửi tin nhắn');
  const list = await call('GET', '/api/conversations', { token: access2 });
  ok(list.status === 200 && list.data.conversations.some((c) => c.id === convId && c.lastMessage === 'Xin chào demo!'),
    'danh sách hội thoại có tin mới nhất');
  const msgs = await call('GET', `/api/conversations/${convId}/messages`, { token: access2 });
  ok(msgs.status === 200 && msgs.data.messages.length === 1, 'lấy lịch sử tin nhắn');

  // demo1 đọc tin -> unread của demo1 = 0, của mình khi demo1 gửi sẽ tăng
  const demoLogin = await call('POST', '/api/auth/login', { body: { email: 'demo1@soulmate.app', password: 'Demo@1234' } });
  const demoAccess = demoLogin.data.accessToken;
  const demoConvs = await call('GET', '/api/conversations', { token: demoAccess });
  const dc = demoConvs.data.conversations.find((c) => c.id === convId);
  ok(dc && dc.unreadCount === 1, 'demo1 có 1 tin chưa đọc');
  const demoSend = await call('POST', `/api/conversations/${convId}/messages`, { token: demoAccess, body: { content: 'Chào bạn!' } });
  ok(demoSend.status === 201, 'demo1 trả lời');
  const myConvs = await call('GET', '/api/conversations', { token: access2 });
  const mc = myConvs.data.conversations.find((c) => c.id === convId);
  ok(mc && mc.unreadCount === 1 && mc.lastMessage === 'Chào bạn!', 'tin nhắn hiển thị + chưa đọc');
  await call('GET', `/api/conversations/${convId}/messages`, { token: access2 });
  const myConvs2 = await call('GET', '/api/conversations', { token: access2 });
  ok(myConvs2.data.conversations.find((c) => c.id === convId).unreadCount === 0, 'đánh dấu đã đọc');

  console.log('== Rooms ==');
  const rooms = await call('GET', '/api/rooms', { token: access2 });
  ok(rooms.status === 200 && rooms.data.rooms.length >= 3, 'GET /api/rooms có ít nhất 3 phòng seed');
  const rid = rooms.data.rooms[0].id;
  const rm = await call('POST', `/api/rooms/${rid}/messages`, { token: access2, body: { content: 'Hello phòng' } });
  ok(rm.status === 201, 'gửi tin vào phòng (REST)');
  const rmsgs = await call('GET', `/api/rooms/${rid}/messages`, { token: access2 });
  ok(rmsgs.status === 200 && rmsgs.data.messages.length >= 1, 'lấy lịch sử phòng');

  console.log('== Bảo mật ==');
  const weak = await call('POST', '/api/auth/register', { body: { email: 'w@w.com', password: 'abc', name: 'W' } });
  ok(weak.status === 400, 'mật khẩu yếu -> 400');
  const badEmail = await call('POST', '/api/auth/register', { body: { email: 'khong-phai-email', password: 'MatKhau123', name: 'W' } });
  ok(badEmail.status === 400, 'email sai -> 400');
  const noToken = await call('GET', '/api/feed');
  ok(noToken.status === 401, 'API cần xác thực');

  console.log(`\n>>> ${passed} passed, ${failed} failed`);
  process.exit(failed ? 1 : 0);
}

main().catch((e) => { console.error('LỖI:', e); process.exit(1); });
