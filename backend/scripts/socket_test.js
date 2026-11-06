// Smoke test Socket.io: node scripts/socket_test.js (server phải đang chạy)
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';
import { io } from 'socket.io-client';
import db from '../src/db.js';
import { APP_CATALOG, chargeRoomGift } from '../src/catalog.js';
import { canExpireSoulSession } from '../src/socket.js';

const BASE = process.env.TEST_BASE_URL || 'https://localhost:3000';
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
  return (await res.json()).accessToken;
}

function connect(token) {
  return io(BASE, {
    transports: ['websocket'],
    rejectUnauthorized: false,
    auth: { token },
  });
}

async function main() {
  console.log('== API catalog + server-side gift accounting ==');
  const catalog = await fetch(`${BASE}/api/catalog`);
  ok(catalog.status === 401, 'catalog API yêu cầu access token');

  const tokenForCatalog = await login('demo1@soulmate.app', 'Demo@1234');
  const catalogRes = await fetch(`${BASE}/api/catalog`, {
    headers: { authorization: `Bearer ${tokenForCatalog}` },
  });
  const catalogData = await catalogRes.json();
  ok(catalogRes.status === 200 && catalogData.profile.avatars.length > 0 &&
      catalogData.profile.interests.length > 0 &&
      catalogData.rooms.gifts.length === APP_CATALOG.rooms.gifts.length &&
      catalogData.wallet.coinPackages[0].coins === 50 &&
      catalogData.vip.plan.priceVnd === 79000 &&
      catalogData.matching.voiceSeconds === APP_CATALOG.matching.voiceSeconds,
      'API catalog trả danh mục hồ sơ, quà, ví, VIP và thời lượng từ server');

  const originalCoins = db.prepare('SELECT coins FROM users WHERE id = ?').get('u_demo1').coins;
  // Giao dịch giảm số dư là một UPDATE có điều kiện nguyên tử trong SQLite.
  const giftTransaction = (userId, giftId) => chargeRoomGift(db, userId, giftId);
  const invalidGift = giftTransaction('u_demo1', 'not_a_server_gift');
  ok(!invalidGift.ok && invalidGift.reason === 'invalid_gift' &&
      db.prepare('SELECT coins FROM users WHERE id = ?').get('u_demo1').coins === originalCoins,
      'không nhận quà không có trong catalog và không đổi số dư');

  const chargedGift = giftTransaction('u_demo1', APP_CATALOG.rooms.gifts[0].id);
  ok(chargedGift.ok && chargedGift.gift.cost === 5 && chargedGift.coins === originalCoins - 5,
      'gửi quà hợp lệ trừ đúng giá do server quy định');
  db.prepare('UPDATE users SET coins = 0 WHERE id = ?').run('u_demo1');
  const insufficient = giftTransaction('u_demo1', APP_CATALOG.rooms.gifts[0].id);
  ok(!insufficient.ok && insufficient.reason === 'insufficient_coins' &&
      db.prepare('SELECT coins FROM users WHERE id = ?').get('u_demo1').coins === 0,
      'từ chối quà khi thiếu xu và không để số dư âm');
  db.prepare('UPDATE users SET coins = ? WHERE id = ?').run(originalCoins, 'u_demo1');
  const missingUser = giftTransaction('user_missing_for_gift_test', APP_CATALOG.rooms.gifts[0].id);
  ok(!missingUser.ok && missingUser.reason === 'user_not_found',
      'giao dịch quà báo user không tồn tại');

  const sessionRule = {
    a: { socketId: 'member-a' }, b: { socketId: 'member-b' },
    endsAt: 5000, completed: false, timeExpired: false,
  };
  ok(!canExpireSoulSession(sessionRule, 'outsider', 6000) &&
      !canExpireSoulSession(sessionRule, 'member-a', 4999) &&
      canExpireSoulSession(sessionRule, 'member-a', 5000),
      'chỉ thành viên được hết giờ và không thể bỏ qua đồng hồ server');
  ok(!canExpireSoulSession({ ...sessionRule, completed: true }, 'member-a', 6000) &&
      !canExpireSoulSession({ ...sessionRule, timeExpired: true }, 'member-a', 6000),
      'không phát hết giờ lần nữa cho phiên đã hoàn tất hoặc hết giờ');

  console.log('== Socket auth ==');
  const noAuth = io(BASE, { transports: ['websocket'], rejectUnauthorized: false });
  const denied = await Promise.race([
    waitEvent(noAuth, 'connect_error'),
    wait(3000).then(() => null),
  ]);
  ok(!!denied, 'kết nối không token -> connect_error');
  noAuth.disconnect();

  const token1 = await login('demo1@soulmate.app', 'Demo@1234');
  const token2 = await login('demo2@soulmate.app', 'Demo@1234');

  const s1 = connect(token1);
  let s2 = connect(token2);
  await Promise.all([waitEvent(s1, 'connect'), waitEvent(s2, 'connect')]);
  ok(s1.connected && s2.connected, 'cả 2 client kết nối bằng access token');

  console.log('== Matching Soul Game ==');
  s2.emit('soul:queue');
  const queued = await waitEvent(s2, 'soul:queued');
  ok(!!queued, 'client 2 vào hàng đợi');

  s1.emit('soul:queue');
  const [m1, m2] = await Promise.all([waitEvent(s1, 'soul:matched'), waitEvent(s2, 'soul:matched')]);
  ok(m1.sessionId === m2.sessionId, '2 client được ghép cùng phiên');
  ok(m1.stranger && m1.stranger.avatar && !m1.stranger.id && !m1.stranger.name,
    'stranger ẩn danh (chỉ avatar/tuổi/giới tính, không id/tên)');
  const sid = m1.sessionId;

  const gotMsg = waitEvent(s2, 'soul:message');
  s1.emit('soul:message', { sessionId: sid, content: 'Chào bạn, mình là người thật!' });
  const msg = await gotMsg;
  ok(msg.content === 'Chào bạn, mình là người thật!', 'relay tin nhắn ẩn danh 2 chiều');

  console.log('== Đồng hồ phiên do server quản lý ==');
  // Không cho client gian lận bằng cách giả vờ đồng hồ trên thiết bị đã hết.
  const prematureEnd = waitEvent(s1, 'soul:time-ended', 500);
  s1.emit('soul:finish', { sessionId: sid });
  let prematureFinishRejected = false;
  try {
    await prematureEnd;
  } catch {
    prematureFinishRejected = true;
  }
  ok(prematureFinishRejected,
    'client gửi kết thúc sớm không thể làm phiên hết giờ ở server');
  const deniedContinueAfterEarlyFinish = waitEvent(s1, 'soul:continue:error');
  s1.emit('soul:continue', { sessionId: sid });
  ok((await deniedContinueAfterEarlyFinish).sessionId === sid,
    'không gia hạn phiên khi đồng hồ server chưa hết giờ');

  // Unit-test policy bằng mốc thời gian giả lập, không chờ timer thật 3 phút.
  const simulatedExpiredSession = {
    a: { socketId: s1.id }, b: { socketId: s2.id },
    endsAt: Date.now() - 1, completed: false, timeExpired: false,
  };
  ok(canExpireSoulSession(simulatedExpiredSession, s1.id) &&
      !canExpireSoulSession(simulatedExpiredSession, 'outsider'),
      'policy cho hết giờ chỉ với thành viên sau khi mốc server tới hạn');
  ok(!canExpireSoulSession({ ...simulatedExpiredSession, endsAt: Date.now() + 10000 }, s1.id),
      'policy từ chối hết giờ trước mốc server');

  console.log('== Hiện danh tính + kết bạn ==');
  const revealP1 = waitEvent(s1, 'soul:revealed');
  const revealP2 = waitEvent(s2, 'soul:revealed');
  s1.emit('soul:reveal', { sessionId: sid });
  const [rv1, rv2] = await Promise.all([revealP1, revealP2]);
  ok(rv1.conversationId === rv2.conversationId, 'cả 2 nhận cùng conversationId sau reveal');
  ok(rv1.user && rv1.user.name, 'nhận thông tin thật của đối phương');

  const convRes = await fetch(`${BASE}/api/conversations`, {
    headers: { authorization: `Bearer ${token1}` },
  });
  const convs = (await convRes.json()).conversations;
  ok(convs.some((c) => c.id === rv1.conversationId), 'hội thoại đã được tạo trong DB');

  console.log('== Ảnh chat realtime ==');
  const uploadRes = await fetch(`${BASE}/api/upload`, {
    method: 'POST', headers: {
      'content-type': 'application/json',
      authorization: `Bearer ${token1}`,
    },
    body: JSON.stringify({
      dataUrl: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    }),
  });
  const imageUrl = (await uploadRes.json()).url;
  const imageEventPromise = waitEvent(s2, 'chat:message');
  const imageSend = await fetch(
    `${BASE}/api/conversations/${rv1.conversationId}/messages`,
    {
      method: 'POST', headers: {
        'content-type': 'application/json',
        authorization: `Bearer ${token1}`,
      },
      body: JSON.stringify({ content: imageUrl, type: 'image' }),
    },
  );
  const imageBody = await imageSend.json();
  const imageEvent = await imageEventPromise;
  ok(imageBody.message?.type === 'image' && imageEvent.message?.type === 'image',
    'API và socket phát type=image, người nhận sẽ render ảnh thay URL');

  console.log('== Phòng tiệc realtime ==');
  const roomsRes = await fetch(`${BASE}/api/rooms`, { headers: { authorization: `Bearer ${token1}` } });
  const roomId = (await roomsRes.json()).rooms[0].id;

  const presenceP = waitEvent(s2, 'room:presence');
  s2.emit('room:join', { roomId });
  const p1 = await presenceP;
  ok(p1.roomId === roomId && p1.members.length === 1, 'join phòng -> broadcast presence (1 người)');

  const presenceP2a = waitEvent(s1, 'room:presence');
  const presenceP2b = waitEvent(s2, 'room:presence');
  s1.emit('room:join', { roomId });
  const [p2a, p2b] = await Promise.all([presenceP2a, presenceP2b]);
  ok(p2a.members.length === 2 && p2b.members.length === 2, 'client 1 join -> cả 2 thấy 2 thành viên');

  const outsiderMessage = waitEvent(s1, 'room:message', 700);
  s1.emit('room:leave', { roomId });
  s1.emit('room:message', { roomId, content: 'Không được gửi khi đã rời' });
  const outsiderWallet = waitEvent(s1, 'user:wallet', 700);
  s1.emit('room:gift', { roomId, gift: '💎' });
  let outsiderWasBlocked = false;
  try {
    await outsiderMessage;
  } catch {
    outsiderWasBlocked = true;
  }
  ok(outsiderWasBlocked, 'client đã rời phòng không thể phát room:message');
  let outsiderGiftBlocked = false;
  try {
    await outsiderWallet;
  } catch {
    outsiderGiftBlocked = true;
  }
  ok(outsiderGiftBlocked, 'client đã rời phòng không thể trừ Xu/gửi room:gift');
  const rtcPeersOutsider = waitEvent(s1, 'room:rtc:peers', 700);
  s1.emit('room:rtc:join', { roomId });
  let outsiderRtcBlocked = false;
  try {
    await rtcPeersOutsider;
  } catch {
    outsiderRtcBlocked = true;
  }
  ok(outsiderRtcBlocked, 'client ngoài phòng không thể mở mic room:rtc');
  const rejoinP = waitEvent(s1, 'room:presence');
  s1.emit('room:join', { roomId });
  await rejoinP;

  const roomMsgP = waitEvent(s2, 'room:message');
  s1.emit('room:message', { roomId, content: 'Hello cả nhà' });
  const rm = await roomMsgP;
  ok(rm.message.content === 'Hello cả nhà' && rm.message.senderName, 'relay tin phòng + có tên người gửi');

  const heartP = waitEvent(s2, 'room:heart');
  s1.emit('room:heart', { roomId });
  const heart = await heartP;
  ok(heart.from && heart.from.name, 'thả tim realtime');

  const outsiderHeart = waitEvent(s2, 'room:heart', 700);
  s1.emit('room:leave', { roomId });
  s1.emit('room:heart', { roomId });
  let outsiderHeartBlocked = false;
  try {
    await outsiderHeart;
  } catch {
    outsiderHeartBlocked = true;
  }
  ok(outsiderHeartBlocked, 'client ngoài phòng không thể phát room:heart');
  const rejoinBeforeGift = waitEvent(s1, 'room:presence');
  s1.emit('room:join', { roomId });
  await rejoinBeforeGift;

  const giftP = waitEvent(s2, 'room:gift');
  const walletP = waitEvent(s1, 'user:wallet');
  s1.emit('room:gift', { roomId, gift: '🌹' });
  const [gift, wallet] = await Promise.all([giftP, walletP]);
  ok(gift.gift === '🌹', 'nhận quà realtime');
  ok(typeof wallet.coins === 'number' && wallet.coins ===
      db.prepare('SELECT coins FROM users WHERE id = ?').get('u_demo1').coins,
      'ví realtime khớp số dư đã trừ ở server');

  const invalidGiftError = waitEvent(s1, 'room:error');
  const unchangedCoins = wallet.coins;
  s1.emit('room:gift', { roomId, gift: '🌈-not-in-catalog' });
  const invalidGiftMessage = await invalidGiftError;
  ok(invalidGiftMessage.message.includes('không hợp lệ') &&
      db.prepare('SELECT coins FROM users WHERE id = ?').get('u_demo1').coins === unchangedCoins,
      'Socket chặn quà giả và không thay số dư');

  // Tách số dư về 0 để kiểm tra lỗi thiếu Xu, sau đó phục hồi cả khi request lỗi.
  const balanceBeforeInsufficientTest = db.prepare(
    'SELECT coins FROM users WHERE id = ?',
  ).get('u_demo1').coins;
  db.prepare('UPDATE users SET coins = 0 WHERE id = ?').run('u_demo1');
  try {
    const insufficientGiftError = waitEvent(s1, 'room:error');
    const noGiftBroadcast = waitEvent(s2, 'room:gift', 700);
    const noWalletUpdate = waitEvent(s1, 'user:wallet', 700);
    s1.emit('room:gift', { roomId, gift: '🌹' });
    const error = await insufficientGiftError;
    let broadcastBlocked = false;
    let walletUpdateBlocked = false;
    try { await noGiftBroadcast; } catch { broadcastBlocked = true; }
    try { await noWalletUpdate; } catch { walletUpdateBlocked = true; }
    ok(error.message.includes('Không đủ Xu') && broadcastBlocked && walletUpdateBlocked &&
        db.prepare('SELECT coins FROM users WHERE id = ?').get('u_demo1').coins === 0,
        'thiếu Xu thì server từ chối quà, không broadcast và không đổi ví');
  } finally {
    db.prepare('UPDATE users SET coins = ? WHERE id = ?')
      .run(balanceBeforeInsufficientTest, 'u_demo1');
  }

  const leftP = waitEvent(s1, 'room:presence');
  s2.emit('room:leave', { roomId });
  const left = await leftP;
  ok(left.members.length === 1, 'rời phòng -> cập nhật thành viên');

  console.log('== WebRTC signaling ==');
  // Gọi 1-1
  const inviteP = waitEvent(s2, 'call:invite');
  s1.emit('call:invite', { to: 'u_demo2', callId: 'call_t1', isVideo: true });
  const invite = await inviteP;
  ok(invite.callId === 'call_t1' && invite.isVideo === true &&
      invite.from === 'u_demo1', 'nhận lời mời gọi (tên + video flag)');

  const unauthorizedRtc = waitEvent(s2, 'rtc:signal', 700);
  s1.emit('rtc:signal', {
    to: 'u_demo2', callId: 'call_t1', data: { kind: 'offer', sdp: 'v=0' },
  });
  let preAcceptSignalBlocked = false;
  try {
    await unauthorizedRtc;
  } catch {
    preAcceptSignalBlocked = true;
  }
  const forgedReject = waitEvent(s1, 'call:rejected', 700);
  s1.emit('call:reject', { to: 'u_demo2', callId: 'call_t1' });
  let callerRejectBlocked = false;
  try {
    await forgedReject;
  } catch {
    callerRejectBlocked = true;
  }
  const rejectedP = waitEvent(s1, 'call:rejected');
  s2.emit('call:reject', { to: 'u_demo1', callId: 'call_t1' });
  const rejected = await rejectedP;
  ok(preAcceptSignalBlocked && callerRejectBlocked && rejected.callId === 'call_t1',
    'chặn RTC trước accept và chỉ người được mời được từ chối');

  const inviteP2 = waitEvent(s2, 'call:invite');
  s1.emit('call:invite', { to: 'u_demo2', callId: 'call_t2', isVideo: true });
  await inviteP2;
  const concurrentCallError = waitEvent(s1, 'call:error');
  s1.emit('call:invite', { to: 'u_demo2', callId: 'call_t3', isVideo: false });
  ok((await concurrentCallError).message.includes('bận'),
    'không cho người đang có cuộc gọi đổ chuông gọi thêm người khác');
  const acceptedP2 = waitEvent(s1, 'call:accepted');
  s2.emit('call:accept', { to: 'u_demo1', callId: 'call_t2' });
  await acceptedP2;
  const offerP = waitEvent(s2, 'rtc:signal');
  s1.emit('rtc:signal', {
    to: 'u_demo2', callId: 'call_t2', data: { kind: 'offer', sdp: 'v=0' },
  });
  const offer = await offerP;
  ok(offer.data.kind === 'offer' && offer.from === 'u_demo1', 'relay SDP offer sau accept');
  const answerP = waitEvent(s1, 'rtc:signal');
  s2.emit('rtc:signal', {
    to: 'u_demo1', callId: 'call_t2', data: { kind: 'answer', sdp: 'v=0' },
  });
  const answer = await answerP;
  ok(answer.data.kind === 'answer' && answer.from === 'u_demo2',
    'relay SDP answer theo chiều ngược lại');
  // Khi callee ngắt kết nối, chỉ caller còn socket hoạt động để nhận call:ended.
  const callerEnd = waitEvent(s1, 'call:ended');
  s2.disconnect();
  const callerWasNotified = await callerEnd;
  ok(callerWasNotified.callId === 'call_t2',
    'disconnect của một đầu đóng cuộc gọi và báo đầu còn lại');
  s2 = connect(token2);
  await waitEvent(s2, 'connect');

  // Gọi tới user OFFLINE -> báo lỗi
  const errP = waitEvent(s1, 'call:error');
  s1.emit('call:invite', { to: 'u_khong_ton_tai', callId: 'call_t3' });
  ok(!!(await errP).message, 'gọi user offline -> call:error');

  // Socket mới không thuộc phiên Soul trước khi reconnect, nên tạo phiên mới.
  const voiceQueued = waitEvent(s2, 'soul:queued');
  s2.emit('soul:queue', { mode: 'voice' });
  await voiceQueued;
  const voiceMatch1 = waitEvent(s1, 'soul:matched');
  const voiceMatch2 = waitEvent(s2, 'soul:matched');
  s1.emit('soul:queue', { mode: 'voice' });
  const [voiceSession1] = await Promise.all([voiceMatch1, voiceMatch2]);

  // Voice Game: relay tín hiệu RTC chỉ trong phiên mới, đã ghép đúng socket.
  const soulSignalP = waitEvent(s2, 'soul:rtc:signal');
  s1.emit('soul:rtc:signal', {
    sessionId: voiceSession1.sessionId, data: { kind: 'ice', candidate: 'cand' },
  });
  const soulSignal = await soulSignalP;
  ok(soulSignal.data.kind === 'ice', 'relay ICE trong phiên Soul (voice)');

  console.log('== Nút tim sau 5 tin + thích hai chiều ==');
  const queuedHeart = waitEvent(s2, 'soul:queued');
  s2.emit('soul:queue');
  await queuedHeart;
  const heartMatchA = waitEvent(s1, 'soul:matched');
  const heartMatchB = waitEvent(s2, 'soul:matched');
  s1.emit('soul:queue');
  const [heartMatch1, heartMatch2] = await Promise.all([heartMatchA, heartMatchB]);
  const heartSessionId = heartMatch1.sessionId;
  const heartAvailable1 = waitEvent(s1, 'soul:heart-available', 12000);
  const heartAvailable2 = waitEvent(s2, 'soul:heart-available', 12000);
  for (let i = 0; i < 5; i++) {
    const sender = i % 2 === 0 ? s1 : s2;
    const receiver = i % 2 === 0 ? s2 : s1;
    const delivered = waitEvent(receiver, 'soul:message');
    sender.emit('soul:message', {
      sessionId: heartSessionId,
      content: `Tin test ${i + 1}`,
    });
    await delivered;
  }
  const [heartReady1, heartReady2] = await Promise.all([
    heartAvailable1,
    heartAvailable2,
  ]);
  ok(heartMatch1.sessionId === heartMatch2.sessionId &&
      heartReady1.reason === 'messages' && heartReady1.messageCount === 5 &&
      heartReady2.reason === 'messages',
      'cả hai nhận mở tim đúng khi tổng số tin đạt 5');

  const firstLikeSent = waitEvent(s1, 'soul:like:sent');
  const partnerLiked = waitEvent(s2, 'soul:like:received');
  s1.emit('soul:like', { sessionId: heartSessionId });
  await Promise.all([firstLikeSent, partnerLiked]);
  ok(true, 'thích một chiều báo đối phương và xác nhận người gửi');

  const mutualA = waitEvent(s1, 'soul:mutual-like');
  const mutualB = waitEvent(s2, 'soul:mutual-like');
  const secondLikeSent = waitEvent(s2, 'soul:like:sent');
  s2.emit('soul:like', { sessionId: heartSessionId });
  const [mutual1, mutual2] = await Promise.all([mutualA, mutualB]);
  await secondLikeSent;
  const deniedSoulMessage = waitEvent(s1, 'soul:message', 700);
  s2.emit('soul:message', {
    sessionId: heartSessionId,
    content: 'Không gửi qua Soul sau khi đã kết đôi',
  });
  let soulMessageRejected = false;
  try {
    await deniedSoulMessage;
  } catch {
    soulMessageRejected = true;
  }
  const normalChat = await fetch(
    `${BASE}/api/conversations/${mutual1.conversationId}/messages`,
    {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        authorization: `Bearer ${token2}`,
      },
      body: JSON.stringify({ content: 'Chat 1-1 không giới hạn' }),
    },
  );
  ok(mutual1.conversationId === mutual2.conversationId &&
      mutual1.user?.name && mutual2.user?.name &&
      soulMessageRejected && normalChat.status === 201,
      'đôi bên thích -> hiện danh tính và chuyển sang chat 1-1');
  s1.emit('soul:leave');
  s2.emit('soul:leave');

  console.log('== Nút tim tự mở sau 10 giây ==');
  const timerQueued = waitEvent(s2, 'soul:queued');
  s2.emit('soul:queue');
  await timerQueued;
  const timerMatchA = waitEvent(s1, 'soul:matched');
  const timerMatchB = waitEvent(s2, 'soul:matched');
  s1.emit('soul:queue');
  const [timerMatch1, timerMatch2] = await Promise.all([timerMatchA, timerMatchB]);
  const [timeHeart1, timeHeart2] = await Promise.all([
    waitEvent(s1, 'soul:heart-available', 12000),
    waitEvent(s2, 'soul:heart-available', 12000),
  ]);
  ok(timerMatch1.sessionId === timerMatch2.sessionId &&
      timeHeart1.reason === 'time' && timeHeart2.reason === 'time',
      'timed trigger đồng bộ cho cả hai client sau 10 giây');
  s1.emit('soul:leave');
  s2.emit('soul:leave');

  // Mic phòng: join -> peers + joined + relay signal
  s2.emit('room:join', { roomId });
  await wait(200);
  const s2PeersP = waitEvent(s2, 'room:rtc:peers');
  s2.emit('room:rtc:join', { roomId }); // demo2 bật mic trước
  await s2PeersP;
  const peersP = waitEvent(s1, 'room:rtc:peers');
  const joinedP = waitEvent(s2, 'room:rtc:joined');
  s1.emit('room:rtc:join', { roomId }); // demo1 bật mic sau -> thấy demo2
  const [peers, joined] = await Promise.all([peersP, joinedP]);
  ok(peers.peers.some((p) => p.userId === 'u_demo2'),
      'người mic sau nhận danh sách peers đang mic');
  ok(joined.peer.userId === 'u_demo1', 'người đang mic nhận thông tin người vào');

  const roomSignalP = waitEvent(s2, 'room:rtc:signal');
  s1.emit('room:rtc:signal', {
    roomId, to: 'u_demo2', data: { kind: 'offer', sdp: 'v=0' },
  });
  const roomSignal = await roomSignalP;
  ok(roomSignal.from === 'u_demo1' && roomSignal.data.kind === 'offer',
      'relay SDP trong phòng');

  s1.emit('room:rtc:leave', { roomId });
  s1.disconnect();
  s2.disconnect();

  console.log(`\n>>> ${passed} passed, ${failed} failed`);
  process.exit(failed ? 1 : 0);
}

main().catch((e) => { console.error('LỖI:', e.message); process.exit(1); });
