// Base32.ets
// RFC 4648 Base32 编解码 —— 用于 otpauth:// URI 里的 secret

const ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

export class Base32 {
  /**
   * 编码 Uint8Array → Base32 字符串（不带 padding）
   */
  static encode(data: Uint8Array): string {
    if (data.length === 0) {
      return '';
    }
    let output = '';
    let buffer = 0;
    let bitsLeft = 0;
    for (let i = 0; i < data.length; i++) {
      buffer = (buffer << 8) | data[i];
      bitsLeft += 8;
      while (bitsLeft >= 5) {
        bitsLeft -= 5;
        const index = (buffer >> bitsLeft) & 0x1f;
        output += ALPHABET.charAt(index);
      }
    }
    if (bitsLeft > 0) {
      const index = (buffer << (5 - bitsLeft)) & 0x1f;
      output += ALPHABET.charAt(index);
    }
    return output;
  }

  /**
   * 解码 Base32 字符串 → Uint8Array
   * 容错：自动去空格/小写/padding/- 分隔
   */
  static decode(input: string): Uint8Array | null {
    const cleaned = input
      .toUpperCase()
      .replace(/ /g, '')
      .replace(/-/g, '')
      .replace(/=/g, '');

    if (cleaned.length === 0) {
      return new Uint8Array(0);
    }

    const out: number[] = [];
    let buffer = 0;
    let bitsLeft = 0;
    for (let i = 0; i < cleaned.length; i++) {
      const ch = cleaned.charAt(i);
      const value = ALPHABET.indexOf(ch);
      if (value < 0) {
        return null;  // 非法字符
      }
      buffer = (buffer << 5) | value;
      bitsLeft += 5;
      if (bitsLeft >= 8) {
        bitsLeft -= 8;
        out.push((buffer >> bitsLeft) & 0xff);
      }
    }
    return new Uint8Array(out);
  }
}
