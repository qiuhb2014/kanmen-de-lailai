// Index.ets
// 主页面：令牌列表、搜索、设置入口和新增入口

import { router } from '@kit.ArkUI';
import { AccountStore, accountStore } from '../store/AccountStore';
import { TOTPAccount } from '../model/TOTPAccount';
import { AccountRow } from '../components/AccountRow';
import { redirectToLockIfNeeded } from '../utils/LockGuard';
import {
  APP_NAME,
  COLOR_BACKGROUND,
  COLOR_BRAND,
  COLOR_CARD,
  COLOR_DANGER,
  COLOR_TEXT,
  COLOR_TEXT_WEAK,
  PAGE_PADDING,
  RADIUS_BUTTON,
  RADIUS_INPUT,
} from '../theme/DesignTokens';

@Entry
@Component
struct Index {
  @State tick: number = 0;
  @State keyword: string = '';
  @State showError: boolean = false;
  @State accountCount: number = 0;
  @State visibleAccounts: TOTPAccount[] = [];
  private timerId: number = -1;
  private store: AccountStore = accountStore;

  aboutToAppear(): void {
    this.refreshAccounts();
    this.tick = Date.now();

    this.timerId = setInterval(() => {
      this.tick = Date.now();
    }, 50);

    redirectToLockIfNeeded();
  }

  onPageShow(): void {
    this.refreshAccounts();
    redirectToLockIfNeeded();
  }

  aboutToDisappear(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  build() {
    Stack() {
      Column() {
        this.header()
        this.searchBar()

        if (this.getRenderedAccounts().length === 0) {
          this.emptyState()
        } else {
          this.list()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(COLOR_BACKGROUND)

      Button('+', { type: ButtonType.Circle })
        .width(56)
        .height(56)
        .fontSize(30)
        .fontWeight(FontWeight.Regular)
        .fontColor(COLOR_CARD)
        .backgroundColor(COLOR_BRAND)
        .position({ x: '78%', y: '82%' })
        .onClick(() => {
          router.pushUrl({ url: 'features/AddAccountPage' });
        })

      if (this.showError) {
        this.errorBanner()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  header() {
    Row() {
      Column() {
        Text(APP_NAME)
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_TEXT)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${this.accountCount} 个令牌 · 本地保存`)
          .fontSize(14)
          .fontColor(COLOR_TEXT_WEAK)
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Button('设置')
        .height(36)
        .fontSize(14)
        .fontColor(COLOR_BRAND)
        .backgroundColor(COLOR_CARD)
        .borderRadius(RADIUS_BUTTON)
        .onClick(() => {
          router.pushUrl({ url: 'features/SettingsView' });
        })
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 28, bottom: 12 })
  }

  @Builder
  searchBar() {
    Row() {
      Text('搜索')
        .fontSize(15)
        .fontColor(COLOR_TEXT_WEAK)
        .margin({ left: 16, right: 8 })
      TextInput({ placeholder: '服务或账号', text: this.keyword })
        .layoutWeight(1)
        .fontSize(15)
        .fontColor(COLOR_TEXT)
        .backgroundColor(Color.Transparent)
        .onChange((value: string) => {
          this.keyword = value;
          this.applyFilter();
        })
    }
    .height(44)
    .margin({ left: PAGE_PADDING, right: PAGE_PADDING, bottom: 12 })
    .backgroundColor(COLOR_CARD)
    .borderRadius(RADIUS_INPUT)
  }

  @Builder
  emptyState() {
    Column() {
      Text(this.keyword ? '没有匹配的令牌' : '还没有令牌')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor(COLOR_TEXT)
      Text(this.keyword ? '换个关键词试试' : '添加第一个账号后，验证码会在这里实时刷新')
        .fontSize(14)
        .fontColor(COLOR_TEXT_WEAK)
        .textAlign(TextAlign.Center)
        .margin({ top: 8 })
        .padding({ left: 40, right: 40 })
      if (!this.keyword) {
        Button('添加令牌')
          .height(44)
          .fontSize(16)
          .fontColor(COLOR_CARD)
          .backgroundColor(COLOR_BRAND)
          .borderRadius(RADIUS_BUTTON)
          .margin({ top: 24 })
          .onClick(() => {
            router.pushUrl({ url: 'features/AddAccountPage' });
          })
      }
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  list() {
    List({ space: 10 }) {
      ForEach(this.getRenderedAccounts(), (acc: TOTPAccount) => {
        ListItem() {
          AccountRow({ account: acc, tick: this.tick })
        }
        .padding({ left: PAGE_PADDING, right: PAGE_PADDING })
        .swipeAction({ end: this.deleteButton(acc) })
      }, (acc: TOTPAccount) => acc.id)
    }
    .width('100%')
    .layoutWeight(1)
    .listDirection(Axis.Vertical)
    .divider({ strokeWidth: 0 })
    .padding({ bottom: 88 })
  }

  @Builder
  deleteButton(acc: TOTPAccount) {
    Button('删除')
      .width(76)
      .height('100%')
          .backgroundColor(COLOR_DANGER)
          .fontColor(COLOR_CARD)
          .onClick(() => {
            this.store.delete(acc.id);
            this.refreshAccounts();
          })
  }

  @Builder
  errorBanner() {
    Column() {
      Text(this.store.lastError)
        .fontSize(14)
        .fontColor(COLOR_CARD)
        .padding(12)
    }
    .width('100%')
    .backgroundColor(COLOR_DANGER)
    .onClick(() => {
      this.showError = false;
      this.store.clearError();
    })
  }

  private refreshAccounts(): void {
    this.store.load();
    this.accountCount = this.store.getAccounts().length;
    this.applyFilter();
  }

  private applyFilter(): void {
    const accounts = this.store.getAccounts();
    const query = (this.keyword ?? '').trim().toLowerCase();
    if (query.length === 0) {
      this.visibleAccounts = accounts ?? [];
      return;
    }
    this.visibleAccounts = accounts.filter((acc: TOTPAccount) => {
      return acc.displayName.toLowerCase().includes(query) ||
        acc.subtitle.toLowerCase().includes(query);
    });
  }

  private getRenderedAccounts(): TOTPAccount[] {
    if (!this.visibleAccounts) {
      return [];
    }
    return this.visibleAccounts;
  }
}
