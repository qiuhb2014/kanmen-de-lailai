// AccountRow.ets
// 单个令牌卡片：左侧进入详情，右侧点击 6 位码复制

import { router } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { vibrator } from '@kit.SensorServiceKit';
import { TOTPAccount } from '../model/TOTPAccount';
import { CountdownRing } from './CountdownRing';
import {
  COLOR_BRAND,
  COLOR_CARD,
  COLOR_DANGER,
  COLOR_FILL,
  COLOR_TEXT,
  COLOR_TEXT_WEAK,
  RADIUS_CARD,
} from '../theme/DesignTokens';

@Component
export struct AccountRow {
  @ObjectLink account: TOTPAccount;
  @Prop tick: number = 0;

  build() {
    Row() {
      this.infoArea()
      this.codeArea()
    }
    .width('100%')
    .height(92)
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .backgroundColor(COLOR_CARD)
    .borderRadius(RADIUS_CARD)
  }

  @Builder
  infoArea() {
    Row() {
      this.avatar(52, 20)

      Column() {
        Text(this.account.displayName || '未命名服务')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_TEXT)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(this.account.subtitle || '未填写账号')
          .fontSize(14)
          .fontColor(COLOR_TEXT_WEAK)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 6 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .layoutWeight(1)
    .height('100%')
    .margin({ right: 12 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      router.pushUrl({
        url: 'features/AccountDetailPage',
        params: { accountId: this.account.id },
      });
    })
  }

  @Builder
  codeArea() {
    Column() {
        Text(this.formatCode(this.safeCurrentCode(this.tick)))
          .fontSize(26)
          .fontWeight(FontWeight.Medium)
          .fontFamily('monospace')
          .fontColor(COLOR_TEXT)
          .textAlign(TextAlign.End)
          .width(132)
          .maxLines(1)
          .onClick(() => {
            this.copy();
          })

        Row() {
          CountdownRing({
            progress: this.safeProgress(this.tick),
            remaining: this.safeRemainingSeconds(this.tick),
            color: this.safeRemainingSeconds(this.tick) <= 5 ? COLOR_DANGER : COLOR_BRAND,
          })
          Text(`${this.safeRemainingSeconds(this.tick)}s`)
            .fontSize(12)
            .fontColor(COLOR_TEXT_WEAK)
            .width(30)
            .textAlign(TextAlign.Start)
            .margin({ left: 6 })
        }
        .width(62)
        .margin({ top: 14 })
        .justifyContent(FlexAlign.End)
        .alignItems(VerticalAlign.Center)
    }
    .width(132)
    .height('100%')
    .alignItems(HorizontalAlign.End)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  avatar(size: number, fontSize: number) {
    Row() {
      Text(this.avatarText())
        .fontSize(fontSize)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_BRAND)
    }
    .width(size)
    .height(size)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(COLOR_FILL)
    .borderRadius(10)
    .margin({ right: 14 })
  }

  private avatarText(): string {
    const name = this.account.displayName || this.account.account || '?';
    return name.substring(0, 1).toUpperCase();
  }

  private formatCode(code: string): string {
    if (code.length !== 6) return code;
    return code.substring(0, 3) + ' ' + code.substring(3);
  }

  private safeCurrentCode(tick: number): string {
    try {
      return this.account.currentCode(this.currentDate(tick));
    } catch (e) {
      return '------';
    }
  }

  private safeRemainingSeconds(tick: number): number {
    try {
      const periodMs = this.safePeriod() * 1000;
      const now = this.currentTime(tick);
      const elapsedMs = now % periodMs;
      return Math.max(1, Math.ceil((periodMs - elapsedMs) / 1000));
    } catch (e) {
      return 0;
    }
  }

  private safeProgress(tick: number): number {
    try {
      const periodMs = this.safePeriod() * 1000;
      return (this.currentTime(tick) % periodMs) / periodMs;
    } catch (e) {
      return 0;
    }
  }

  private copy(): void {
    const code = this.safeCurrentCode(this.tick);
    if (code === '------') {
      return;
    }

    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, code);
      pasteboard.getSystemPasteboard().setDataSync(data);
    } catch (e) {
      this.showToast('复制失败');
      return;
    }

    try {
      vibrator.startVibration({ type: 'time', duration: 30 }, { id: 0, usage: 'touch' });
    } catch (e) {
    }

    this.showToast('复制成功');
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message, duration: 1500 });
    } catch (e) {
    }
  }

  private currentDate(tick: number): Date {
    return new Date(this.currentTime(tick));
  }

  private currentTime(tick: number): number {
    return tick > 0 ? tick : Date.now();
  }

  private safePeriod(): number {
    return this.account.period > 0 ? this.account.period : 30;
  }
}
