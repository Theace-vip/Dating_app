// Test feed realtime: node scripts/realtime_feed_test.js (server phải đang chạy)
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';
import { io } from 'socket.io-client';

const BASE = 'https://localhost:3000';
let passed = 0, failed = 0;
const ok = (cond, name) => {
  if (cond) { passed++; console.log('  ✓', name); }
  else { failed++; console.log('  ✗', name); }
};
const wait = (ms) => new Promise((r) => setTimeout(r, ms));
const waitEvent = (sock, event, timeout = 4000) =>
  new Promise((resolve, reject) => {
    const t = setTimeout(() => reject(new Error(`timeout chờ event ${event}`)), timeout);
    sock.once(event, (data) => { clearTimeout(t); resolve(data); });
  });

async function login(email, password) {
  const res = await fetch(`${BASE}/api/auth/login`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
  const j = await res.json();
  if (!j.accessToken) throw new Error('login fail: ' + JSON.stringify(j));
  return j.accessToken;
}

function connect(token) {
  return io(BASE, {
    transports: ['websocket'],
    rejectUnauthorized: false,
    auth: { token },
  });
}

async function main() {
  const token1 = await login('demo1@soulmate.app', 'Demo@1234');
  const token2 = await login('demo2@soulmate.app', 'Demo@1234');
  const s1 = connect(token1);
  const s2 = connect(token2);
  await Promise.all([waitEvent(s1, 'connect'), waitEvent(s2, 'connect')]);
  ok(s1.connected && s2.connected, '2 client kết nối');

  const auth = {
    'content-type': 'application/json',
    authorization: `Bearer ${token1}`,
  };

  console.log('== Đăng bài realtime ==');
  // s2 chờ sự kiện TRƯỚC khi post để không miss
  const pNew2 = waitEvent(s2, 'feed:new');
  const pNew1 = waitEvent(s1, 'feed:new');
  const create = await fetch(`${BASE}/api/feed`, {
    method: 'POST', headers: auth,
    body: JSON.stringify({ content: `Bài test realtime ${Date.now()}` }),
  });
  const created = (await create.json()).post;
  ok(!!created, 'POST /api/feed trả về bài mới');
  const [ev1, ev2] = await Promise.all([pNew1, pNew2]);
  ok(ev1.post?.id === created.id, 'client 1 (người đăng) nhận feed:new');
  ok(ev2.post?.id === created.id, 'client 2 (người khác) nhận feed:new');

  console.log('== Like realtime ==');
  const pStats1 = waitEvent(s1, 'feed:stats');
  await fetch(`${BASE}/api/feed/${created.id}/like`, {
    method: 'POST', headers: { 'content-type': 'application/json', authorization: `Bearer ${token2}` },
  });
  const st = await pStats1;
  ok(st.postId === created.id && st.likes === 1, 'client 1 nhận feed:stats likes=1');

  console.log('== Bình luận realtime ==');
  const pStats2 = waitEvent(s1, 'feed:stats');
  const pComment1 = waitEvent(s1, 'feed:comment:new');
  const pComment2 = waitEvent(s2, 'feed:comment:new');
  const createdCommentRes = await fetch(`${BASE}/api/feed/${created.id}/comments`, {
    method: 'POST', headers: { 'content-type': 'application/json', authorization: `Bearer ${token2}` },
    body: JSON.stringify({ content: 'test comment' }),
  });
  const createdComment = (await createdCommentRes.json()).comment;
  const [st2, comment1, comment2] = await Promise.all([pStats2, pComment1, pComment2]);
  ok(st2.postId === created.id && st2.comments === 1, 'client 1 nhận feed:stats comments=1');
  ok(comment1.comment?.id === createdComment.id &&
      comment2.comment?.content === 'test comment',
      'hai client nhận nội dung bình luận cùng tác giả qua realtime');

  console.log('== Sửa/xóa bình luận realtime ==');
  const editEvent = waitEvent(s1, 'feed:comment:updated');
  await fetch(`${BASE}/api/feed/${created.id}/comments/${createdComment.id}`, {
    method: 'PATCH',
    headers: { 'content-type': 'application/json', authorization: `Bearer ${token2}` },
    body: JSON.stringify({ content: 'đã sửa bình luận' }),
  });
  ok((await editEvent).comment?.content === 'đã sửa bình luận',
    'client khác nhận nội dung bình luận sau khi sửa');
  const deleteEvent = waitEvent(s1, 'feed:comment:deleted');
  const deleteStats = waitEvent(s1, 'feed:stats');
  const deleteCommentRes = await fetch(
    `${BASE}/api/feed/${created.id}/comments/${createdComment.id}`,
    { method: 'DELETE', headers: { authorization: `Bearer ${token2}` } },
  );
  const [deletedComment, deleteCommentBody, deleteStatsBody] = await Promise.all([
    deleteEvent,
    deleteCommentRes.json(),
    deleteStats,
  ]);
  ok(deletedComment.commentId === createdComment.id &&
      deleteCommentBody.comments === 0 && deleteStatsBody.comments === 0,
      'xóa bình luận realtime và cập nhật bộ đếm về chính xác');

  console.log('== Đăng lại feed + đếm lượt chia sẻ ==');
  const notConfirmedShare = await fetch(`${BASE}/api/feed/${created.id}/share`, {
    method: 'POST', headers: { authorization: `Bearer ${token2}` },
  });
  ok((await notConfirmedShare.json()).shares === 0,
    'mở chọn chia sẻ nhưng chưa xác nhận không tăng bộ đếm');
  const repostEvent1 = waitEvent(s1, 'feed:new');
  const repostEvent2 = waitEvent(s2, 'feed:new');
  const shareStats = waitEvent(s1, 'feed:stats');
  const repostRes = await fetch(`${BASE}/api/feed/${created.id}/share`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', authorization: `Bearer ${token2}` },
    body: JSON.stringify({ repostContent: 'Tôi muốn chia sẻ bài này' }),
  });
  const repostResult = await repostRes.json();
  const [repost1, repost2, updatedStats] = await Promise.all([
    repostEvent1,
    repostEvent2,
    shareStats,
  ]);
  ok(repostResult.repost?.originalPost?.postId === created.id &&
      repostResult.repost.content === 'Tôi muốn chia sẻ bài này' &&
      repost1.post?.id === repostResult.repost.id &&
      repost2.post?.originalPost?.postId === created.id &&
      updatedStats.shares === 1,
      'repost lưu caption/bài gốc, phát realtime và tăng share count đúng một lần');
  const confirmedStats = waitEvent(s1, 'feed:stats');
  const externalShare = await fetch(`${BASE}/api/feed/${created.id}/share`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', authorization: `Bearer ${token2}` },
    body: JSON.stringify({ confirmed: true }),
  });
  const externalResult = await externalShare.json();
  ok(externalResult.shares === 2 && externalResult.repost == null &&
      (await confirmedStats).shares === 2,
      'xác nhận share ngoài tăng đúng một lượt nhưng không tạo repost');
  console.log('== Sửa bài realtime ==');
  const pUpd = waitEvent(s2, 'feed:updated');
  await fetch(`${BASE}/api/feed/${created.id}`, {
    method: 'PATCH', headers: auth,
    body: JSON.stringify({ content: 'Đã sửa bài' }),
  });
  const up = await pUpd;
  ok(up.post?.id === created.id && up.post.content === 'Đã sửa bài', 'client 2 nhận feed:updated');

  console.log('== Phân trang before cursor ==');
  const page = await fetch(`${BASE}/api/feed?limit=3`, { headers: auth });
  const posts = (await page.json()).posts;
  ok(posts.length > 0, 'GET /api/feed?limit=3 có bài');
  if (posts.length > 0) {
    const cursor = posts[posts.length - 1].createdAt;
    const page2 = await fetch(
      `${BASE}/api/feed?limit=3&before=${encodeURIComponent(cursor)}`, { headers: auth });
    const j2 = await page2.json();
    ok(Array.isArray(j2.posts) && j2.posts.length > 0, 'GET /api/feed?before=cursor hoạt động');
    ok(j2.posts.some((p) => p.id === posts[posts.length - 1].id),
      'cursor <= nên bài mốc vẫn được trả (client tự loại trùng)');
  }

  console.log('== Xóa bài realtime ==');
  const pDel = waitEvent(s2, 'feed:deleted');
  await fetch(`${BASE}/api/feed/${created.id}`, { method: 'DELETE', headers: auth });
  const del = await pDel;
  ok(del.postId === created.id, 'client 2 nhận feed:deleted');

  s1.disconnect();
  s2.disconnect();
  console.log(`\nKết quả: ${passed} pass, ${failed} fail`);
  process.exit(failed > 0 ? 1 : 0);
}

main().catch((e) => { console.error('✗ LỖI:', e.message); process.exit(1); });
