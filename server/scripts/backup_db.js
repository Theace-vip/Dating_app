// Sao lưu database: node scripts/backup_db.js
// Dùng VACUUM INTO để tạo snapshot nhất quán (an toàn khi server đang chạy).
import fs from 'node:fs';
import path from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import { serverRoot } from '../src/config.js';

const dataDir = path.join(serverRoot, 'data');
const dbPath = path.join(dataDir, 'soulmate.db');
const backupDir = path.join(serverRoot, 'backups');

if (!fs.existsSync(dbPath)) {
  console.log('[sao-luu] Chưa có database -> bỏ qua.');
  process.exit(0);
}

fs.mkdirSync(backupDir, { recursive: true });

const stamp = new Date()
  .toISOString()
  .replace(/[:.]/g, '-')
  .slice(0, 19);
const outPath = path.join(backupDir, `soulmate-${stamp}.db`);

const db = new DatabaseSync(dbPath, { readOnly: true });
db.exec(`VACUUM INTO '${outPath.replace(/'/g, "''")}'`);
db.close();

// Giữ tối đa 14 bản sao lưu gần nhất
const files = fs
  .readdirSync(backupDir)
  .filter((f) => f.startsWith('soulmate-') && f.endsWith('.db'))
  .sort();
while (files.length > 14) {
  const oldest = files.shift();
  fs.unlinkSync(path.join(backupDir, oldest));
}

const size = (fs.statSync(outPath).size / 1024).toFixed(1);
console.log(`[sao-luu] OK: ${path.basename(outPath)} (${size} KB)`);
