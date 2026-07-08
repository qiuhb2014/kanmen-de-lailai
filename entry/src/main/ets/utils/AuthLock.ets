// AuthLock.ets
// 应用锁状态管理 —— 用鸿蒙的 @kit.UserAuthenticationKit 触发 Face ID / 指纹
//
// 行为：
// - App 进后台 → 自动 lock（如果 isEnabled）
// - App 回前台 / 启动 → 跳到 LockView
// - LockView 触发 userAuth 认证 → 成功就解锁

import { userAuth } from '@kit.UserAuthenticationKit';
import { BusinessError } from '@kit.BasicServicesKit';

@ObservedV2
export class AppLock {
  @Trace isLocked: boolean = false;
  @Trace isEnabled: boolean = false;
  @Trace lastError: string = '';

  enable(): void {
    this.isEnabled = true;
  }

  disable(): void {
    this.isEnabled = false;
    this.isLocked = false;
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
}

export const appLock: AppLock = new AppLock();
