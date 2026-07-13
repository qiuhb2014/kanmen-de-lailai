// EntryAbility.ets
// App 入口 Ability —— 加载主页 + 初始化 KeychainStore

import UIAbility from '@ohos.app.ability.UIAbility';
import window from '@ohos.window';
import { KeychainStore } from '../store/KeychainStore';
import { accountStore } from '../store/AccountStore';
import { appLock } from '../utils/AuthLock';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'LailaiGuard';
const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(): void {
    hilog.info(DOMAIN, TAG, 'EntryAbility onCreate');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, 'EntryAbility onWindowStageCreate');

    // 初始化 KeychainStore（拿到 context 后才能用 Preferences）
    KeychainStore.getInstance().init(this.context);
    appLock.init(this.context);
    accountStore.load();

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load content: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'Page loaded');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, 'EntryAbility onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, 'EntryAbility onForeground');
    appLock.lockIfEnabled();
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, 'EntryAbility onBackground');
    // 进后台时如果开启了应用锁，就锁上
    appLock.lockIfEnabled();
  }
}
