// AccountStore.ets
// 全局 ViewModel —— KeychainStore 之上的一层薄包装
// ArkUI 没有 EnvironmentObject，所以用单例 + AppStorage 通知刷新

import { KeychainStore } from './KeychainStore';
import { TOTPAccount } from '../model/TOTPAccount';

@ObservedV2
export class AccountStore {
  @Trace accounts: TOTPAccount[] = [];
  @Trace lastError: string = '';

  private keychain: KeychainStore;

  constructor() {
    this.keychain = KeychainStore.getInstance();
  }

  getAccounts(): TOTPAccount[] {
    if (!this.accounts) {
      return [];
    }
    return this.accounts;
  }

  load(): void {
    try {
      this.accounts = this.keychain.loadAll();
    } catch (e) {
      this.lastError = `加载失败：${(e as Error).message ?? e}`;
      this.accounts = [];
    }
  }

  add(account: TOTPAccount): boolean {
    try {
      this.keychain.save(account);
      this.load();
      return true;
    } catch (e) {
      this.lastError = `保存失败：${(e as Error).message ?? e}`;
      return false;
    }
  }

  update(account: TOTPAccount): boolean {
    try {
      this.keychain.save(account);
      this.load();
      return true;
    } catch (e) {
      this.lastError = `更新失败：${(e as Error).message ?? e}`;
      return false;
    }
  }

  delete(id: string): boolean {
    try {
      this.keychain.delete(id);
      this.load();
      return true;
    } catch (e) {
      this.lastError = `删除失败：${(e as Error).message ?? e}`;
      return false;
    }
  }

  deleteAll(): void {
    try {
      this.keychain.deleteAll();
      this.load();
    } catch (e) {
      this.lastError = `清空失败：${(e as Error).message ?? e}`;
    }
  }

  clearError(): void {
    this.lastError = '';
  }
}

// 全局单例（避免 Env 包装的复杂度）
export const accountStore: AccountStore = new AccountStore();
