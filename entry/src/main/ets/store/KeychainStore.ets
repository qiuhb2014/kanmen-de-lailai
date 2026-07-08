// KeychainStore.ets
// 持久化层 —— 鸿蒙没有原生 Keychain
// 折中方案：使用 @ohos.data.preferences（应用沙箱 KV 存储）
// 数据本身受鸿蒙应用沙箱保护（卸载即清空 + 系统级隔离）
// 生产环境建议再加 KeyStore / HUKS 对 secret 字段做二次加密

import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { TOTPAccount } from '../model/TOTPAccount';
import { parseOTPAlgorithm } from '../crypto/TOTPGenerator';
import { Base32 } from '../utils/Base32';

const STORE_NAME = 'twofa_secure_store';
const ACCOUNTS_KEY = 'accounts_v1';

interface StoredAccount {
  id: string;
  issuer: string;
  account: string;
  secretBase32: string;
  digits: number;
  period: number;
  algorithm: string;
  createdAt: number;
}

export class KeychainStore {
  private static instance: KeychainStore | null = null;
  private prefs: preferences.Preferences | null = null;

  static getInstance(): KeychainStore {
    if (!KeychainStore.instance) {
      KeychainStore.instance = new KeychainStore();
    }
    return KeychainStore.instance;
  }

  /** 必须在 EntryAbility 的 onWindowStageCreate 之后调用一次 */
  init(context: common.UIAbilityContext): void {
    if (this.prefs) return;
    const options: preferences.Options = { name: STORE_NAME };
    this.prefs = preferences.getPreferencesSync(context, options);
  }

  loadAll(): TOTPAccount[] {
    if (!this.prefs) {
      console.error('KeychainStore not initialized');
      return [];
    }
    try {
      const json = this.prefs.getSync(ACCOUNTS_KEY, '[]') as string;
      const arr: StoredAccount[] = JSON.parse(json);
      const accounts: TOTPAccount[] = [];
      arr.forEach((item: StoredAccount) => {
        const account = this.toAccount(item);
        if (account !== null) {
          accounts.push(account);
        }
      });
      return accounts.sort((a: TOTPAccount, b: TOTPAccount) => a.createdAt - b.createdAt);
    } catch (e) {
      console.error('KeychainStore.loadAll failed', JSON.stringify(e));
      return [];
    }
  }

  save(account: TOTPAccount): void {
    if (!this.prefs) {
      throw new Error('存储未初始化');
    }
    const list = this.loadAll();
    // upsert: 同 id 替换
    const idx = list.findIndex((a) => a.id === account.id);
    if (idx >= 0) {
      list[idx] = account;
    } else {
      list.push(account);
    }
    this.writeAll(list);
  }

  delete(id: string): void {
    const list = this.loadAll().filter((a) => a.id !== id);
    this.writeAll(list);
  }

  deleteAll(): void {
    this.writeAll([]);
  }

  // MARK: - 内部

  private writeAll(accounts: TOTPAccount[]): void {
    if (!this.prefs) {
      throw new Error('存储未初始化');
    }
    const arr: StoredAccount[] = accounts.map(this.fromAccount);
    const json = JSON.stringify(arr);
    this.prefs.putSync(ACCOUNTS_KEY, json);
    this.prefs.flushSync();
  }

  private toAccount = (s: StoredAccount): TOTPAccount | null => {
    const secret = Base32.decode(s.secretBase32);
    if (!secret) return null;
    const acc = new TOTPAccount();
    acc.id = s.id;
    acc.issuer = s.issuer;
    acc.account = s.account;
    acc.secret = secret;
    acc.digits = s.digits;
    acc.period = s.period;
    acc.algorithm = parseOTPAlgorithm(s.algorithm);
    acc.createdAt = s.createdAt;
    return acc;
  };

  private fromAccount = (a: TOTPAccount): StoredAccount => {
    return {
      id: a.id,
      issuer: a.issuer,
      account: a.account,
      secretBase32: Base32.encode(a.secret),
      digits: a.digits,
      period: a.period,
      algorithm: a.algorithm,
      createdAt: a.createdAt,
    };
  };
}
