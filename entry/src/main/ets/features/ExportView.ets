// ExportView.ets
// 导出加密备份 —— 用户输入密码 → AES-256-GCM 加密 → 写文件
//
// 文件名格式：lailai-backup-YYYYMMDD-HHmm.json
// 保存到 filesDir（应用沙箱），用户可拷贝到 iCloud/网盘/U 盘

import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { accountStore } from '../store/AccountStore';
import { BackupCrypto } from '../crypto/BackupCrypto';
import {
  COLOR_BACKGROUND,
  COLOR_BRAND,
  COLOR_CARD,
  COLOR_DANGER,
  COLOR_FILL,
  COLOR_TEXT,
  COLOR_TEXT_SECONDARY,
  COLOR_TEXT_WEAK,
  COLOR_WARNING,
  PAGE_PADDING,
  RADIUS_BUTTON,
  RADIUS_CARD,
} from '../theme/DesignTokens';

@Entry
@Component
struct ExportView {
  @State password: string = '';
  @State confirmPassword: string = '';
  @State busy: boolean = false;
  @State error: string = '';
  @State successPath: string = '';

  build() {
    Column() {
      // 顶部导航
      Row() {
        Text('取消')
          .fontSize(16)
          .fontColor(COLOR_BRAND)
          .onClick(() => router.back())
        Text('导出备份')
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

      if (this.successPath) {
        this.successView()
      } else {
        this.formView()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_BACKGROUND)
  }

  @Builder
  formView() {
    Scroll() {
      Column() {
        // 警告提示
        Row() {
          Text('备份')
            .fontSize(14)
            .fontColor(COLOR_WARNING)
            .fontWeight(FontWeight.Medium)
            .margin({ right: 12 })
          Column() {
            Text('备份包含全部密钥')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(COLOR_TEXT)
            Text('请设置强密码保护。\n密码丢失则备份无法恢复。')
              .fontSize(12)
              .fontColor(COLOR_TEXT_SECONDARY)
              .margin({ top: 4 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding(16)
        .backgroundColor('#FFF7E6')
        .borderRadius(RADIUS_CARD)
        .margin({ top: 16, left: PAGE_PADDING, right: PAGE_PADDING })

        // 数量
        Text(`将导出 ${accountStore.getAccounts().length} 个账号`)
          .fontSize(13)
          .fontColor(COLOR_TEXT_SECONDARY)
          .width('100%')
          .padding({ left: PAGE_PADDING, right: PAGE_PADDING, top: 20, bottom: 8 })

        // 密码输入
        Column() {
          this.passwordField('设置密码', this.password, false, (v: string) => { this.password = v; })
          this.divider()
          this.passwordField('再次输入', this.confirmPassword, false, (v: string) => { this.confirmPassword = v; })
        }
        .backgroundColor(COLOR_CARD)
        .borderRadius(RADIUS_CARD)
        .margin({ left: PAGE_PADDING, right: PAGE_PADDING })

        if (this.error) {
          Text(this.error)
            .fontSize(13)
            .fontColor(COLOR_DANGER)
            .width('100%')
            .padding({ left: PAGE_PADDING, right: PAGE_PADDING, top: 12 })
        }

        Button(this.busy ? '加密中...' : '生成备份文件')
          .width('90%')
          .height(50)
          .margin({ top: 30 })
          .fontColor(COLOR_CARD)
          .backgroundColor(this.canExport ? COLOR_BRAND : '#CCCCCC')
          .borderRadius(RADIUS_BUTTON)
          .onClick(() => this.canExport ? this.doExport() : null)

        Text('加密算法：AES-256-GCM\n密码派生：PBKDF2-HMAC-SHA256（200,000 次迭代）')
          .fontSize(11)
          .fontColor(COLOR_TEXT_WEAK)
          .textAlign(TextAlign.Center)
          .width('100%')
          .padding({ top: 16, bottom: 30 })
      }
      .width('100%')
    }
    .layoutWeight(1)
  }

  @Builder
  successView() {
    Column() {
      Text('备份已生成')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_TEXT)
        .margin({ top: 60, bottom: 24 })

      Text('文件已保存到：')
        .fontSize(14)
        .fontColor(COLOR_TEXT_SECONDARY)

      Text(this.successPath)
        .fontSize(12)
        .fontColor(COLOR_TEXT)
        .fontFamily('monospace')
        .padding(12)
        .backgroundColor(COLOR_FILL)
        .borderRadius(RADIUS_BUTTON)
        .margin({ top: 8, left: 24, right: 24 })
        .textAlign(TextAlign.Center)
        .wordBreak(WordBreak.BREAK_ALL)

      Text('建议拷贝到 iCloud Drive、华为云空间、U 盘等地方。\n切记保存好你的备份密码。')
        .fontSize(12)
        .fontColor(COLOR_TEXT_WEAK)
        .textAlign(TextAlign.Center)
        .margin({ top: 24 })
        .padding({ left: 32, right: 32 })

      Blank()

      Button('完成')
        .width('80%')
        .height(50)
        .margin({ bottom: 40 })
        .fontColor(COLOR_CARD)
        .backgroundColor(COLOR_BRAND)
        .borderRadius(RADIUS_BUTTON)
        .onClick(() => router.back())
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  passwordField(label: string, value: string, _isOld: boolean, onChange: (v: string) => void) {
    Row() {
      Text(label)
        .fontSize(15)
        .width(80)
        .fontColor(COLOR_TEXT)
      TextInput({ placeholder: '至少 6 位', text: value })
        .layoutWeight(1)
        .type(InputType.Password)
        .backgroundColor(Color.Transparent)
        .onChange((v: string) => onChange(v))
    }
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
  }

  @Builder
  divider() {
    Divider().color('#EEEEEE').margin({ left: 16 })
  }

  // MARK: - 校验

  private get canExport(): boolean {
    return this.password.length >= 6 &&
           this.password === this.confirmPassword &&
           !this.busy;
  }

  // MARK: - 执行

  private async doExport(): Promise<void> {
    this.busy = true;
    this.error = '';
    try {
      const data = await BackupCrypto.export(accountStore.getAccounts(), this.password);
      const context = getContext(this) as common.UIAbilityContext;
      const filesDir = context.filesDir;
      const fileName = `lailai-backup-${formatDate(new Date())}.json`;
      const filePath = `${filesDir}/${fileName}`;

      const file = fileIo.openSync(
        filePath,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC
      );
      // data 是 Uint8Array，转成 ArrayBuffer 再写
      const buf = data.buffer.slice(data.byteOffset, data.byteOffset + data.byteLength);
      fileIo.writeSync(file.fd, buf);
      fileIo.closeSync(file);

      this.successPath = filePath;
    } catch (e) {
      this.error = `导出失败：${(e as Error).message ?? e}`;
    } finally {
      this.busy = false;
    }
  }
}

function formatDate(d: Date): string {
  const yyyy = d.getFullYear();
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  const dd = String(d.getDate()).padStart(2, '0');
  const hh = String(d.getHours()).padStart(2, '0');
  const mi = String(d.getMinutes()).padStart(2, '0');
  return `${yyyy}${mm}${dd}-${hh}${mi}`;
}
