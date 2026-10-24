import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
export const serverRoot = path.resolve(__dirname, '..');

const configPath = path.join(serverRoot, 'config.json');

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
// Ghi lại để secret không đổi giữa các lần chạy
fs.writeFileSync(configPath, JSON.stringify(config, null, 2));

export default config;
