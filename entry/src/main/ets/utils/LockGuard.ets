// LockGuard.ets
// 每个业务页面在回到前台时调用，确保应用锁不会只在首页生效。

import { router } from '@kit.ArkUI';
import { appLock } from './AuthLock';

export function redirectToLockIfNeeded(): void {
  if (!appLock.isEnabled || !appLock.isLocked) {
    return;
  }
  setTimeout(() => {
    if (appLock.isEnabled && appLock.isLocked) {
      router.replaceUrl({ url: 'features/LockView' });
    }
  }, 50);
}
