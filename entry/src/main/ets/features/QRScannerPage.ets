// QRScannerPage.ets
// 系统级扫码 —— 用鸿蒙的 @kit.ScanKit（scanBarcode）
// 这是鸿蒙的"原生姿势"，一行调用，UI 都给你做好了

import { scanBarcode, scanCore } from '@kit.ScanKit';
import { router } from '@kit.ArkUI';
import { AccountStore, accountStore } from '../store/AccountStore';
import { parseOTPUri } from '../utils/OTPURI';
import { COLOR_BRAND, COLOR_CARD, COLOR_DANGER, RADIUS_BUTTON, RADIUS_CARD } from '../theme/DesignTokens';

@Entry
@Component
struct QRScannerPage {
  @State scanning: boolean = true;
  @State errorMsg: string = '';
  private store: AccountStore = accountStore;

  aboutToAppear(): void {
    this.startScan();
  }

  private async startScan(): Promise<void> {
    try {
      const options: scanBarcode.ScanOptions = {
        scanTypes: [scanCore.ScanType.QR_CODE],
        enableMultiMode: false,
        enableAlbum: false,
      };
      const result = await scanBarcode.startScanForResult(getContext(this), options);
      this.scanning = false;
      const value = result.originalValue;
      if (!value) {
        this.errorMsg = '未识别到二维码';
        return;
      }
      if (!value.startsWith('otpauth://')) {
        this.errorMsg = '不是 otpauth:// 二维码';
        return;
      }
      try {
        const acc = parseOTPUri(value);
        this.store.add(acc);
        router.back();
      } catch (e) {
        this.errorMsg = (e as Error).message;
      }
    } catch (e) {
      this.scanning = false;
      this.errorMsg = `扫码失败：${(e as Error).message ?? e}`;
    }
  }

  build() {
    Stack() {
      // 背景全黑
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Black)

      // 提示
      if (this.scanning) {
        Column() {
          Text('请将二维码放入取景框内')
            .fontSize(16)
            .fontColor(COLOR_CARD)
            .padding(12)
            .backgroundColor('rgba(0, 0, 0, 0.5)')
            .borderRadius(RADIUS_BUTTON)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }

      // 错误
      if (this.errorMsg) {
        Column() {
          Text(this.errorMsg)
            .fontSize(16)
            .fontColor(COLOR_CARD)
            .padding(20)
            .backgroundColor(COLOR_DANGER)
            .borderRadius(RADIUS_CARD)
            .textAlign(TextAlign.Center)

          Button('返回')
            .margin({ top: 20 })
            .fontColor(COLOR_CARD)
            .backgroundColor(COLOR_BRAND)
            .borderRadius(RADIUS_BUTTON)
            .onClick(() => router.back())
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }

      // 顶部关闭按钮
      Row() {
        Text('✕')
          .fontSize(24)
          .fontColor(COLOR_CARD)
          .padding(12)
          .onClick(() => router.back())
      }
      .width('100%')
      .padding({ left: 12, top: 36 })
    }
    .width('100%')
    .height('100%')
  }
}
