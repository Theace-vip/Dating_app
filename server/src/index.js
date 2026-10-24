import fs from 'node:fs';
import path from 'node:path';
import https from 'node:https';
import os from 'node:os';
import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import rateLimit from 'express-rate-limit';
import config, { serverRoot } from './config.js';
import './db.js';
import authRouter, { authMiddleware } from './auth.js';
import apiRouter from './routes.js';
import { initSocket } from './socket.js';
import { ensureCert } from '../scripts/gen-cert.js';

// ===== HTTPS (self-signed) + cert pinning ở phía app =====
const { key, cert, pin } = ensureCert();

const app = express();
app.disable('x-powered-by');
app.set('trust proxy', 1);
app.use(helmet());
app.use(cors());
// 10MB: đủ cho ảnh base64 (tối đa 5MB) khi upload; các payload khác vẫn bị rate limit
app.use(express.json({ limit: '10mb' }));
app.use(rateLimit({
  windowMs: 5 * 60 * 1000,
  limit: 600,
  standardHeaders: true,
  legacyHeaders: false,
}));

app.get('/health', (req, res) => res.json({ ok: true, app: 'SoulMate', time: Date.now() }));
// Ảnh upload: phục vụ tĩnh (không nhạy cảm, vẫn qua HTTPS + cert pinning)
app.use('/uploads', express.static(path.join(serverRoot, 'uploads'), {
  maxAge: '30d',
  immutable: true,
}));
app.use('/api/auth', authRouter);
app.use('/api', authMiddleware, apiRouter);

app.use((err, req, res, next) => {
  if (err?.type === 'entity.parse.failed') {
    return res.status(400).json({ error: 'bad_json' });
  }
  console.error('[error]', err.message);
  res.status(500).json({ error: 'internal_error' });
});

const server = https.createServer({ key, cert }, app);
initSocket(server);

function lanAddresses() {
  const out = [];
  for (const [name, list] of Object.entries(os.networkInterfaces())) {
    for (const ni of list || []) {
      if (ni.family === 'IPv4' && !ni.internal && !ni.address.startsWith('169.254.')) {
        out.push(`${ni.address} (${name})`);
      }
    }
  }
  return out;
}

server.listen(config.port, '0.0.0.0', () => {
  const lans = lanAddresses();
  console.log('==================================================');
  console.log('  SoulMate Server đã chạy (HTTPS + Socket.io)');
  console.log(`  Local:     https://localhost:${config.port}`);
  for (const addr of lans) {
    console.log(`  Mang LAN:  https://${addr.split(' ')[0]}:${config.port}  <- nhap IP nay vao app`);
  }
  if (lans.length) {
    console.log('  (dien thoai cung WiFi vao duoc; can mo firewall: chay mo_ket_noi_mang.bat)');
  }
  console.log(`  Cert pin SHA-256: ${pin}`);
  console.log('  Tài khoản mẫu: demo1@soulmate.app / Demo@1234');
  console.log('==================================================');
});
