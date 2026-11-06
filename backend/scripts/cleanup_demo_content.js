// Xoá nội dung mẫu từng được seed ở bản cũ (bài viết, like, bình luận, phòng).
// Chạy một lần sau khi nâng cấp: node scripts/cleanup_demo_content.js
// An toàn khi chạy nhiều lần: chỉ đụng tới các bản ghi có id seed cũ.
import db from '../src/db.js';

const posts = db.prepare("DELETE FROM posts WHERE id LIKE 'p_seed%'").run();
const rooms = db.prepare("DELETE FROM rooms WHERE id IN ('r_1','r_2','r_3')").run();

console.log(`[cleanup] Đã xoá ${posts.changes} bài viết mẫu và ${rooms.changes} phòng mẫu.`);
console.log('[cleanup] Bài viết, bình luận, like và phòng còn lại đều do người dùng tạo.');
