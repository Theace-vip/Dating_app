import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';

// serverRoot = thư mục server/, dùng để đặt data/, uploads/, certs/ và config.
const __dirname = path.dirname(fileURLToPath(import.meta.url));
export const serverRoot = path.resolve(__dirname, '..');

// config.json không commit lên Git vì chứa JWT secret riêng của từng máy.
const configPath = path.join(serverRoot, 'config.json');

// Giá trị mặc định khi chưa có config: cổng 3000, access token 15 phút,
// refresh token 30 ngày. Secret sinh ngẫu nhiên ở lần chạy đầu tiên.
const defaults = {
  port: 3000,
  jwtSecret: crypto.randomBytes(48).toString('hex'),
  accessTokenTtlSec: 15 * 60,
  refreshTokenTtlSec: 30 * 24 * 60 * 60,
};

let config = { ...defaults };
if (fs.existsSync(configPath)) {
  try {
    const saved = JSON.parse(fs.readFileSync(configPath, 'utf8'));
    config = { ...defaults, ...saved };
  } catch {
    // config hỏng -> tạo lại với secret mới
  }
}
// Ghi lại ngay sau khi đọc để secret không đổi giữa các lần khởi động.
// Nếu config hỏng, defaults ở trên (gồm secret mới) sẽ được ghi đè lại.
fs.writeFileSync(configPath, JSON.stringify(config, null, 2));

export default config;
