// BackupCrypto.ets
// 备份流程：
// 1. 把所有账号（含 secret）序列化成 JSON
// 2. 用 PBKDF2-HMAC-SHA256 从用户密码派生 AES-256 密钥
// 3. AES-GCM 加密 → combined 格式（nonce + ciphertext + tag）
// 4. 写入 iCloud / Drive Kit / 用户指定位置
//
// 鸿蒙的 cryptoFramework 没有原生 PBKDF2 API，
// 下面用 HMAC-SHA256 自行实现 RFC 2898 标准的 PBKDF2。

import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';
import { TOTPAccount } from '../model/TOTPAccount';
import { parseOTPAlgorithm } from './TOTPGenerator';
import { Base32 } from '../utils/Base32';
import { secureRandomBytes } from '../utils/Random';

const ITERATIONS = 200_000;
const SALT_LEN = 16;
const NONCE_LEN = 12;       // AES-GCM nonce
const KEY_LEN = 32;         // AES-256

interface BackupPayload {
  version: number;
  kdf: string;
  iterations: number;
  salt: string;             // base64
  data: string;             // base64: iv(12) + ciphertext + tag(16)
}

interface BackupPlaintext {
  accounts: BackupAccount[];
  exportedAt: number;
}

interface BackupAccount {
  id: string;
  issuer: string;
  account: string;
  secretBase32: string;
  digits: number;
  period: number;
  algorithm: string;
  createdAt: number;
}

export class BackupError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'BackupError';
  }
}

export class BackupCrypto {

  /** 导出：明文账号 → 加密 JSON 字节流 */
  static async export(accounts: TOTPAccount[], password: string): Promise<Uint8Array> {
    // 1) 序列化明文
    const plain: BackupPlaintext = {
      accounts: accounts.map((a: TOTPAccount): BackupAccount => toBackupAccount(a)),
      exportedAt: Date.now(),
    };
    const plainBytes = utf8Encode(JSON.stringify(plain));

    // 2) 随机 salt + 派生密钥
    const salt = secureRandomBytes(SALT_LEN);
    const key = await pbkdf2(password, salt, ITERATIONS, KEY_LEN);

    // 3) AES-GCM 加密
    const iv = secureRandomBytes(NONCE_LEN);

    const cipher = cryptoFramework.createCipher('AES256|GCM|PKCS7');
    const symKey = await cryptoFramework.createSymKeyGenerator('AES256').convertKey({ data: key });
    await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, symKey, gcmParams(iv));
    const encResult = await cipher.doFinal({ data: plainBytes });
    const ciphertextWithTag = new Uint8Array(encResult.data);

    // 4) 拼 combined = iv(12) + ciphertext + tag(16)
    const combined = concatBytes(iv, ciphertextWithTag);

    // 5) 打包 JSON
    const payload: BackupPayload = {
      version: 1,
      kdf: 'PBKDF2-SHA256',
      iterations: ITERATIONS,
      salt: toBase64(salt),
      data: toBase64(combined),
    };
    return utf8Encode(JSON.stringify(payload));
  }

  /** 导入：加密 JSON 字节流 → 明文账号列表 */
  static async import(data: Uint8Array, password: string): Promise<TOTPAccount[]> {
    let payload: BackupPayload;
    try {
      payload = JSON.parse(utf8Decode(data)) as BackupPayload;
    } catch {
      throw new BackupError('备份文件格式不识别');
    }
    if (payload.version !== 1 || payload.kdf !== 'PBKDF2-SHA256') {
      throw new BackupError('备份文件格式不识别');
    }

    const salt = fromBase64(payload.salt);
    const combined = fromBase64(payload.data);
    if (combined.length < NONCE_LEN + 16) {
      throw new BackupError('备份文件已损坏');
    }
    const iv = combined.slice(0, NONCE_LEN);
    const ciphertextWithTag = combined.slice(NONCE_LEN);

    const key = await pbkdf2(password, salt, payload.iterations, KEY_LEN);
    const symKey = await cryptoFramework.createSymKeyGenerator('AES256').convertKey({ data: key });

    const cipher = cryptoFramework.createCipher('AES256|GCM|PKCS7');
    await cipher.init(cryptoFramework.CryptoMode.DECRYPT_MODE, symKey, gcmParams(iv));

    let plainBytes: Uint8Array;
    try {
      const decResult = await cipher.doFinal({ data: ciphertextWithTag });
      plainBytes = new Uint8Array(decResult.data);
    } catch {
      // AES-GCM auth tag 校验失败 = 密码错 或 文件被改
      throw new BackupError('密码错误，或文件已损坏');
    }

    const plain = JSON.parse(utf8Decode(plainBytes)) as BackupPlaintext;
    return plain.accounts.map((p: BackupAccount) => {
      const acc = new TOTPAccount();
      const secret = Base32.decode(p.secretBase32);
      acc.id = p.id;
      acc.issuer = p.issuer;
      acc.account = p.account;
      acc.secret = secret ?? new Uint8Array(0);
      acc.digits = p.digits;
      acc.period = p.period;
      acc.algorithm = parseOTPAlgorithm(p.algorithm);
      acc.createdAt = p.createdAt;
      return acc;
    });
  }
}

function toBackupAccount(account: TOTPAccount): BackupAccount {
  const backup: BackupAccount = {
    id: account.id,
    issuer: account.issuer,
    account: account.account,
    secretBase32: Base32.encode(account.secret),
    digits: account.digits,
    period: account.period,
    algorithm: account.algorithm,
    createdAt: account.createdAt,
  };
  return backup;
}

function utf8Encode(value: string): Uint8Array {
  return util.TextEncoder.create('utf-8').encodeInto(value);
}

function utf8Decode(value: Uint8Array): string {
  return util.TextDecoder.create('utf-8').decodeToString(value);
}

function gcmParams(iv: Uint8Array): cryptoFramework.GcmParamsSpec {
  const params: cryptoFramework.GcmParamsSpec = {
    algName: 'GcmParamsSpec',
    iv: { data: iv },
    aad: { data: new Uint8Array(0) },
    authTag: { data: new Uint8Array(16) },
  };
  return params;
}

// ============================================================
// PBKDF2-HMAC-SHA256 自实现（RFC 2898）
// ============================================================

async function pbkdf2(password: string, salt: Uint8Array, iterations: number, keyLen: number): Promise<Uint8Array> {
  const pwdBytes = utf8Encode(password);
  const blockCount = Math.ceil(keyLen / 32);   // SHA-256 输出 32 字节
  const result = new Uint8Array(blockCount * 32);

  for (let i = 1; i <= blockCount; i++) {
    // 第一个 block: U1 = HMAC(P, salt || INT(i))
    const saltInt = new Uint8Array(salt.length + 4);
    saltInt.set(salt, 0);
    const view = new DataView(saltInt.buffer);
    view.setUint32(salt.length, i, false);

    let u = hmacSha256(pwdBytes, saltInt);
    const block = new Uint8Array(u);

    // 后续: Un = HMAC(P, U(n-1)), block = U1 XOR U2 XOR ... XOR Uc
    for (let j = 1; j < iterations; j++) {
      u = hmacSha256(pwdBytes, u);
      for (let k = 0; k < block.length; k++) {
        block[k] ^= u[k];
      }
    }

    result.set(block, (i - 1) * 32);
  }

  return result.slice(0, keyLen);
}

function hmacSha256(key: Uint8Array, data: Uint8Array): Uint8Array {
  const keyBlob: cryptoFramework.DataBlob = { data: key };
  const symKey = cryptoFramework.createSymKeyGenerator('HMAC|SHA256').convertKeySync(keyBlob);
  const mac = cryptoFramework.createMac('HMAC|SHA256');
  mac.initSync(symKey);
  mac.updateSync({ data: data });
  const result = mac.doFinalSync();
  return new Uint8Array(result.data);
}

// ============================================================
// 工具函数
// ============================================================

function concatBytes(a: Uint8Array, b: Uint8Array): Uint8Array {
  const out = new Uint8Array(a.length + b.length);
  out.set(a, 0);
  out.set(b, a.length);
  return out;
}

function toBase64(bytes: Uint8Array): string {
  return new util.Base64Helper().encodeToStringSync(bytes);
}

function fromBase64(s: string): Uint8Array {
  return new util.Base64Helper().decodeSync(s);
}
