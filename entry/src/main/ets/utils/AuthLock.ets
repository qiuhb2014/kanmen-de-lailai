// AuthLock.ets
// 应用锁状态管理 —— 用鸿蒙的 @kit.UserAuthenticationKit 触发 Face ID / 指纹
//
// 行为：
// - App 进后台 → 自动 lock（如果 isEnabled）
// - App 回前台 / 启动 → 跳到 LockView
// - LockView 触发 userAuth 认证 → 成功就解锁

import { userAuth } from '@kit.UserAuthenticationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const LOCK_STORE_NAME = 'lailai_lock_settings';
const LOCK_ENABLED_KEY = 'app_lock_enabled';

@ObservedV2
export class AppLock {
  @Trace isLocked: boolean = false;
  @Trace isEnabled: boolean = false;
  @Trace lastError: string = '';
  private prefs: preferences.Preferences | null = null;

  /** 必须在 EntryAbility 获得上下文后初始化。 */
  init(context: common.UIAbilityContext): void {
    try {
      const options: preferences.Options = { name: LOCK_STORE_NAME };
      this.prefs = preferences.getPreferencesSync(context, options);
      this.isEnabled = this.prefs.getSync(LOCK_ENABLED_KEY, false) as boolean;
      // 冷启动时，已启用的应用锁必须先完成认证才能进入应用。
      this.isLocked = this.isEnabled;
      this.lastError = '';
    } catch (e) {
      this.prefs = null;
      this.isEnabled = false;
      this.isLocked = false;
      this.lastError = `应用锁初始化失败：${(e as Error).message ?? e}`;
    }
  }

  enable(): void {
    this.isEnabled = true;
    this.isLocked = false;
    this.persistEnabled();
  }

  disable(): void {
    this.isEnabled = false;
    this.isLocked = false;
    this.persistEnabled();
  }

  /** App 进后台时调用 */
  lockIfEnabled(): void {
    if (this.isEnabled) {
      this.isLocked = true;
    }
  }

  /** 触发 Face ID / 指纹认证 */
  async unlock(): Promise<boolean> {
    if (!this.isEnabled) {
      this.isLocked = false;
      return true;
    }
    return this.authenticate();
  }

  /** 即使尚未开启应用锁，也要求一次生物认证，用于确认开启操作。 */
  async authenticate(): Promise<boolean> {
    try {
      const authParam: userAuth.AuthParam = {
        challenge: new Uint8Array([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]),
        authType: [userAuth.UserAuthType.FACE, userAuth.UserAuthType.FINGERPRINT],
        authTrustLevel: userAuth.AuthTrustLevel.ATL3,
      };
      const widgetParam: userAuth.WidgetParam = {
        title: '解锁看门的来来',
      };
      const result = await new Promise<userAuth.UserAuthResult>((resolve) => {
        const callback: userAuth.IAuthCallback = {
          onResult(result: userAuth.UserAuthResult): void {
            resolve(result);
          }
        };
        const auth = userAuth.getUserAuthInstance(authParam, widgetParam);
        auth.on('result', callback);
        auth.start();
      });
      if (result.result === userAuth.UserAuthResultCode.SUCCESS) {
        this.isLocked = false;
        this.lastError = '';
        return true;
      } else {
        this.lastError = '认证未通过';
        return false;
      }
    } catch (e) {
      const err = e as BusinessError;
      // 用户取消 = 不算错误
      if (err.code === userAuth.UserAuthResultCode.CANCELED) {
        this.lastError = '';
        return false;
      }
      this.lastError = `认证失败：${err.message ?? err.code}`;
      return false;
    }
  }

  private persistEnabled(): void {
    if (!this.prefs) {
      this.lastError = '应用锁存储未初始化';
      return;
    }
    try {
      this.prefs.putSync(LOCK_ENABLED_KEY, this.isEnabled);
      this.prefs.flushSync();
      this.lastError = '';
    } catch (e) {
      this.lastError = `保存应用锁设置失败：${(e as Error).message ?? e}`;
    }
  }
}

export const appLock: AppLock = new AppLock();
