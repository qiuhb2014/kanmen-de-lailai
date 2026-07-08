// TOTPAccount.ets
// 一个 TOTP 账号 = 一个网站/服务的一条绑定记录

import { TOTPGenerator, OTPAlgorithm } from '../crypto/TOTPGenerator';

export class TOTPAccount {
  id: string = '';
  issuer: string = '';            // 服务名，比如 "GitHub"
  account: string = '';           // 账号，比如 "you@x.com"
  secret: Uint8Array = new Uint8Array(0);   // 共享密钥
  digits: number = 6;
  period: number = 30;
  algorithm: OTPAlgorithm = OTPAlgorithm.SHA1;
  createdAt: number = 0;          // Date.now()

  /** 显示名（服务名优先） */
  get displayName(): string {
    if (!this.issuer) return this.account;
    return this.issuer;
  }

  get subtitle(): string {
    return this.issuer ? this.account : '';
  }

  /** 计算当前 6 位码 */
  currentCode(date: Date = new Date()): string {
    const gen = new TOTPGenerator(this.secret, this.digits, this.period, this.algorithm);
    return gen.generate(date);
  }

  /** 倒计时 */
  remainingSeconds(date: Date = new Date()): number {
    return this.period - (Math.floor(date.getTime() / 1000) % this.period);
  }

  /** 进度 0.0~1.0 */
  progress(date: Date = new Date()): number {
    const elapsed = Math.floor(date.getTime() / 1000) % this.period;
    return elapsed / this.period;
  }
}
