// AccountDetailPage.ets
// 令牌详情：查看当前验证码、复制验证码和基础参数

import { router } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { vibrator } from '@kit.SensorServiceKit';
import { TOTPAccount } from '../model/TOTPAccount';
import { accountStore } from '../store/AccountStore';
import { CountdownRing } from '../components/CountdownRing';
import {
  COLOR_BACKGROUND,
  COLOR_BORDER,
  COLOR_BRAND,
  COLOR_CARD,
  COLOR_DANGER,
  COLOR_FILL,
  COLOR_TEXT,
  COLOR_TEXT_WEAK,
  PAGE_PADDING,
  RADIUS_CARD,
} from '../theme/DesignTokens';

interface AccountDetailParams {
  accountId?: string;
}

@Entry
@Component
struct AccountDetailPage {
  @State accountId: string = '';
  @State account: TOTPAccount = new TOTPAccount();
  @State hasAccount: boolean = false;
  @State tick: number = Date.now();
  private timerId: number = -1;

  aboutToAppear(): void {
    this.readParams();
    this.refreshAccount();
    this.tick = Date.now();
    this.timerId = setInterval(() => {
      this.tick = Date.now();
    }, 50);
  }

  onPageShow(): void {
    this.refreshAccount();
  }

  aboutToDisappear(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  build() {
    Column() {
      this.navBar()

      if (this.hasAccount) {
        Scroll() {
          Column() {
            this.profileHeader()
            this.codeCard()
            this.copyCard()
            this.infoCard()
          }
          .width('100%')
          .padding({ bottom: 40 })
        }
        .layoutWeight(1)
        .backgroundColor(COLOR_BACKGROUND)
      } else {
        this.missingState()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_BACKGROUND)
  }

  @Builder
  navBar() {
    Row() {
      Text('←')
        .fontSize(30)
        .fontColor(COLOR_TEXT)
        .width(56)
        .onClick(() => router.back())

      Text(this.titleText())
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_TEXT)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text('⋮')
        .fontSize(30)
        .fontColor(COLOR_TEXT)
        .width(56)
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .padding({ left: PAGE_PADDING, right: PAGE_PADDING, top: 18, bottom: 12 })
    .backgroundColor(COLOR_BACKGROUND)
  }

  @Builder
  profileHeader() {
    Column() {
      this.avatar(80, 34)

      Text(this.account.displayName || '未命名服务')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_TEXT)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 26 })

      Text(this.account.subtitle || '未填写账号')
        .fontSize(16)
        .fontColor(COLOR_TEXT_WEAK)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 10 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({ top: 28, bottom: 34, left: 40, right: 40 })
  }

  @Builder
  codeCard() {
    Column() {
      Text(this.formatCode(this.safeCurrentCode(this.tick)))
        .fontSize(52)
        .fontWeight(FontWeight.Bold)
        .fontFamily('monospace')
        .fontColor(COLOR_TEXT)
        .textAlign(TextAlign.Center)
        .width('100%')
        .maxLines(1)

      Divider()
        .color(COLOR_BORDER)
        .width('78%')
        .margin({ top: 26, bottom: 18 })

      Row() {
        CountdownRing({
          progress: this.safeProgress(this.tick),
          remaining: this.safeRemainingSeconds(this.tick),
          color: this.safeRemainingSeconds(this.tick) <= 5 ? COLOR_DANGER : COLOR_BRAND,
          ringSize: 28,
          strokeWidth: 3,
        })

        Text(`${this.safeRemainingSeconds(this.tick)} 秒后刷新`)
          .fontSize(16)
          .fontColor(COLOR_TEXT_WEAK)
          .margin({ left: 12 })
      }
      .alignItems(VerticalAlign.Center)
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height(190)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(COLOR_CARD)
    .borderRadius(RADIUS_CARD)
    .margin({ left: PAGE_PADDING, right: PAGE_PADDING })
  }

  @Builder
  copyCard() {
    Column() {
      this.copyIcon()

      Text('复制')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(COLOR_TEXT)
        .margin({ top: 10 })
    }
    .width('100%')
    .height(96)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(COLOR_CARD)
    .borderRadius(RADIUS_CARD)
    .margin({ left: PAGE_PADDING, right: PAGE_PADDING, top: 24 })
    .onClick(() => {
      this.copy();
    })
  }

  @Builder
  infoCard() {
    Column() {
      this.infoRow('类型', `TOTP · ${this.safePeriod()} 秒`)
      this.divider()
      this.infoRow('算法', this.algorithmLabel())
      this.divider()
      this.infoRow('数字位数', `${this.account.digits || 6} 位`)
      this.divider()
      this.infoRow('创建时间', this.createdDateText())
    }
    .backgroundColor(COLOR_CARD)
    .borderRadius(RADIUS_CARD)
    .margin({ left: PAGE_PADDING, right: PAGE_PADDING, top: 24 })
  }

  @Builder
  infoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(16)
        .fontColor(COLOR_TEXT_WEAK)
        .layoutWeight(1)

      Text(value)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(COLOR_TEXT)
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 18, bottom: 18 })
  }

  @Builder
  divider() {
    Divider()
      .color(COLOR_BORDER)
      .margin({ left: 20, right: 20 })
  }

  @Builder
  avatar(size: number, fontSize: number) {
    Row() {
      Text(this.avatarText())
        .fontSize(fontSize)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_TEXT)
    }
    .width(size)
    .height(size)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(COLOR_FILL)
    .borderRadius(16)
  }

  @Builder
  copyIcon() {
    Stack() {
      Row()
        .width(20)
        .height(20)
        .border({ width: 2, color: COLOR_BRAND })
        .borderRadius(4)
        .position({ x: 8, y: 8 })

      Row()
        .width(20)
        .height(20)
        .backgroundColor(COLOR_CARD)
        .border({ width: 2, color: COLOR_BRAND })
        .borderRadius(4)
        .position({ x: 0, y: 0 })
    }
    .width(30)
    .height(30)
  }

  @Builder
  missingState() {
    Column() {
      Text('令牌不存在')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor(COLOR_TEXT)

      Text('返回首页后重新选择一个令牌')
        .fontSize(14)
        .fontColor(COLOR_TEXT_WEAK)
        .margin({ top: 8 })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  private readParams(): void {
    const params = router.getParams() as AccountDetailParams;
    if (params && params.accountId) {
      this.accountId = params.accountId;
    }
  }

  private refreshAccount(): void {
    accountStore.load();
    const found = this.findAccount(this.accountId);
    if (found) {
      this.account = found;
      this.hasAccount = true;
    } else {
      this.hasAccount = false;
    }
  }

  private findAccount(id: string): TOTPAccount | null {
    const accounts = accountStore.getAccounts();
    for (let i = 0; i < accounts.length; i++) {
      if (accounts[i].id === id) {
        return accounts[i];
      }
    }
    return null;
  }

  private titleText(): string {
    if (this.hasAccount) {
      return this.account.displayName || '令牌详情';
    }
    return '令牌详情';
  }

  private avatarText(): string {
    const name = this.account.displayName || this.account.account || '?';
    return name.substring(0, 1).toUpperCase();
  }

  private formatCode(code: string): string {
    if (code.length !== 6) {
      return code;
    }
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
      const elapsedMs = this.currentTime(tick) % periodMs;
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

  private algorithmLabel(): string {
    const raw = `${this.account.algorithm}`;
    if (raw === 'SHA256') {
      return 'SHA-256';
    }
    if (raw === 'SHA512') {
      return 'SHA-512';
    }
    return 'SHA-1';
  }

  private createdDateText(): string {
    if (!this.account.createdAt) {
      return '-';
    }
    const date = new Date(this.account.createdAt);
    const month = this.pad2(date.getMonth() + 1);
    const day = this.pad2(date.getDate());
    return `${date.getFullYear()}-${month}-${day}`;
  }

  private pad2(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }
}
