import { cryptoFramework } from '@kit.CryptoArchitectureKit';

export function secureRandomBytes(length: number): Uint8Array {
  const random = cryptoFramework.createRandom();
  const result = random.generateRandomSync(length);
  return new Uint8Array(result.data);
}

export function generateUuid(): string {
  try {
    return uuidFromBytes(secureRandomBytes(16));
  } catch (e) {
    return fallbackUuid();
  }
}

function uuidFromBytes(bytes: Uint8Array): string {
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = Array.from(bytes).map((b: number) => b.toString(16).padStart(2, '0'));
  return `${hex.slice(0, 4).join('')}-${hex.slice(4, 6).join('')}-${hex.slice(6, 8).join('')}-${hex.slice(8, 10).join('')}-${hex.slice(10, 16).join('')}`;
}

function fallbackUuid(): string {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c: string) => {
    const r = (Math.random() * 16) | 0;
    const v = c === 'x' ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}
