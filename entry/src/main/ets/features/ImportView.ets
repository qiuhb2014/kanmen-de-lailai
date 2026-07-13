// ImportView.ets
// 导入加密备份 —— 三步：选文件 → 输入密码 → 预览 → 确认导入

import { router } from '@kit.ArkUI';
import { fileIo } from '@kit.CoreFileKit';
import { picker } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { accountStore } from '../store/AccountStore';
import { BackupCrypto, BackupError } from '../crypto/BackupCrypto';
import { TOTPAccount } from '../model/TOTPAccount';
import { redirectToLockIfNeeded } from '../utils/LockGuard';
import {
  COLOR_BACKGROUND,
  COLOR_BRAND,
  COLOR_CARD,
  COLOR_DANGER,
  COLOR_TEXT,
  COLOR_TEXT_SECONDARY,
  COLOR_TEXT_WEAK,
  PAGE_PADDING,
  RADIUS_BUTTON,
  RADIUS_CARD,
} from '../theme/DesignTokens';

type Step = 'pick' | 'password' | 'preview';

@Entry
@Component
struct ImportView {
  @State step: Step = 'pick';
  @State fileUri: string = '';
  @State fileName: string = '';
  @State password: string = '';
  @State canDecrypt: boolean = false;
  @State busy: boolean = false;
  @State error: string = '';
  @State previewAccounts: TOTPAccount[] = [];

  onPageShow(): void {
    redirectToLockIfNeeded();
  }

  build() {
    Column() {
      // 顶部
      Row() {
        Text('取消')
          .fontSize(16)
          .fontColor(COLOR_BRAND)
          .onClick(() => router.back())
        Text('导入备份')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_TEXT)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text(' ')
          .fontSize(16)
          .width(40)
      }
      .width('100%')
      .padding({ left: PAGE_PADDING, right: PAGE_PADDING, top: 12, bottom: 12 })
      .backgroundColor(COLOR_CARD)

      Divider().color('#EEEEEE')

      if (this.step === 'pick') {
        this.pickView()
      } else if (this.step === 'password') {
        this.passwordView()
      } else {
        this.previewView()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_BACKGROUND)
  }

  @Builder
  pickView() {
    Column() {
      Text('选择备份文件')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor(COLOR_TEXT)
        .margin({ top: 100 })
      Text('请选择之前导出的 .json 备份文件')
        .fontSize(14)
        .fontColor(COLOR_TEXT_SECONDARY)
        .margin({ top: 8 })

      if (this.error) {
        Text(this.error)
          .fontSize(13)
          .fontColor(COLOR_DANGER)
          .margin({ top: 16 })
      }

      Blank()

      Button('选择文件')
        .width('80%')
        .height(50)
        .margin({ bottom: 40 })
        .fontColor(COLOR_CARD)
        .backgroundColor(COLOR_BRAND)
        .borderRadius(RADIUS_BUTTON)
        .onClick(() => this.pickFile())
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  passwordView() {
    Column() {
      Text('输入备份密码')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor(COLOR_TEXT)
        .margin({ top: 70 })

      Text(this.fileName)
        .fontSize(12)
        .fontColor(COLOR_TEXT_WEAK)
        .fontFamily('monospace')
        .margin({ top: 4 })
        .padding({ left: 24, right: 24 })
        .textAlign(TextAlign.Center)
        .wordBreak(WordBreak.BREAK_ALL)

      TextInput({ placeholder: '请输入密码', text: this.password })
        .type(InputType.Password)
        .width('85%')
        .height(50)
        .margin({ top: 30 })
        .backgroundColor(COLOR_CARD)
        .borderRadius(RADIUS_BUTTON)
        .onChange((v: string) => this.updatePassword(v))

      if (this.error) {
        Text(this.error)
          .fontSize(13)
          .fontColor(COLOR_DANGER)
          .margin({ top: 12 })
      }

      Blank()

      Button(this.busy ? '解密中...' : '解密')
        .width('80%')
        .height(50)
        .margin({ bottom: 40 })
        .fontColor(COLOR_CARD)
        .backgroundColor(this.canDecrypt && !this.busy ? COLOR_BRAND : '#CCCCCC')
        .borderRadius(RADIUS_BUTTON)
        .enabled(this.canDecrypt && !this.busy)
        .onClick(() => this.doDecrypt())
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  previewView() {
    Column() {
      Text(`找到 ${this.previewAccounts.length} 个账号`)
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor(COLOR_TEXT)
        .margin({ top: 24 })

      Text('已存在的账号会被覆盖。确认导入？')
        .fontSize(13)
        .fontColor(COLOR_TEXT_SECONDARY)
        .margin({ top: 6 })

      List({ space: 8 }) {
        ForEach(this.previewAccounts, (acc: TOTPAccount) => {
          ListItem() {
            Row() {
              Text(acc.displayName)
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .layoutWeight(1)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              if (acc.subtitle) {
                Text(acc.subtitle)
                  .fontSize(13)
                  .fontColor(COLOR_TEXT_SECONDARY)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
            }
            .padding({ left: 12, right: 12, top: 12, bottom: 12 })
            .backgroundColor(COLOR_CARD)
            .borderRadius(RADIUS_CARD)
          }
        }, (acc: TOTPAccount) => acc.id)
      }
      .layoutWeight(1)
      .padding({ left: PAGE_PADDING, right: PAGE_PADDING, top: 16 })

      Button('导入到应用')
        .width('80%')
        .height(50)
        .margin({ bottom: 30 })
        .fontColor(COLOR_CARD)
        .backgroundColor(COLOR_BRAND)
        .borderRadius(RADIUS_BUTTON)
        .onClick(() => this.doImport())

      if (this.error) {
        Text(this.error)
          .fontSize(13)
          .fontColor(COLOR_DANGER)
          .margin({ bottom: 16 })
      }
    }
    .width('100%')
    .layoutWeight(1)
  }

  // MARK: - 选文件

  private async pickFile(): Promise<void> {
    try {
      this.error = '';
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
      if (!context) {
        throw new Error('无法获取应用上下文');
      }
      const documentPicker = new picker.DocumentViewPicker(context);
      const options = new picker.DocumentSelectOptions();
      options.maxSelectNumber = 1;
      options.fileSuffixFilters = ['.json'];
      const result = await documentPicker.select(options);
      if (result && result.length > 0) {
        this.fileUri = result[0];
        this.fileName = result[0].split('/').pop() ?? result[0];
        this.step = 'password';
      }
    } catch (e) {
      const err = e as BusinessError;
      this.error = `选择文件失败：${err.message ?? err.code}`;
    }
  }

  // MARK: - 解密

  private updatePassword(value: string): void {
    this.password = value;
    this.canDecrypt = value.length > 0;
  }

  private async doDecrypt(): Promise<void> {
    if (!this.canDecrypt || this.busy) {
      return;
    }
    this.busy = true;
    this.error = '';
    try {
      const file = fileIo.openSync(this.fileUri, fileIo.OpenMode.READ_ONLY);
      let buf: ArrayBuffer;
      try {
        const stat = fileIo.statSync(file.fd);
        if (stat.size <= 0) {
          throw new Error('备份文件为空');
        }
        buf = new ArrayBuffer(stat.size);
        fileIo.readSync(file.fd, buf);
      } finally {
        fileIo.closeSync(file);
      }
      const data = new Uint8Array(buf);
      this.previewAccounts = await BackupCrypto.import(data, this.password);
      if (this.previewAccounts.length === 0) {
        this.error = '备份文件里没有账号';
        return;
      }
      this.step = 'preview';
    } catch (e) {
      if (e instanceof BackupError) {
        this.error = e.message;
      } else {
        this.error = `解密失败：${(e as Error).message ?? e}`;
      }
    } finally {
      this.busy = false;
    }
  }

  // MARK: - 导入

  private doImport(): void {
    this.error = '';
    accountStore.clearError();
    for (const acc of this.previewAccounts) {
      if (!accountStore.add(acc)) {
        this.error = accountStore.lastError || `导入 ${acc.displayName} 失败`;
        return;
      }
    }
    router.back();
  }
}
