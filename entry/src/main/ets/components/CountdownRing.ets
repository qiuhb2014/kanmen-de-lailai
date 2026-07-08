// CountdownRing.ets
// TOTP 倒计时环：剩余时间越少，环形进度越短

import { COLOR_BORDER, COLOR_BRAND } from '../theme/DesignTokens';

@Component
export struct CountdownRing {
  @Prop progress: number = 0;        // 0.0 ~ 1.0
  @Prop remaining: number = 0;       // 剩余秒数
  @Prop color: string = COLOR_BRAND;
  @Prop ringSize: number = 18;
  @Prop strokeWidth: number = 2;

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Circle()
        .fill(Color.Transparent)
        .stroke(COLOR_BORDER)
        .strokeWidth(this.strokeWidth)
        .width(this.ringSize)
        .height(this.ringSize)

      Progress({
        value: this.remainingPercent(),
        total: 100,
        type: ProgressType.Ring,
      })
        .width(this.ringSize)
        .height(this.ringSize)
        .color(this.color)
        .style({
          strokeWidth: this.remaining <= 5 ? this.strokeWidth + 1 : this.strokeWidth,
          enableSmoothEffect: true,
        })
    }
    .width(this.ringSize)
    .height(this.ringSize)
  }

  private remainingPercent(): number {
    const value = (1 - this.progress) * 100;
    if (value < 0) {
      return 0;
    }
    if (value > 100) {
      return 100;
    }
    return value;
  }
}
