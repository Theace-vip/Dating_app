import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import selfsigned from 'selfsigned';
import { serverRoot } from '../src/config.js';

export const certDir = path.join(serverRoot, 'certs');
export const keyPath = path.join(certDir, 'server.key');
export const certPath = path.join(certDir, 'server.crt');

/**
 * Tạo certificate self-signed (HTTPS) nếu chưa có.
 * Trả về { key, cert, pin } trong đó pin = SHA-256 (hex) của DER certificate
 * — chính là giá trị nhúng trong app Flutter để chống MITM.
 */
export function ensureCert({ force = false } = {}) {
  fs.mkdirSync(certDir, { recursive: true });
  if (!force && fs.existsSync(keyPath) && fs.existsSync(certPath)) {
    const cert = fs.readFileSync(certPath);
    return {
      key: fs.readFileSync(keyPath),
      cert,
      pin: certSha256(cert),
    };
  }

  const pems = selfsigned.generate(
    [
      { name: 'commonName', value: 'localhost' },
      { name: 'organizationName', value: 'SoulMate' },
    ],
    {
      days: 3650,
      keySize: 2048,
      algorithm: 'sha256',
      extensions: [
        { name: 'basicConstraints', cA: false },
        { name: 'keyUsage', digitalSignature: true, keyEncipherment: true },
        { name: 'extKeyUsage', serverAuth: true },
        {
          name: 'subjectAltName',
          altNames: [
            { type: 2, value: 'localhost' }, // DNS
            { type: 7, ip: '127.0.0.1' },    // IP
          ],
        },
      ],
    },
  );

  fs.writeFileSync(keyPath, pems.private, { mode: 0o600 });
  fs.writeFileSync(certPath, pems.cert);
  const cert = fs.readFileSync(certPath);
  return { key: fs.readFileSync(keyPath), cert, pin: certSha256(cert) };
}

/** SHA-256 của DER (body PEM base64) -> hex, kiểu giống Flutter X509Certificate.der */
export function certSha256(pemCert) {
  const b64 = pemCert
    .toString('utf8')
    .replace(/-----BEGIN CERTIFICATE-----/, '')
    .replace(/-----END CERTIFICATE-----/, '')
    .replace(/\s+/g, '');
  const der = Buffer.from(b64, 'base64');
  return crypto.createHash('sha256').update(der).digest('hex');
}

// Chạy trực tiếp: node scripts/gen-cert.js
const isMain = process.argv[1] && import.meta.url.endsWith(path.basename(process.argv[1]));
if (isMain) {
  const { pin } = ensureCert({ force: process.argv.includes('--force') });
  console.log('Certificate pin (SHA-256 hex):');
  console.log(pin);
}
