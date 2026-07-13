// SettingsView.ets
// 设置页：应用锁、备份恢复、关于

import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { appLock } from '../utils/AuthLock';
import { redirectToLockIfNeeded } from '../utils/LockGuard';
import { accountStore } from '../store/AccountStore';
import {
  APP_NAME,
  COLOR_BACKGROUND,
  COLOR_BORDER,
  COLOR_BRAND,
  COLOR_CARD,
  COLOR_DANGER,
  COLOR_TEXT,
  COLOR_TEXT_SECONDARY,
  COLOR_TEXT_WEAK,
  PAGE_PADDING,
  RADIUS_CARD,
} from '../theme/DesignTokens';

@Entry
@Component
struct SettingsView {
  @State enableLock: boolean = false;
  @State accountCount: number = 0;

  aboutToAppear(): void {
    this.enableLock = appLock.isEnabled;
    this.accountCount = accountStore.getAccounts().length;
  }

  onPageShow(): void {
    redirectToLockIfNeeded();
  }

  build() {
    Column() {
      this.navBar()

      Scroll() {
        Column() {
          this.sectionTitle('安全')
          Column() {
            this.toggleRow('应用锁', '使用生物识别保护令牌', this.enableLock, (v: boolean) => this.toggleLock(v))
          }
          .backgroundColor(COLOR_CARD)
          .borderRadius(RADIUS_CARD)
          .margin({ left: PAGE_PADDING, right: PAGE_PADDING })

          this.sectionTitle('备份与恢复')
          Column() {
            this.linkRow('导出加密备份', `共 ${this.accountCount} 个令牌`, () => {
              router.pushUrl({ url: 'features/ExportView' });
            })
            this.divider()
            this.linkRow('导入备份', '从加密备份文件恢复', () => {
              router.pushUrl({ url: 'features/ImportView' });
            })
          }
          .backgroundColor(COLOR_CARD)
          .borderRadius(RADIUS_CARD)
          .margin({ left: PAGE_PADDING, right: PAGE_PADDING })

          this.sectionTitle('数据')
          Column() {
            this.linkRow('清空所有令牌', '此操作不可恢复', () => this.confirmDeleteAll(), true)
          }
          .backgroundColor(COLOR_CARD)
          .borderRadius(RADIUS_CARD)
          .margin({ left: PAGE_PADDING, right: PAGE_PADDING })

          this.sectionTitle('关于')
          Column() {
            this.linkRow('使用说明', '', () => this.showHelp())
            this.divider()
            this.linkRow('隐私说明', '本地保存，不上传密钥', () => this.showPrivacy())
            this.divider()
            this.linkRow('版本', '1.0.0', () => {})
          }
          .backgroundColor(COLOR_CARD)
          .borderRadius(RADIUS_CARD)
          .margin({ left: PAGE_PADDING, right: PAGE_PADDING })

          Text(`${APP_NAME} v1.0.0\nHarmonyOS 原生两步验证令牌管理器`)
            .fontSize(12)
            .fontColor(COLOR_TEXT_WEAK)
            .textAlign(TextAlign.Center)
            .width('100%')
            .margin({ top: 28, bottom: 32 })
        }
      }
      .layoutWeight(1)
      .backgroundColor(COLOR_BACKGROUND)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_BACKGROUND)
  }

  @Builder
  navBar() {
    Row() {
      Text('返回')
        .fontSize(16)
        .fontColor(COLOR_BRAND)
        .width(64)
        .onClick(() => router.back())
      Text('设置')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(COLOR_TEXT)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
      Text('')
        .width(64)
    }
    .width('100%')
    .padding({ left: PAGE_PADDING, right: PAGE_PADDING, top: 12, bottom: 12 })
    .backgroundColor(COLOR_CARD)
  }

  @Builder
  sectionTitle(text: string) {
    Text(text)
      .fontSize(13)
      .fontColor(COLOR_TEXT_SECONDARY)
      .width('100%')
      .padding({ left: PAGE_PADDING, right: PAGE_PADDING, top: 24, bottom: 8 })
  }

  @Builder
  toggleRow(label: string, sub: string, value: boolean, onChange: (v: boolean) => void) {
    Row() {
      Column() {
        Text(label)
          .fontSize(16)
          .fontColor(COLOR_TEXT)
        Text(sub)
          .fontSize(13)
          .fontColor(COLOR_TEXT_WEAK)
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Toggle({ type: ToggleType.Switch, isOn: value })
        .onChange((v: boolean) => onChange(v))
    }
    .padding(16)
  }

  @Builder
  linkRow(label: string, sub: string, onClick: () => void, danger: boolean = false) {
    Row() {
      Column() {
        Text(label)
          .fontSize(16)
          .fontColor(danger ? COLOR_DANGER : COLOR_TEXT)
        if (sub) {
          Text(sub)
            .fontSize(13)
            .fontColor(COLOR_TEXT_WEAK)
            .margin({ top: 4 })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text('›')
        .fontSize(20)
        .fontColor(COLOR_TEXT_WEAK)
    }
    .padding(16)
    .onClick(onClick)
  }

  @Builder
  divider() {
    Divider().color(COLOR_BORDER).margin({ left: 16 })
  }

  private async toggleLock(on: boolean): Promise<void> {
    if (on) {
      const success = await appLock.authenticate();
      if (success) {
        appLock.enable();
        this.enableLock = true;
      } else {
        this.enableLock = false;
      }
    } else {
      appLock.disable();
      this.enableLock = false;
    }
  }

  private confirmDeleteAll(): void {
    promptAction.showDialog({
      title: '清空所有令牌',
      message: '此操作不可恢复。建议先导出备份。\n\n确定要清空所有令牌吗？',
      buttons: [
        { text: '取消', color: COLOR_TEXT_WEAK },
        { text: '清空', color: COLOR_DANGER },
      ],
    }).then((result) => {
      if (result.index === 1) {
        accountStore.deleteAll();
        router.back();
      }
    });
  }

  private showHelp(): void {
    promptAction.showDialog({
      title: '使用说明',
      message: '1. 添加令牌可以扫码，也可以手动输入 Base32 Secret。\n2. 点击令牌卡片可复制当前验证码。\n3. 倒计时接近结束时，请等待下一轮验证码再使用。\n4. 建议定期导出加密备份。',
      buttons: [{ text: '知道了', color: COLOR_BRAND }],
    });
  }

  private showPrivacy(): void {
    promptAction.showDialog({
      title: '隐私说明',
      message: `${APP_NAME} 不上传令牌密钥。账号数据保存在应用沙箱内，备份文件由你的密码加密保护。`,
      buttons: [{ text: '好的', color: COLOR_BRAND }],
    });
  }
}
