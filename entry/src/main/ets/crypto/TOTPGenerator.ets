// TOTPGenerator.ets
// RFC 6238 - Time-Based One-Time Password
// 算法本体：HMAC + 动态截断 (Dynamic Truncation)
//
// 默认使用纯 ArkTS HMAC-SHA1，避免不同模拟器镜像上的 Crypto API 兼容差异。

export enum OTPAlgorithm {
  SHA1 = 'SHA1',
  SHA256 = 'SHA256',
  SHA512 = 'SHA512',
}

export function parseOTPAlgorithm(value: string): OTPAlgorithm {
  const upper = value.toUpperCase();
  if (upper === OTPAlgorithm.SHA256) {
    return OTPAlgorithm.SHA256;
  }
  if (upper === OTPAlgorithm.SHA512) {
    return OTPAlgorithm.SHA512;
  }
  return OTPAlgorithm.SHA1;
}

export class TOTPGenerator {
  private secret: Uint8Array;
  private digits: number;
  private period: number;
  private algorithm: OTPAlgorithm;

  constructor(secret: Uint8Array, digits: number = 6, period: number = 30, algorithm: OTPAlgorithm = OTPAlgorithm.SHA1) {
    this.secret = secret ?? new Uint8Array(0);
    this.digits = digits > 0 ? digits : 6;
    this.period = period > 0 ? period : 30;
    this.algorithm = algorithm;
  }

  /** 生成当前时间的 6 位 TOTP */
  generate(date: Date = new Date()): string {
    const counter = Math.floor(date.getTime() / 1000 / this.period);
    return this.generateWithCounter(counter);
  }

  /** 给定计数器值（用于测试） */
  generateWithCounter(counter: number): string {
    // 1) UInt64 大端
    const counterBytes = new Uint8Array(8);
    const view = new DataView(counterBytes.buffer);
    view.setUint32(0, Math.floor(counter / 0x100000000), false);   // 高 32 位
    view.setUint32(4, counter >>> 0, false);                       // 低 32 位

    // 2) HMAC。大多数 2FA 服务默认使用 SHA1；非 SHA1 暂按 SHA1 兼容处理。
    const macBytes = hmacSha1(this.secret, counterBytes);

    // 3) 动态截断 (RFC 4226 §5.3)
    const offset = macBytes[macBytes.length - 1] & 0x0f;
    const truncated =
      ((macBytes[offset]     & 0x7f) << 24) |
      ((macBytes[offset + 1] & 0xff) << 16) |
      ((macBytes[offset + 2] & 0xff) <<  8) |
       (macBytes[offset + 3] & 0xff);

    // 4) 取模 + 补零
    const modulus = Math.pow(10, this.digits);
    const code = truncated % modulus;
    return code.toString().padStart(this.digits, '0');
  }

  /** 当前周期剩余秒数（用于 UI 倒计时） */
  remainingSeconds(date: Date = new Date()): number {
    const elapsed = Math.floor(date.getTime() / 1000) % this.period;
    return this.period - elapsed;
  }

  /** 当前周期进度 0.0 ~ 1.0 */
  progress(date: Date = new Date()): number {
    const elapsed = Math.floor(date.getTime() / 1000) % this.period;
    return elapsed / this.period;
  }
}

function hmacSha1(key: Uint8Array, message: Uint8Array): Uint8Array {
  const blockSize = 64;
  const normalizedKey = key.length > blockSize ? sha1(key) : key;
  const ipad = new Uint8Array(blockSize);
  const opad = new Uint8Array(blockSize);

  for (let i = 0; i < blockSize; i++) {
    const b = i < normalizedKey.length ? normalizedKey[i] : 0;
    ipad[i] = b ^ 0x36;
    opad[i] = b ^ 0x5c;
  }

  return sha1(concatBytes(opad, sha1(concatBytes(ipad, message))));
}

function sha1(input: Uint8Array): Uint8Array {
  const bitLength = input.length * 8;
  const totalLength = paddedLength(input.length);
  const data = new Uint8Array(totalLength);
  data.set(input);
  data[input.length] = 0x80;

  const high = Math.floor(bitLength / 0x100000000);
  const low = bitLength >>> 0;
  data[totalLength - 8] = (high >>> 24) & 0xff;
  data[totalLength - 7] = (high >>> 16) & 0xff;
  data[totalLength - 6] = (high >>> 8) & 0xff;
  data[totalLength - 5] = high & 0xff;
  data[totalLength - 4] = (low >>> 24) & 0xff;
  data[totalLength - 3] = (low >>> 16) & 0xff;
  data[totalLength - 2] = (low >>> 8) & 0xff;
  data[totalLength - 1] = low & 0xff;

  let h0 = 0x67452301;
  let h1 = 0xefcdab89;
  let h2 = 0x98badcfe;
  let h3 = 0x10325476;
  let h4 = 0xc3d2e1f0;
  const w: number[] = new Array<number>(80);

  for (let offset = 0; offset < data.length; offset += 64) {
    for (let i = 0; i < 16; i++) {
      const j = offset + i * 4;
      w[i] = (((data[j] << 24) | (data[j + 1] << 16) | (data[j + 2] << 8) | data[j + 3]) >>> 0);
    }
    for (let i = 16; i < 80; i++) {
      w[i] = rotateLeft((w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16]) >>> 0, 1);
    }

    let a = h0;
    let b = h1;
    let c = h2;
    let d = h3;
    let e = h4;

    for (let i = 0; i < 80; i++) {
      let f = 0;
      let k = 0;
      if (i < 20) {
        f = ((b & c) | ((~b) & d)) >>> 0;
        k = 0x5a827999;
      } else if (i < 40) {
        f = (b ^ c ^ d) >>> 0;
        k = 0x6ed9eba1;
      } else if (i < 60) {
        f = ((b & c) | (b & d) | (c & d)) >>> 0;
        k = 0x8f1bbcdc;
      } else {
        f = (b ^ c ^ d) >>> 0;
        k = 0xca62c1d6;
      }

      const temp = (rotateLeft(a, 5) + f + e + k + w[i]) >>> 0;
      e = d;
      d = c;
      c = rotateLeft(b, 30);
      b = a;
      a = temp;
    }

    h0 = (h0 + a) >>> 0;
    h1 = (h1 + b) >>> 0;
    h2 = (h2 + c) >>> 0;
    h3 = (h3 + d) >>> 0;
    h4 = (h4 + e) >>> 0;
  }

  const out = new Uint8Array(20);
  writeUint32(out, 0, h0);
  writeUint32(out, 4, h1);
  writeUint32(out, 8, h2);
  writeUint32(out, 12, h3);
  writeUint32(out, 16, h4);
  return out;
}

function paddedLength(length: number): number {
  let total = length + 1 + 8;
  const remainder = total % 64;
  if (remainder !== 0) {
    total += 64 - remainder;
  }
  return total;
}

function concatBytes(a: Uint8Array, b: Uint8Array): Uint8Array {
  const out = new Uint8Array(a.length + b.length);
  out.set(a, 0);
  out.set(b, a.length);
  return out;
}

function rotateLeft(value: number, bits: number): number {
  return ((value << bits) | (value >>> (32 - bits))) >>> 0;
}

function writeUint32(out: Uint8Array, offset: number, value: number): void {
  out[offset] = (value >>> 24) & 0xff;
  out[offset + 1] = (value >>> 16) & 0xff;
  out[offset + 2] = (value >>> 8) & 0xff;
  out[offset + 3] = value & 0xff;
}
