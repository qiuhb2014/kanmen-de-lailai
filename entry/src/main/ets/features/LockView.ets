// LockView.ets
// 应用锁屏页 —— 触发 Face ID / 指纹解锁，成功后回 Index

import { router } from '@kit.ArkUI';
import { appLock } from '../utils/AuthLock';
import {
  APP_NAME,
  COLOR_BACKGROUND,
  COLOR_BRAND,
  COLOR_CARD,
  COLOR_DANGER,
  COLOR_TEXT,
  COLOR_TEXT_WEAK,
  RADIUS_BUTTON,
} from '../theme/DesignTokens';

@Entry
@Component
struct LockView {
  @State busy: boolean = false;

  aboutToAppear(): void {
    this.tryUnlock();
  }

  private async tryUnlock(): Promise<void> {
    if (this.busy) return;
    this.busy = true;
    const success = await appLock.unlock();
    this.busy = false;
    if (success) {
      router.replaceUrl({ url: 'pages/Index' });
    }
  }

  build() {
    Column() {
      Column() {
        Text(`${APP_NAME} 已锁定`)
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_TEXT)

        Text('使用 Face ID / 指纹解锁')
          .fontSize(14)
          .fontColor(COLOR_TEXT_WEAK)
          .margin({ top: 8 })

        if (appLock.lastError) {
          Text(appLock.lastError)
            .fontSize(13)
            .fontColor(COLOR_DANGER)
            .margin({ top: 20 })
        }
      }
      .layoutWeight(1)
      .width('100%')
      .justifyContent(FlexAlign.Center)

      Button(this.busy ? '验证中...' : '解锁')
        .width('80%')
        .height(50)
        .margin({ bottom: 60 })
        .fontColor(COLOR_CARD)
        .backgroundColor(this.busy ? '#CCCCCC' : COLOR_BRAND)
        .borderRadius(RADIUS_BUTTON)
        .onClick(() => this.tryUnlock())
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_BACKGROUND)
  }
}
