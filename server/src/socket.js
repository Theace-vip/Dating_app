import { Server } from 'socket.io';
import db, { getUser, publicUser, ensureConversation, addFriendship } from './db.js';
import { verifyAccessToken, randomId } from './security.js';
import { APP_CATALOG, chargeRoomGift } from './catalog.js';

let io = null;
const presence = new Map();     // userId -> Set<socketId>
const roomMembers = new Map();  // roomId -> Set<userId>
const queue = [];               // hàng đợi Soul Game: [{ socketId, userId, mode }]
const soulSessions = new Map(); // sessionId -> { a, b, revealed, room, mode }
const rtcRoomPeers = new Map();  // roomId -> Set<userId> đang bật mic WebRTC
const activeCalls = new Map(); // callId -> caller/callee + trạng thái signaling

export function isOnline(userId) {
  const s = presence.get(userId);
  return !!s && s.size > 0;
}

export function roomPresenceList(roomId) {
  const members = roomMembers.get(roomId);
  if (!members) return [];
  return [...members].map((id) => {
    const u = getUser(id);
    return u ? { userId: u.id, name: u.name, avatar: u.avatar } : null;
  }).filter(Boolean);
}

export function emitToUser(userId, event, payload) {
  io?.to(`user:${userId}`).emit(event, payload);
}

export function getIO() {
  return io;
}

function profileForStranger(userId) {
  const u = getUser(userId);
  if (!u) return null;
  // Ẩn danh: không gửi id/tên/email cho tới khi hai bên đồng ý hiện danh tính
  return { avatar: u.avatar, age: u.age, gender: u.gender };
}

function removeFromQueue(socketId) {
  const i = queue.findIndex((q) => q.socketId === socketId);
  if (i >= 0) queue.splice(i, 1);
}

function isRoomMember(socket, roomId) {
  return socket.data.rooms?.has(roomId) === true &&
    socket.rooms.has(`room:${roomId}`);
}

function leaveSoul(socket) {
  const sessionId = socket.data.soulSessionId;
  if (!sessionId) return;
  const session = soulSessions.get(sessionId);
  if (session) {
    clearTimeout(session.heartTimer);
    clearTimeout(session.gameTimer);
  }
  soulSessions.delete(sessionId);
  socket.data.soulSessionId = null;
  if (!session) return;
  socket.to(session.room).emit('soul:partner-left', { sessionId });
}

function makeSoulHeartAvailable(sessionId, session, reason) {
  if (soulSessions.get(sessionId) !== session || session.completed ||
      session.revealed || session.heartAvailable) return;
  clearTimeout(session.heartTimer);
  session.heartAvailable = true;
  io.to(session.room).emit('soul:heart-available', {
    sessionId,
    reason,
    messageCount: session.messageCount,
  });
}

// Server giữ đồng hồ trận; client chỉ hiển thị phần thời gian còn lại.
function scheduleSoulExpiry(sessionId, session, durationSeconds) {
  clearTimeout(session.gameTimer);
  session.endsAt = Date.now() + durationSeconds * 1000;
  session.timeExpired = false;
  session.gameTimer = setTimeout(() => {
    // Bỏ qua timer cũ nếu phiên đã rời hàng đợi, hiện danh tính hoặc đã hết giờ.
    if (soulSessions.get(sessionId) !== session || session.completed ||
        session.timeExpired) return;

    announceSoulExpiry(sessionId, session);
  }, durationSeconds * 1000);
}

// Chỉ thành viên của đúng phiên mới được báo hết giờ; client không thể rút ngắn giờ chơi.
export function canExpireSoulSession(session, socketId, now = Date.now()) {
  const isMember = session &&
    (session.a.socketId === socketId || session.b.socketId === socketId);
  return !!session && !!isMember && !session.completed && !session.timeExpired &&
    Number.isFinite(session.endsAt) && now >= session.endsAt;
}

// Đánh dấu hết giờ chỉ khi mốc kết thúc do server cấp đã qua.
function markSoulSessionExpired(session, now = Date.now()) {
  if (!session || !canExpireSoulSession(session, session.a.socketId, now)) {
    return false;
  }
  clearTimeout(session.gameTimer);
  session.timeExpired = true;
  session.endsAt = now;
  return true;
}

// Một chỗ phát event hết giờ dùng chung cho timer và thao tác xác nhận của client.
function announceSoulExpiry(sessionId, session, now = Date.now()) {
  if (!markSoulSessionExpired(session, now)) return false;
  io.to(session.room).emit('soul:time-ended', {
    sessionId,
    endsAt: new Date(session.endsAt).toISOString(),
  });
  return true;
}

function expireSoulSession(socket, sessionId) {
  const session = soulSessions.get(sessionId);
  const isMember = session &&
    (session.a.socketId === socket.id || session.b.socketId === socket.id);
  if (!isMember) return;
  announceSoulExpiry(sessionId, session);
}

export function initSocket(httpServer) {
  io = new Server(httpServer, {
    cors: { origin: '*' },
    maxHttpBufferSize: 64 * 1024, // chặn payload quá lớn
  });

  // Xác thực bằng access token (header auth hoặc query token)
  io.use((socket, next) => {
    const token =
      socket.handshake.auth?.token ||
      socket.handshake.query?.token ||
      (socket.handshake.headers.authorization || '').replace(/^Bearer /, '');
    try {
      const payload = verifyAccessToken(String(token));
      socket.data.userId = payload.sub;
      next();
    } catch {
      next(new Error('unauthorized'));
    }
  });

  io.on('connection', (socket) => {
    const userId = socket.data.userId;

    // ===== Presence =====
    if (!presence.has(userId)) presence.set(userId, new Set());
    presence.get(userId).add(socket.id);
    socket.join(`user:${userId}`);
    if (presence.get(userId).size === 1) io.emit('presence:changed', { userId, online: true });

    // ===== Soul Game: queue + matching =====
    socket.on('soul:queue', ({ mode = 'text' } = {}) => {
      // Chỉ nhận hai chế độ đã định nghĩa; không để client tự chọn luật chơi khác.
      if (mode !== 'text' && mode !== 'voice') {
        socket.emit('soul:queue:error', { message: 'Chế độ ghép đôi không hợp lệ' });
        return;
      }
      removeFromQueue(socket.id);
      if (socket.data.soulSessionId) leaveSoul(socket);

      // Không ghép chính mình; chỉ ghép cùng chế độ (text vs voice)
      const partner = queue.find(
          (q) => q.userId !== userId && q.mode === mode);
      if (partner) {
        removeFromQueue(partner.socketId);
        const sessionId = randomId('soul');
        const room = `soul:${sessionId}`;
        const pSock = io.sockets.sockets.get(partner.socketId);
        for (const s of [socket, pSock]) {
          if (s) { s.data.soulSessionId = sessionId; s.join(room); }
        }
        const session = {
          a: { socketId: socket.id, userId },
          b: { socketId: partner.socketId, userId: partner.userId },
          revealed: false,
          completed: false,
          room,
          mode,
          startedAt: Date.now(),
          messageCount: 0,
          heartAvailable: false,
          timeExpired: false,
          likes: new Set(),
        };
        soulSessions.set(sessionId, session);
        const durationSeconds = mode === 'voice'
          ? APP_CATALOG.matching.voiceSeconds
          : APP_CATALOG.matching.textSeconds;
        scheduleSoulExpiry(sessionId, session, durationSeconds);
        if (mode === 'text' && APP_CATALOG.matching.heartUnlockAfterSeconds > 0) {
          session.heartTimer = setTimeout(
            () => makeSoulHeartAvailable(sessionId, session, 'time'),
            APP_CATALOG.matching.heartUnlockAfterSeconds * 1000,
          );
        }
        // Người ghép sau (a) sẽ là bên khởi tạo kết nối WebRTC (voice mode)
        if (pSock) {
          pSock.emit('soul:matched', {
            sessionId, mode, initiator: false, durationSeconds,
            endsAt: new Date(session.endsAt).toISOString(),
            stranger: profileForStranger(userId),
          });
        }
        socket.emit('soul:matched', {
          sessionId, mode, initiator: true, durationSeconds,
          endsAt: new Date(session.endsAt).toISOString(),
          stranger: profileForStranger(partner.userId),
        });
      } else {
        queue.push({ socketId: socket.id, userId, mode });
        socket.emit('soul:queued', {});
      }
    });

    // Mỗi thao tác gameplay đều xác thực thành viên và trạng thái trên backend.
    socket.on('soul:heart:unlock', ({ sessionId } = {}) => {
      const session = soulSessions.get(sessionId);
      const isMember = session &&
        (session.a.socketId === socket.id || session.b.socketId === socket.id);
      if (!session || session.mode !== 'text' || !isMember || session.completed ||
          session.timeExpired || !session.endsAt ||
          Date.now() < session.startedAt + APP_CATALOG.matching.heartUnlockAfterSeconds * 1000) {
        return;
      }
      makeSoulHeartAvailable(sessionId, session, 'time');
    });

    socket.on('soul:message', ({ sessionId, content } = {}) => {
      const session = soulSessions.get(sessionId);
      if (!session || !session.room || session.completed || session.timeExpired) return;
      const text = String(content || '').trim().slice(0, 2000);
      if (!text) return;
      const isMember =
        session.a.socketId === socket.id || session.b.socketId === socket.id;
      if (!isMember) return;
      socket.to(session.room).emit('soul:message', {
        sessionId,
        content: text,
        createdAt: new Date().toISOString(),
      });
      session.messageCount++;
      if (session.mode === 'text' && session.messageCount >= 5) {
        makeSoulHeartAvailable(sessionId, session, 'messages');
      }
    });

    socket.on('soul:reveal', ({ sessionId } = {}) => {
      const session = soulSessions.get(sessionId);
      const isA = session?.a.socketId === socket.id;
      const isB = session?.b.socketId === socket.id;
      if (!session || (!isA && !isB) || session.completed) return;

      session.revealed = true;
      session.completed = true;
      clearTimeout(session.heartTimer);
      clearTimeout(session.gameTimer);
      const userA = getUser(session.a.userId);
      const userB = getUser(session.b.userId);
      if (!userA || !userB) return;
      const conversation = ensureConversation(session.a.userId, session.b.userId);
      addFriendship(session.a.userId, session.b.userId);
      io.sockets.sockets.get(session.a.socketId)?.emit('soul:revealed', {
        sessionId,
        conversationId: conversation.id,
        user: publicUser(userB),
      });
      io.sockets.sockets.get(session.b.socketId)?.emit('soul:revealed', {
        sessionId,
        conversationId: conversation.id,
        user: publicUser(userA),
      });
    });

    socket.on('soul:like', ({ sessionId } = {}) => {
      const session = soulSessions.get(sessionId);
      const isA = session?.a.socketId === socket.id;
      const isB = session?.b.socketId === socket.id;
      if (!session || session.mode !== 'text' || (!isA && !isB) ||
          session.completed || session.timeExpired) return;
      if (!session.heartAvailable) {
        socket.emit('soul:like:error', { sessionId, reason: 'not_available' });
        return;
      }

      if (session.likes.has(userId)) {
        socket.emit('soul:like:sent', { sessionId, alreadyLiked: true });
        return;
      }
      session.likes.add(userId);
      socket.emit('soul:like:sent', { sessionId });
      const partnerSocketId = isA ? session.b.socketId : session.a.socketId;
      io.sockets.sockets.get(partnerSocketId)?.emit('soul:like:received', {
        sessionId,
      });
      if (session.likes.size < 2) return;

      session.completed = true;
      session.revealed = true;
      clearTimeout(session.heartTimer);
      clearTimeout(session.gameTimer);
      const userA = getUser(session.a.userId);
      const userB = getUser(session.b.userId);
      const conversation = ensureConversation(session.a.userId, session.b.userId);
      addFriendship(session.a.userId, session.b.userId);
      io.sockets.sockets.get(session.a.socketId)?.emit('soul:mutual-like', {
        sessionId,
        conversationId: conversation.id,
        user: publicUser(userB),
      });
      io.sockets.sockets.get(session.b.socketId)?.emit('soul:mutual-like', {
        sessionId,
        conversationId: conversation.id,
        user: publicUser(userA),
      });
    });

    // Client có thể xin kết thúc sớm; chỉ server mới đổi session sang trạng thái hết giờ.
    socket.on('soul:finish', ({ sessionId } = {}) => {
      expireSoulSession(socket, sessionId);
    });

    socket.on('soul:continue', ({ sessionId } = {}) => {
      const session = soulSessions.get(sessionId);
      const isMember = session &&
        (session.a.socketId === socket.id || session.b.socketId === socket.id);
      if (!session || session.revealed || !isMember || !session.timeExpired) {
        socket.emit('soul:continue:error', { sessionId });
        return;
      }
      const durationSeconds = session.mode === 'voice'
        ? APP_CATALOG.matching.voiceSeconds
        : APP_CATALOG.matching.textSeconds;
      session.continued = true;
      if (session.mode === 'text' && !session.heartAvailable) {
        session.heartTimer = setTimeout(
          () => makeSoulHeartAvailable(sessionId, session, 'time'),
          APP_CATALOG.matching.heartUnlockAfterSeconds * 1000,
        );
      }
      scheduleSoulExpiry(sessionId, session, durationSeconds);
      io.to(session.room).emit('soul:continued', {
        sessionId,
        durationSeconds,
        endsAt: new Date(session.endsAt).toISOString(),
      });
    });

    socket.on('soul:leave', () => {
      removeFromQueue(socket.id);
      leaveSoul(socket);
    });

    // ===== WebRTC signaling: Voice Game (1-1 trong phiên Soul) =====
    socket.on('soul:rtc:signal', ({ sessionId, data } = {}) => {
      const session = soulSessions.get(sessionId);
      if (!session) return;
      const isA = session.a.socketId === socket.id;
      const isB = session.b.socketId === socket.id;
      if (!isA && !isB) return;
      const otherId = isA ? session.b.socketId : session.a.socketId;
      io.sockets.sockets.get(otherId)?.emit('soul:rtc:signal', {
        sessionId, from: userId, data,
      });
    });

    // ===== WebRTC signaling: gọi thoại/video 1-1 =====
    // Chỉ hai user của lời mời hợp lệ mới được accept/reject, hangup hoặc trao đổi SDP/ICE.
    // Lưu trạng thái cuộc gọi trong memory để xác thực cặp caller/callee trước signaling.
    socket.on('call:invite', ({ to, callId, isVideo } = {}) => {
      if (typeof to !== 'string' || typeof callId !== 'string' ||
          to === userId || !getUser(to) || activeCalls.has(callId) ||
          [...activeCalls.values()].some((call) =>
            call.callerId === userId || call.calleeId === userId)) {
        socket.emit('call:error', { callId, message: 'Thông tin cuộc gọi không hợp lệ hoặc đang bận' });
        return;
      }
      const busy = [...activeCalls.values()].some((call) =>
        call.calleeId === to || call.callerId === to);
      if (busy) {
        socket.emit('call:error', { callId, message: 'Đối phương đang có cuộc gọi khác' });
        return;
      }
      if (!isOnline(to)) {
        socket.emit('call:error', {
          callId, message: 'Đối phương không trực tuyến',
        });
        return;
      }
      const caller = getUser(userId);
      // Lưu hai đầu cuộc gọi để chỉ đúng người nhận được accept/reject/signaling.
      const socketsForCallee = presence.get(to) || new Set();
      const call = {
        callerId: userId,
        calleeId: to,
        callerSocketId: socket.id,
        callerSocketIds: new Set([socket.id]),
        calleeSocketId: null,
        calleeSocketIds: new Set(),
        status: 'ringing',
        timeout: setTimeout(() => {
          if (activeCalls.get(callId) !== call || call.status !== 'ringing') return;
          activeCalls.delete(callId);
          for (const callerSocketId of call.callerSocketIds) {
            io.sockets.sockets.get(callerSocketId)?.emit('call:error', {
              callId,
              message: 'Không có ai bắt máy',
            });
          }
          for (const calleeSocketId of socketsForCallee) {
            io.sockets.sockets.get(calleeSocketId)?.emit('call:ended', {
              callId,
              reason: 'timeout',
            });
          }
        }, APP_CATALOG.call.ringingTimeoutSeconds * 1000),
      };
      activeCalls.set(callId, call);
      for (const calleeSocketId of socketsForCallee) {
        io.sockets.sockets.get(calleeSocketId)?.emit('call:invite', {
          callId,
          from: userId,
          fromName: caller?.name,
          fromAvatar: caller?.avatar,
          isVideo: !!isVideo,
        });
      }
    });
    socket.on('call:accept', ({ to, callId } = {}) => {
      const call = activeCalls.get(callId);
      if (!call || call.status !== 'ringing' || call.calleeId !== userId ||
          call.callerId !== to) return;
      call.calleeSocketIds = new Set([socket.id]);
      const userAlreadyInCall = [...activeCalls.entries()].some(([activeId, active]) =>
        activeId !== callId && active.status === 'accepted' &&
        (active.callerId === userId || active.calleeId === userId));
      if (userAlreadyInCall) {
        clearTimeout(call.timeout);
        activeCalls.delete(callId);
        socket.emit('call:error', { callId, message: 'Bạn đang tham gia cuộc gọi khác' });
        for (const callerSocketId of call.callerSocketIds) {
          io.sockets.sockets.get(callerSocketId)?.emit('call:rejected', {
            callId,
            by: userId,
          });
        }
        return;
      }
      clearTimeout(call.timeout);
      call.status = 'accepted';
      call.calleeSocketId = socket.id;
      for (const callerSocketId of call.callerSocketIds) {
        io.sockets.sockets.get(callerSocketId)?.emit('call:accepted', {
          callId,
          by: userId,
        });
      }
    });
    socket.on('call:reject', ({ to, callId } = {}) => {
      const call = activeCalls.get(callId);
      if (!call || call.status !== 'ringing' || call.calleeId !== userId ||
          call.callerId !== to) return;
      clearTimeout(call.timeout);
      activeCalls.delete(callId);
      for (const callerSocketId of call.callerSocketIds) {
        io.sockets.sockets.get(callerSocketId)?.emit('call:rejected', {
          callId,
          by: userId,
        });
      }
    });
    socket.on('call:hangup', ({ to, callId } = {}) => {
      const call = activeCalls.get(callId);
      if (!call || ![call.callerId, call.calleeId].includes(userId) ||
          ![call.callerId, call.calleeId].includes(to) || to === userId) return;
      clearTimeout(call.timeout);
      activeCalls.delete(callId);
      emitToUser(to, 'call:ended', { callId, by: userId });
    });
    // Chuyển tiếp SDP/ICE chỉ sau accept; media thực tế đi trực tiếp qua WebRTC.
    socket.on('rtc:signal', ({ to, callId, data } = {}) => {
      const call = activeCalls.get(callId);
      if (!call || call.status !== 'accepted' ||
          ![call.callerId, call.calleeId].includes(userId) ||
          ![call.callerId, call.calleeId].includes(to) || to === userId ||
          !data || typeof data !== 'object') return;
      const targetSockets = userId === call.callerId
          ? call.calleeSocketIds : call.callerSocketIds;
      for (const targetSocketId of targetSockets) {
        io.sockets.sockets.get(targetSocketId)?.emit('rtc:signal', {
          callId,
          from: userId,
          data,
        });
      }
    });
    socket.on('disconnecting', () => {
      for (const [callId, call] of activeCalls) {
        call.callerSocketIds.delete(socket.id);
        call.calleeSocketIds.delete(socket.id);
        const wasCaller = call.callerId === userId;
        const wasCallee = call.calleeId === userId;
        if (!wasCaller && !wasCallee) continue;
        const sideIsStillConnected = wasCaller
            ? call.callerSocketIds.size > 0
            : call.calleeSocketIds.size > 0;
        if (sideIsStillConnected) continue;
        clearTimeout(call.timeout);
        activeCalls.delete(callId);
        const otherUserId = wasCaller ? call.calleeId : call.callerId;
        emitToUser(otherUserId, 'call:ended', { callId, by: userId });
      }
    });

    // ===== WebRTC signaling: mic trong phòng tiệc (mesh) =====
    socket.on('room:rtc:join', ({ roomId } = {}) => {
      if (typeof roomId !== 'string' || !isRoomMember(socket, roomId)) return;
      const existing = [...(rtcRoomPeers.get(roomId) || [])]
        .filter((id) => id !== userId)
        .map((id) => {
          const u = getUser(id);
          return u ? { userId: u.id, name: u.name, avatar: u.avatar } : null;
        })
        .filter(Boolean);
      if (!rtcRoomPeers.has(roomId)) rtcRoomPeers.set(roomId, new Set());
      rtcRoomPeers.get(roomId).add(userId);
      // Người vào sau trả lời offer; người đang ở phòng sẽ tạo offer
      socket.emit('room:rtc:peers', { roomId, peers: existing });
      const u = getUser(userId);
      socket.to(`room:${roomId}`).emit('room:rtc:joined', {
        roomId,
        peer: { userId, name: u?.name, avatar: u?.avatar },
      });
    });

    socket.on('room:rtc:leave', ({ roomId } = {}) => {
      if (typeof roomId !== 'string' || !isRoomMember(socket, roomId)) return;
      removeRtcPeer(roomId, userId);
      socket.to(`room:${roomId}`).emit('room:rtc:left', { roomId, userId });
    });

    socket.on('room:rtc:signal', ({ roomId, to, data } = {}) => {
      if (typeof roomId !== 'string' || typeof to !== 'string' ||
          !isRoomMember(socket, roomId) || !rtcRoomPeers.get(roomId)?.has(userId) ||
          !rtcRoomPeers.get(roomId)?.has(to)) return;
      for (const s of io.sockets.sockets.values()) {
        if (s.data.userId === to && isRoomMember(s, roomId)) {
          s.emit('room:rtc:signal', { roomId, from: userId, data });
          break;
        }
      }
    });

    // ===== Chat: đang gõ =====
    socket.on('chat:typing', ({ conversationId } = {}) => {
      if (typeof conversationId !== 'string') return;
      const c = db.prepare('SELECT * FROM conversations WHERE id = ?')
        .get(conversationId);
      if (!c || (c.user_a !== userId && c.user_b !== userId)) return;
      const partner = c.user_a === userId ? c.user_b : c.user_a;
      emitToUser(partner, 'chat:typing', { conversationId, from: userId });
    });

    // ===== Phòng tiệc =====
    socket.on('room:join', ({ roomId } = {}) => {
      if (typeof roomId !== 'string') return;
      if (!db.prepare('SELECT 1 FROM rooms WHERE id = ?').get(roomId)) {
        socket.emit('room:error', { message: 'Phòng không tồn tại' });
        return;
      }
      socket.join(`room:${roomId}`);
      socket.data.rooms ??= new Set();
      socket.data.rooms.add(roomId);
      if (!roomMembers.has(roomId)) roomMembers.set(roomId, new Set());
      roomMembers.get(roomId).add(userId);
      io.to(`room:${roomId}`).emit('room:presence', {
        roomId,
        members: roomPresenceList(roomId),
      });
    });

    socket.on('room:leave', ({ roomId } = {}) => {
      if (typeof roomId !== 'string') return;
      leaveRoom(socket, roomId);
    });

    socket.on('room:message', ({ roomId, content } = {}) => {
      if (typeof roomId !== 'string' || !isRoomMember(socket, roomId)) return;
      const text = String(content || '').trim().slice(0, 2000);
      if (!text) return;
      const u = getUser(userId);
      if (!u) return;
      const id = randomId('rm');
      const createdAt = new Date().toISOString();
      db.prepare('INSERT INTO room_messages (id, room_id, sender_id, content, created_at) VALUES (?, ?, ?, ?, ?)')
        .run(id, roomId, userId, text, createdAt);
      io.to(`room:${roomId}`).emit('room:message', {
        roomId,
        message: {
          id, roomId, senderId: userId, senderName: u.name,
          senderAvatar: u.avatar, content: text, createdAt,
        },
      });
    });

    socket.on('room:heart', ({ roomId } = {}) => {
      if (typeof roomId !== 'string' || !isRoomMember(socket, roomId)) return;
      const u = getUser(userId);
      if (!u) return;
      socket.to(`room:${roomId}`).emit('room:heart', {
        roomId,
        from: { name: u.name, avatar: u.avatar },
      });
    });

    socket.on('room:gift', ({ roomId, gift } = {}) => {
      if (typeof roomId !== 'string' || !isRoomMember(socket, roomId)) return;
      const u = getUser(userId);
      if (!u) return;
      // ID quà và giá được đối chiếu với catalog phía server; không tin giá từ client.
      // Transaction đồng bộ của SQLite giữ debit atomic; chỉ báo quà khi trừ Xu thành công.
      const transaction = chargeRoomGift(db, userId, gift);
      if (!transaction.ok) {
        socket.emit('room:error', {
          message: transaction.reason === 'insufficient_coins'
              ? 'Không đủ Xu để gửi quà'
              : transaction.reason === 'invalid_gift'
                  ? 'Quà không tồn tại hoặc thao tác không hợp lệ'
                  : 'Không tìm thấy tài khoản gửi quà',
        });
        return;
      }
      socket.emit('user:wallet', {
        coins: transaction.coins,
        diamonds: transaction.diamonds,
      });
      socket.to(`room:${roomId}`).emit('room:gift', {
        roomId,
        gift: transaction.gift.emoji,
        from: { name: u.name, avatar: u.avatar },
      });
    });

    // ===== Ngắt kết nối =====
    socket.on('disconnect', () => {
      removeFromQueue(socket.id);
      const wasInSession = socket.data.soulSessionId;
      leaveSoul(socket);

      const set = presence.get(userId);
      if (set) {
        set.delete(socket.id);
        if (set.size === 0) {
          presence.delete(userId);
          io.emit('presence:changed', { userId, online: false });
        }
      }
      for (const roomId of socket.data.rooms || []) {
        leaveRoom(socket, roomId, false);
      }
      if (wasInSession) {
        // partner-left đã được leaveSoul phát đi
      }
    });
  });

  return io;
}

function removeRtcPeer(roomId, userId) {
  const peers = rtcRoomPeers.get(roomId);
  if (!peers) return;
  peers.delete(userId);
  if (peers.size === 0) rtcRoomPeers.delete(roomId);
}

function leaveRoom(socket, roomId, notify = true) {
  socket.leave(`room:${roomId}`);
  socket.data.rooms?.delete(roomId);
  // Room voice membership is per user: clean it only after the last socket leaves.
  const stillHere = [...(io.sockets.sockets.values())]
    .some((s) => s.data.userId === socket.data.userId && isRoomMember(s, roomId));
  if (!stillHere && rtcRoomPeers.get(roomId)?.has(socket.data.userId)) {
    removeRtcPeer(roomId, socket.data.userId);
    io.to(`room:${roomId}`).emit('room:rtc:left', {
      roomId, userId: socket.data.userId,
    });
  }
  const members = roomMembers.get(roomId);
  if (members) {
    // Chỉ xóa khi user không còn socket nào trong phòng này
    if (!stillHere) members.delete(socket.data.userId);
    if (members.size === 0) roomMembers.delete(roomId);
  }
  if (notify) {
    io.to(`room:${roomId}`).emit('room:presence', {
      roomId,
      members: roomPresenceList(roomId),
    });
  }
}
