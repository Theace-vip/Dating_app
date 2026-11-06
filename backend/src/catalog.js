// Danh mục này là nguồn sự thật phía server; ứng dụng chỉ tải về để hiển thị.
// Deep-freeze tránh module khác vô tình thay đổi bảng giá/catalog trong runtime.
function deepFreeze(value) {
  if (value && typeof value === 'object' && !Object.isFrozen(value)) {
    Object.freeze(value);
    for (const child of Object.values(value)) deepFreeze(child);
  }
  return value;
}
export const APP_CATALOG = deepFreeze({
  profile: {
    avatars: [
      '🦊', '🐱', '🐰', '🐻', '🐼', '🐯', '🦁', '🐸',
      '🐵', '🐶', '🐺', '🦄', '🐲', '🐙', '🦋', '🌟',
    ],
    interests: [
      'Âm nhạc', 'Du lịch', 'Anime', 'Game', 'Thể thao', 'Nấu ăn',
      'Đọc sách', 'Điện ảnh', 'Nhiếp ảnh', 'Thú cưng', 'Yoga', 'Kinh doanh',
      'Hội họa', 'Khiêu vũ', 'Công nghệ', 'Thiên nhiên',
    ],
  },
  rooms: {
    // Client gửi id quà, nhưng giá và quyền trừ Xu luôn được server quyết định.
    // Mỗi quà là một animation SVGA phát trong phòng (không còn emoji tĩnh).
    // Asset SVGA thuộc YY Inc., chỉ dùng cho mục đích học tập — xem assets/svga/NOTICE.md.
    gifts: [
      { id: 'rose', name: 'Hoa hồng', svga: 'assets/svga/rose.svga', cost: 10 },
      { id: 'heartbeat', name: 'Nhịp tim', svga: 'assets/svga/heartbeat.svga', cost: 20 },
      { id: 'twitter', name: 'Trái tim bay', svga: 'assets/svga/TwitterHeart.svga', cost: 30 },
      { id: 'angel', name: 'Thiên thần', svga: 'assets/svga/angel.svga', cost: 100 },
      { id: 'halloween', name: 'Bí ngô', svga: 'assets/svga/halloween.svga', cost: 150 },
      // Không dùng Rocket.svga: file trong repo mẫu là SVGA 1.0 (ZIP), player chỉ đọc 2.0.
      { id: 'kingset', name: 'Vương miện', svga: 'assets/svga/kingset.svga', cost: 400 },
      { id: 'posche', name: 'Siêu xe', svga: 'assets/svga/posche.svga', cost: 800 },
    ],
  },
  wallet: {
    // Đây là bảng giá hiển thị; mua Xu chưa bật khi chưa tích hợp cổng thanh toán.
    purchasesEnabled: false,
    coinPackages: [
      { id: 'coins_50', coins: 50, priceVnd: 20000, priceLabel: '20.000đ' },
      { id: 'coins_300', coins: 300, priceVnd: 99000, priceLabel: '99.000đ' },
      { id: 'coins_1000', coins: 1000, priceVnd: 299000, priceLabel: '299.000đ' },
    ],
  },
  call: {
    // Cuộc gọi đổ chuông có hạn; server tự giải phóng trạng thái nếu không ai trả lời.
    ringingTimeoutSeconds: 45,
  },
  matching: {
    // Backend là nguồn cấu hình thời lượng; app chỉ dùng để vẽ đồng hồ đếm ngược.
    textSeconds: 180,
    voiceSeconds: 90,
    heartUnlockAfterSeconds: 10,
  },
  vip: {
    // Không cho ứng dụng tự cấp VIP; chỉ mở đăng ký sau khi có xác minh thanh toán.
    purchasesEnabled: false,
    plan: {
      id: 'vip_monthly',
      title: 'VIP 1 tháng',
      priceVnd: 79000,
      priceLabel: '79.000đ',
      benefits: [
        { emoji: '👀', title: 'Xem ai thích mình' },
        { emoji: '💞', title: 'Tăng lượt ghép đôi' },
        { emoji: '👑', title: 'Khung avatar riêng' },
      ],
    },
  },
});

// Tạo câu trả lời chung để Socket.IO và kiểm thử dùng cùng một quy tắc giao dịch.
export function chargeRoomGift(database, userId, giftId) {
  const gift = APP_CATALOG.rooms.gifts.find((item) => item.id === giftId);
  if (!gift) return { ok: false, reason: 'invalid_gift' };

  // UPDATE có điều kiện giúp hai lần gửi đồng thời không thể làm số Xu âm.
  const result = database.prepare(
    'UPDATE users SET coins = coins - ? WHERE id = ? AND coins >= ?',
  ).run(gift.cost, userId, gift.cost);
  if (result.changes !== 1) {
    const user = database.prepare('SELECT coins FROM users WHERE id = ?').get(userId);
    return { ok: false, reason: user ? 'insufficient_coins' : 'user_not_found' };
  }

  const user = database.prepare('SELECT coins, diamonds FROM users WHERE id = ?').get(userId);
  return { ok: true, gift, coins: user.coins, diamonds: user.diamonds };
}
