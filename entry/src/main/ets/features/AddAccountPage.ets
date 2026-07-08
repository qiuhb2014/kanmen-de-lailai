// AddAccountPage.ets
// 添加令牌：扫码或手动输入

import { router } from '@kit.ArkUI';
import { AccountStore, accountStore } from '../store/AccountStore';
import { TOTPAccount } from '../model/TOTPAccount';
import { Base32 } from '../utils/Base32';
import { OTPAlgorithm } from '../crypto/TOTPGenerator';
import { generateUuid } from '../utils/Random';
import {
  COLOR_BACKGROUND,
  COLOR_BORDER,
  COLOR_BRAND,
  COLOR_CARD,
  COLOR_DANGER,
  COLOR_TEXT,
  COLOR_TEXT_DISABLED,
  COLOR_TEXT_SECONDARY,
  COLOR_TEXT_WEAK,
  PAGE_PADDING,
  RADIUS_CARD,
} from '../theme/DesignTokens';

@Entry
@Component
struct AddAccountPage {
  @State issuer: string = '';
  @State account: string = '';
  @State secret: string = '';
  @State error: string = '';
  @State isFormValid: boolean = false;
  private store: AccountStore = accountStore;

  build() {
    Column() {
      this.navBar()

      Scroll() {
        Column() {
          this.scanCell()
          this.sectionTitle('手动输入')
          this.formCard()

          if (this.error) {
            Text(this.error)
              .fontSize(13)
              .fontColor(COLOR_DANGER)
              .width('100%')
              .padding({ left: PAGE_PADDING, right: PAGE_PADDING, top: 12 })
          }
        }
        .width('100%')
        .padding({ bottom: 32 })
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
      Text('取消')
        .fontSize(16)
        .fontColor(COLOR_BRAND)
        .width(64)
        .onClick(() => router.back())

      Text('添加令牌')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(COLOR_TEXT)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      Text('保存')
        .fontSize(16)
        .fontColor(this.isFormValid ? COLOR_BRAND : COLOR_TEXT_DISABLED)
        .fontWeight(FontWeight.Medium)
        .width(64)
        .textAlign(TextAlign.End)
        .onClick(() => {
          if (this.isFormValid) {
            this.save();
          } else {
            this.validateForm(true);
          }
        })
    }
    .width('100%')
    .padding({ left: PAGE_PADDING, right: PAGE_PADDING, top: 12, bottom: 12 })
    .backgroundColor(COLOR_CARD)
  }

  @Builder
  scanCell() {
    Column() {
      Row() {
        Column() {
          Text('扫码录入')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(COLOR_TEXT)
          Text('扫描网站提供的 otpauth 二维码')
            .fontSize(13)
            .fontColor(COLOR_TEXT_WEAK)
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text('进入')
          .fontSize(14)
          .fontColor(COLOR_BRAND)
      }
      .width('100%')
      .padding(16)
      .backgroundColor(COLOR_CARD)
      .borderRadius(RADIUS_CARD)
      .onClick(() => {
        router.pushUrl({ url: 'features/QRScannerPage' });
      })
    }
    .padding({ left: PAGE_PADDING, right: PAGE_PADDING, top: 16 })
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
  formCard() {
    Column() {
      this.issuerField()
      this.divider()
      this.accountField()
      this.divider()
      this.secretField()
    }
    .backgroundColor(COLOR_CARD)
    .borderRadius(RADIUS_CARD)
    .margin({ left: PAGE_PADDING, right: PAGE_PADDING })
  }

  @Builder
  issuerField() {
    Row() {
      Text('服务')
        .fontSize(15)
        .fontColor(COLOR_TEXT)
        .width(68)
      TextInput({ placeholder: '例如 GitHub', text: this.issuer })
        .layoutWeight(1)
        .fontSize(15)
        .fontColor(COLOR_TEXT)
        .backgroundColor(Color.Transparent)
        .type(InputType.Normal)
        .onChange((v: string) => {
          this.updateIssuer(v);
        })
    }
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
  }

  @Builder
  accountField() {
    Row() {
      Text('账号')
        .fontSize(15)
        .fontColor(COLOR_TEXT)
        .width(68)
      TextInput({ placeholder: '例如 you@example.com', text: this.account })
        .layoutWeight(1)
        .fontSize(15)
        .fontColor(COLOR_TEXT)
        .backgroundColor(Color.Transparent)
        .type(InputType.Normal)
        .onChange((v: string) => {
          this.updateAccount(v);
        })
    }
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
  }

  @Builder
  secretField() {
    Row() {
      Text('Secret')
        .fontSize(15)
        .fontColor(COLOR_TEXT)
        .width(68)
      TextInput({ placeholder: 'Base32 密钥', text: this.secret })
        .layoutWeight(1)
        .fontSize(15)
        .fontColor(COLOR_TEXT)
        .fontFamily('monospace')
        .backgroundColor(Color.Transparent)
        .type(InputType.Normal)
        .onChange((v: string) => {
          this.updateSecret(v);
        })
    }
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
  }

  @Builder
  divider() {
    Divider().color(COLOR_BORDER).margin({ left: 16 })
  }

  private updateIssuer(value: string): void {
    this.issuer = value;
    this.validateForm(false);
  }

  private updateAccount(value: string): void {
    this.account = value;
    this.validateForm(false);
  }

  private updateSecret(value: string): void {
    this.secret = value.toUpperCase();
    this.validateForm(false);
  }

  private validateForm(showError: boolean): boolean {
    const account = this.account.trim();
    const secretText = this.secret.trim();
    const secretBytes = Base32.decode(secretText);

    let message = '';
    if (account.length === 0) {
      message = '请输入账号';
    } else if (secretText.length === 0) {
      message = '请输入 Secret';
    } else if (!secretBytes || secretBytes.length === 0) {
      message = 'Secret 不是合法的 Base32 字符串';
    }

    const valid = message.length === 0;
    this.isFormValid = valid;
    this.error = showError || valid ? message : '';
    return valid;
  }

  private save(): void {
    if (!this.validateForm(true)) {
      return;
    }

    const secretBytes = Base32.decode(this.secret.trim());
    if (!secretBytes || secretBytes.length === 0) {
      this.error = 'Secret 不是合法的 Base32 字符串';
      return;
    }

    const acc = new TOTPAccount();
    acc.id = generateUuid();
    acc.issuer = this.issuer.trim();
    acc.account = this.account.trim();
    acc.secret = secretBytes;
    acc.digits = 6;
    acc.period = 30;
    acc.algorithm = OTPAlgorithm.SHA1;
    acc.createdAt = Date.now();

    if (this.store.add(acc)) {
      router.back();
    } else {
      this.error = this.store.lastError || '保存失败，请稍后重试';
    }
  }
}
