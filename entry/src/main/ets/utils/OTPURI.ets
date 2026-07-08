// OTPURI.ets
// otpauth:// URI 解析与生成
// 格式: otpauth://totp/Issuer:Account?secret=XXX&issuer=Issuer&algorithm=SHA1&digits=6&period=30

import { Base32 } from '../utils/Base32';
import { TOTPAccount } from '../model/TOTPAccount';
import { OTPAlgorithm, parseOTPAlgorithm } from '../crypto/TOTPGenerator';
import { generateUuid } from './Random';

export class OTPUriError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'OTPUriError';
  }
}

/**
 * 解析 otpauth:// URI → TOTPAccount
 */
export function parseOTPUri(uri: string): TOTPAccount {
  // scheme 检查
  if (!uri.startsWith('otpauth://')) {
    throw new OTPUriError('URI 必须是 otpauth:// 开头');
  }
  // type 检查
  if (!uri.startsWith('otpauth://totp/')) {
    throw new OTPUriError('仅支持 TOTP 类型（暂不支持 HOTP）');
  }

  // 拆 path 和 query
  const pathQuery = uri.substring('otpauth://totp/'.length);
  const qIndex = pathQuery.indexOf('?');
  const labelRaw = qIndex < 0 ? pathQuery : pathQuery.substring(0, qIndex);
  const queryStr = qIndex < 0 ? '' : pathQuery.substring(qIndex + 1);

  const label = decodeURIComponent(labelRaw);
  let issuer: string | null = null;
  let account: string;
  const colonIdx = label.indexOf(':');
  if (colonIdx >= 0) {
    issuer = label.substring(0, colonIdx).trim();
    account = label.substring(colonIdx + 1).trim();
  } else {
    account = label;
  }

  // query 解析
  const query: Record<string, string> = {};
  if (queryStr) {
    queryStr.split('&').forEach((kv) => {
      const idx = kv.indexOf('=');
      if (idx > 0) {
        const k = decodeURIComponent(kv.substring(0, idx));
        const v = decodeURIComponent(kv.substring(idx + 1));
        query[k] = v;
      }
    });
  }

  // secret 必填
  const secretStr = query['secret'];
  if (!secretStr) {
    throw new OTPUriError('缺少 secret 参数');
  }
  const secretBytes = Base32.decode(secretStr);
  if (!secretBytes || secretBytes.length === 0) {
    throw new OTPUriError('secret 不是合法的 Base32');
  }

  const digits = parseInt(query['digits'] ?? '6', 10) || 6;
  const period = parseInt(query['period'] ?? '30', 10) || 30;
  const algorithm = parseOTPAlgorithm(query['algorithm'] ?? 'SHA1');
  const finalIssuer = (query['issuer'] ?? issuer ?? '').trim();

  const acc = new TOTPAccount();
  acc.id = generateUuid();
  acc.issuer = finalIssuer;
  acc.account = account;
  acc.secret = secretBytes;
  acc.digits = digits;
  acc.period = period;
  acc.algorithm = algorithm;
  acc.createdAt = Date.now();
  return acc;
}

/**
 * TOTPAccount → otpauth:// URI
 */
export function buildOTPUri(account: TOTPAccount): string {
  const label = account.issuer
    ? `${encodeURIComponent(account.issuer)}:${encodeURIComponent(account.account)}`
    : encodeURIComponent(account.account);

  const params = [
    `secret=${encodeURIComponent(Base32.encode(account.secret))}`,
    `issuer=${encodeURIComponent(account.issuer)}`,
    `digits=${account.digits}`,
    `period=${account.period}`,
    `algorithm=${account.algorithm}`,
  ];
  return `otpauth://totp/${label}?${params.join('&')}`;
}
